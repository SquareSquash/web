# Copyright 2014 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

# Worker that processes an API exception notification and creates {Occurrence}
# and (if necessary) {Bug} records. This worker is responsible for determining
# which Bug an Occurrence is part of, who is likely to be responsible for the
# bug, and whether the Bug should be reopened or not.
#
# This is a slow process, so it is meant to be run asynchronously. The
# initializer is intended to be run during the request, and will raise an
# exception given malformed parameters. Otherwise, the {#perform} method should
# be called in a separate thread to actually process the notification.
#
# The attributes passed to the initializer are used to construct the Occurrence,
# with the exception of `api_key` and `environment`. Once the Occurrence is
# built, it is linked to an existing matching Bug, or a new Bug if no matching
# Bug can be found.
#
# When the Occurrence is created, it is assigned to a Bug by the {Blamer} class.

class OccurrencesWorker
  include BackgroundRunner::Job

  # Keys that must be passed to the {.perform} method. (We also need either the
  # `build` or `revision` keys.)
  REQUIRED_KEYS = %w( api_key environment client backtraces class_name message occurred_at )

  # @private
  attr_reader :project, :environment, :deploy

  # Included for BackgroundRunner compatibility.

  def self.perform(attrs)
    new(attrs).perform
  end

  # Creates a new worker ready to process an incoming notification.
  #
  # @param [Hash<String, Object>] attrs The queue item properties.
  # @raise [API::InvalidAttributesError] If the attributes are invalid.
  # @raise [API::UnknownAPIKeyError] If the API key is invalid.

  def initialize(attrs)
    @attrs = attrs.deep_clone

    raise API::InvalidAttributesError, "Missing required keys: #{(REQUIRED_KEYS - @attrs.select { |k, v| v.present? }.keys).to_sentence}" unless REQUIRED_KEYS.all? { |key| @attrs[key].present? }
    raise API::InvalidAttributesError, "revision or build must be specified" unless @attrs.include?('revision') || @attrs.include?('build')

    begin
      @project = Project.find_by_api_key!(@attrs.delete('api_key'))
    rescue ActiveRecord::RecordNotFound
      raise API::UnknownAPIKeyError, "Unknown API key"
    end

    env_name     = @attrs.delete('environment')
    @environment = project.environments.with_name(env_name).find_or_create!(name: env_name)
  rescue ActiveRecord::RecordInvalid => err
    raise API::InvalidAttributesError, err.to_s
  end

  # Processes an exception notification. Builds an {Occurrence} and possibly a
  # {Bug}.

  def perform
    # First make an occurrence to perform a blame on
    commit         = set_deploy_and_commit
    class_name     = @attrs.delete('class_name')
    occurrence     = build_occurrence(commit)

    # In order to use Blamer, we need to create a new, unsaved bug with the
    # class name and environment specified in @attrs. If blamer finds a matching
    # existing Bug, it will return that Bug, and the unsaved Bug will never be
    # saved. If however no matching bug is found, a new bug is created, saved,
    # and returned. In no case is the bug we create below saved.
    occurrence.bug = build_temporary_bug(class_name)
    blamer         = project.blamer.new(occurrence)
    bug            = blamer.find_or_create_bug!

    # these must be done after Blamer runs
    add_user_agent_data occurrence
    filter_pii(occurrence, class_name) unless project.disable_message_filtering?
    occurrence.message = occurrence.message.truncate(1000)
    occurrence.message ||= occurrence.class_name # hack for Java

    # hook things up and save
    occurrence.bug     = bug
    Bug.transaction do
      bug.save!
      occurrence.save!
    end

    blamer.reopen_bug_if_necessary! bug
    occurrence
  rescue ActiveRecord::StatementInvalid => err
    if err.to_s.start_with?("ActiveRecord::JDBCError: ERROR: could not serialize access due to read/write dependencies among transactions")
      @retry_count ||= 0
      if @retry_count > 5
        Rails.logger.error "[OccurrencesWorker] Too many retries: #{err.to_s}"
        raise
      else
        @retry_count += 1
        Rails.logger.error "[OccurrencesWorker] Retrying: #{err.to_s}"
        retry
      end
    else
      raise
    end
  rescue Object => err
    # don't get into an infinite loop of notifying Squash
    Rails.logger.error "-- ERROR IN OccurrencesWorker #{err.object_id} --"
    Rails.logger.error err
    Rails.logger.error err.backtrace.join("\n")
    Rails.logger.error @attrs.inspect
    Rails.logger.error "-- END ERROR #{err.object_id} --"
    raise if Rails.env.test?
  end

  private

  def build_temporary_bug(class_name)
    bug            = environment.bugs.build
    bug.class_name = class_name
    bug.deploy     = deploy
    return bug
  end

  def build_occurrence(sha)
    # extract top-level attributes and metadata; stick the rest in user_data

    occurrence_attrs = Hash.new
    other_data       = Hash.new
    @attrs.each do |k, v|
      if Occurrence.attribute_names.include?(k) || Occurrence.metadata_column_fields.keys.map(&:to_s).include?(k)
        occurrence_attrs[k] = v
      else
        other_data[k] = v
      end
    end
    occurrence_attrs['query']    = occurrence_attrs['query'][0, 255] if occurrence_attrs['query']
    occurrence_attrs['revision'] = sha

    occurrence          = Occurrence.new(occurrence_attrs)
    occurrence.metadata = JSON.parse(occurrence.metadata).reverse_merge(other_data).to_json
    occurrence.message  ||= occurrence.class_name # hack for Java

    # must symbolicate before assigning blame

    occurrence.symbolicate

    sourcemaps = environment.source_maps.where(revision: sha)
    occurrence.sourcemap(*sourcemaps) unless sourcemaps.empty?

    obfuscation_map = ObfuscationMap.joins(:deploy).where(deploys: {environment_id: environment.id, revision: sha}).first
    occurrence.deobfuscate(obfuscation_map) if obfuscation_map

    occurrence
  end

  def set_deploy_and_commit
    # We have a couple of options here, depending on the attributes we got from
    # the client...

    if @attrs['revision'].present? && @attrs['build'].present?
      # If we get both a revision and a build, then we can find a Deploy, or
      # create one if it doesn't exist, and use that.

      revision = @attrs['revision']
      sha      = project.blamer.resolve_revision(project, revision)
      @deploy  = @environment.deploys.where(build: @attrs['build']).find_or_create!(
          deployed_at: Time.now,
          revision:    sha
      )
    elsif @attrs['revision'].present?
      # If we get only a revision, the Bug won't have a Deploy, but we still
      # have a revision to do blaming with.

      revision = @attrs['revision']
      sha      = project.blamer.resolve_revision(project, revision)
    elsif @attrs['build'].present?
      # If we get only a build, we can find the Deploy with that build number
      # and use it to get the revision.

      begin
        @deploy = environment.deploys.find_by_build(@attrs['build'])
        raise API::InvalidAttributesError, "Unknown build number" unless deploy
        sha = deploy.revision
      end
    else
      # If we get nothing, we can't do anything.
      raise API::InvalidAttributesError, "Missing required keys"
    end
    sha
  end

  def add_user_agent_data(occurrence)
    ua = if occurrence.headers && occurrence.headers['HTTP_USER_AGENT']
           occurrence.headers['HTTP_USER_AGENT']
         elsif occurrence.extra_data['user_agent']
           occurrence.extra_data['user_agent']
         else
           nil
         end
    return unless ua
    ua                                = Agent.new(ua)
    occurrence.browser_name           = ua.name
    occurrence.browser_version        = ua.version
    occurrence.browser_engine         = ua.engine
    occurrence.browser_os             = ua.os
    occurrence.browser_engine_version = ua.engine_version
  end

  def filter_pii(occurrence, class_name)
    occurrence.message = filter_pii_string(MessageTemplateMatcher.instance.matched_substring(class_name, occurrence.message))

    occurrence.query    = filter_pii_string(occurrence.query) if occurrence.query
    occurrence.path     = filter_pii_string(occurrence.path) if occurrence.path
    occurrence.fragment = filter_pii_string(occurrence.fragment) if occurrence.fragment

    occurrence.parent_exceptions.each do |parent|
      parent['message'] = filter_pii_string(MessageTemplateMatcher.instance.matched_substring(parent['class_name'], parent['message']))
      parent['ivars'].each { |name, param| parent['ivars'][name] = filter_pii_param(param) }
    end if occurrence.parent_exceptions
    %w(session headers flash params cookies ivars).each do |field|
      occurrence.send(field).each do |name, value|
        occurrence.send(field)[name] = filter_pii_param(value)
      end if occurrence.send(field)
    end
  end

  def filter_pii_param(param)
    case param
      when String
        filter_pii_string param
      when Hash
        param.each do |representation, value|
          next if %w(language class_name).include?(representation)
          param[representation] = filter_pii_string(value)
        end
    end
  end

  def filter_pii_string(str)
    str.gsub(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/i, '[EMAIL?]').
        gsub(/\b(?:(?:\+?1\s*(?:[.-]\s*)?)?(?:\(\s*([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9])\s*\)|([2-9]1[02-9]|[2-9][02-8]1|[2-9][02-8][02-9]))\s*(?:[.-]\s*)?)?([2-9]1[02-9]|[2-9][02-9]1|[2-9][02-9]{2})\s*(?:[.-]\s*)?([0-9]{4})(?:\s*(?:#|x\.?|ext\.?|extension)\s*(\d+))?\b/, '[PHONE?]').
        gsub(/\b[0-9][0-9\-]{6,}[0-9]\b/, '[CC/BANK?]')
  end
end
