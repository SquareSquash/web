# Copyright 2013 Square Inc.
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

# Container module for the {Blamer::Base} class cluster.

module Blamer

  # @abstract
  #
  # Subclasses of this class analyze an Occurrence and determines which Bug is
  # responsible. A new Bug is created if no existing Bug matches the search
  # criteria. Different subclasses implement different strategies for
  # determining fault.
  #
  # Usage
  # -----
  #
  # To re-calculate blame for an existing Occurrence, and potentially re-assign it
  # to a different Bug, it is sufficient to pass the Occurrence to this class's
  # initializer.
  #
  # To assign blame to a new, unsaved Occurrence, it will be necessary to create
  # an unsaved Bug and fill it out with the data Blamer needs in order to perform
  # its search. This data is:
  #
  # * the Bug's `environment`,
  # * the Bug's `class_name`, and
  # * the Bug's `deploy`, if any.
  #
  # This new Bug should be temporarily associated with the Occurrence before the
  # Occurrence is given to Blamer. The result of the {#find_or_create_bug!} method
  # will always be a different, saved Bug; you should leave your temporary Bug
  # unsaved.
  #
  # Deployed Projects
  # -----------------
  #
  # For Occurrences that come from Projects deployed onto client platforms, the
  # Deploy is also taken into account. For such Projects, the Blamer will try to
  # find, in order:
  #
  # * an open Bug matching the search criteria under any Deploy,
  # * a fixed Bug matching the criteria under the current Deploy, or
  # * a newly-created Bug.
  #
  # In no case will an open Bug in a different Deploy be chosen.
  #
  # Reopening Bugs
  # --------------
  #
  # After linking and saving the Bug returned from {#find_or_create_bug!}, you
  # should call {#reopen_bug_if_necessary!} to potentially reopen the Bug. This
  # should only be done after the Occurrence and Bug are both linked and saved.

  class Base
    # The amount of time after a bug is fixed _without_ being deployed after which
    # it will be reopened if new occurrences appear.
    STALE_TIMEOUT = 10.days

    # @private
    attr_reader :occurrence

    # @return [String] A human-readable name for this blamer subclass.
    def self.human_name()
      I18n.t("blamer.#{to_s.demodulize.underscore}")
    end

    # Converts a ref-ish (like "HEAD") into a Git SHA. The default
    # implementation simply returns the given revision; subclasses can actually
    # use Git to resolve the SHA.
    #
    # @param [Project] project A project whose repository will be used.
    # @param [String] revision A git ref-ish.
    # @return [String] The 40-character Git SHA.
    def self.resolve_revision(project, revision) revision end

    # Creates a new instance suitable for placing a given Occurrence.
    #
    # @param [Occurrence] occurrence The Occurrence to find a Bug for.

    def initialize(occurrence)
      @occurrence = occurrence
      @special    = false
    end

    # @return [Bug] A Bug the Occurrence should belong to. Does not assign the
    #   Occurrence to the Bug. If no suitable Bug is found, saves and returns a
    #   new one.

    def find_or_create_bug!
      criteria = bug_search_criteria
      bug      = if deploy
                   # for distributed projects, we need to find either
                   # * a bug associated with the exact deploy specified in the build attribute
                   # * or, if the exact deploy specified does not have such a bug:
                   #   * find any open (not fixed) bug matching the criteria;
                   #   * if such a bug exists, use that bug and alter its deploy_id to
                   #     the given deploy;
                   #   * otherwise, a new bug is created.
                   b        = Bug.transaction do
                     environment.bugs.where(criteria.merge(deploy_id: deploy.id)).first ||
                         environment.bugs.where(criteria.merge(fixed: false)).
                             find_or_create!(bug_attributes)
                   end
                   b.deploy = deploy
                   b
                 else
                   # for hosted projects, we search for any bug matching the criteria under
                   # our current environment
                   environment.bugs.where(criteria).
                       find_or_create!(bug_attributes)
                 end

      # If this code works as it should, there should only be one open record of
      # a Bug at any time. A bug occurs, a new Bug is created. A new release is
      # out, but it doesn't fix the bug, and that same Bug is reused. A new
      # release is out that DOES fix the bug, and the bug is closed. The bug
      # recurs, and a new open Bug is created.

      # Lastly, we need to resolve the bug if it's a duplicate.
      bug      = bug.duplicate_of(true) if bug.duplicate?

      return bug
    end

    # This method determines if the Bug should be reopened. You should pass in the
    # Bug returned from {#find_or_create_bug!}, after it has been linked to the
    # Occurrence and saved.
    #
    # This method will reopen the Bug if necessary. The Bug is only reopened if
    # it recurs after being fixed and after the fix is deployed. A fix is
    # considered deployed if the fix has been marked `fix_deployed` or if the fix
    # is over 30 days old.
    #
    # Bugs of distributed Projects are never reopened.
    #
    # @param [Bug] bug The bug that was returned from {#find_or_create_bug!}.

    def reopen_bug_if_necessary!(bug)
      return if bug.deploy

      # now that things are saved, reopen the bug if we need to
      # this is so the occurrence has an id we can write into the reopen event
      occurrence_deploy = bug.environment.deploys.where(revision: occurrence.revision).order('deployed_at DESC').first
      latest_deploy     = bug.environment.deploys.order('deployed_at DESC').first
      if bug.fix_deployed? && occurrence_deploy.try!(:id) == latest_deploy.try!(:id)
        # reopen the bug if it was purportedly fixed and deployed, and the occurrence
        # we're seeing is on the latest deploy -- or if we don't have any deploy
        # information
        bug.reopen occurrence
        bug.save!
      elsif !bug.fix_deployed? && bug.fixed? && bug.fixed_at < STALE_TIMEOUT.ago
        # or, if it was fixed but never marked as deployed, and is more than 30 days old, reopen it
        bug.reopen occurrence
        bug.save!
      end
    end

    protected

    # @abstract
    #
    # @return Hash<Symbol, Object> Ahash of search criteria to be used in a
    #   `WHERE` clause to locate a Bug to file an Occurrence under.

    def bug_search_criteria
      raise NotImplementedError
    end

    private

    def bug() occurrence.bug end
    def environment() occurrence.bug.environment end
    def project() occurrence.bug.environment.project end
    def deploy() occurrence.bug.deploy end

    def bug_attributes
      message = if project.disable_message_filtering?
                  occurrence.message
                else
                  filter_message(occurrence.bug.class_name, occurrence.message)
                end.truncate(1000)

      {
          message_template: message,
          revision:         occurrence.revision,
          environment:      occurrence.bug.environment,
          client:           occurrence.client,
          special_file:     @special
      }
    end

    def filter_message(class_name, message)
      template_message = MessageTemplateMatcher.instance.sanitized_message(class_name, message)
      return template_message if template_message

      message = message.
          gsub(/#<([^\s]+) (\w+: .+?(, )?)+>/, "#<\\1 [ATTRIBUTES]>") # #<Project id: 1, foo: bar>
      message.gsub!(/#<([^\s]+) .+?>/, "#<\\1 [DESCRIPTION]>") # #<Net::HTTP www.apple.com:80 open=true>
      message.gsub!(/#<(.+?):0x[0-9a-f]+>/, "#<\\1:[ADDRESS]>") # #<Object:0x007fedfa0aa920>
      message.gsub!(/\b[0-9a-f]{40}\b/, "[SHA1]") # 0e32b153039e46d4165c65eef1fc277d0f8f11d2
      message.gsub!(/\b\d+\.\d+\.\d+\.\d+\b/, "[IPv4]") # 144.89.172.115
      message.gsub!(/\b-?\d+(\.\d+)?\b/, "[NUMBER]") # 42.24 or 42 or -42
      message
    end
  end
end

Dir.glob(Rails.root.join('lib', 'blamer', '*.rb')).each do |file|
  next if file == __FILE__
  require file
end
