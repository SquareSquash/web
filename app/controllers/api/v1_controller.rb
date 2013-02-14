# Copyright 2012 Square Inc.
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

require 'base64'
require 'zlib'

# Endpoint for client libraries. Receives notifications of new exception
# occurrences and new deploys. Processes these requests.
#
# Note that this controller does not inherit from {ApplicationController}.
#
# Common
# ======
#
# All response bodies are empty.
#
# Response Codes
# --------------
#
# |          |                                   |
# |:---------|:----------------------------------|
# | 200, 201 | No errors.                        |
# | 422      | Invalid arguments.                |
# | 403      | Invalid API key.                  |
# | 404      | Unknown environment, deploy, etc. |

class Api::V1Controller < ActionController::Base
  include Squash::Ruby::ControllerMethods
  enable_squash_client except: :notify # prevent infinite loop of notifications

  rescue_from(API::UnknownAPIKeyError) { head :forbidden }
  rescue_from(API::InvalidAttributesError, ActiveRecord::RecordInvalid) do |err|
    record = err.respond_to?(:record) ? err.record : nil
    if record
      Rails.logger.error "Rejecting #{record.class}: #{record.errors.full_messages.join(' - ')}"
    else
      Rails.logger.error "Rejecting record: #{err}"
    end
    head :unprocessable_entity
  end
  rescue_from(ActiveRecord::RecordNotFound) do |err|
    # return 403 or 404 depending on whether it was an auth failure
    if err.to_s =~ /Couldn't find Project with/
      head :forbidden
    else
      head :not_found
    end
  end

  # API endpoint for exception notifications. Creates a new thread and
  # instantiates an {OccurrencesWorker} to process it.
  #
  # Routes
  # ------
  #
  # * `POST /api/1.0/notify`

  def notify
   # worker = OccurrencesWorker.new(request.request_parameters)
   # Multithread.spinoff(nil, 40, squash_rails_data) { worker.perform }
    head :ok
  end

  # API endpoint for deploy or release notifications. Creates a new {Deploy}.
  #
  # Routes
  # ------
  #
  # * `POST /api/1.0/deploy`

  def deploy
    require_params :project, :environment, :deploy

    project     = Project.find_by_api_key!(params['project']['api_key'])
    environment = project.environments.with_name(params['environment']['name']).find_or_create!({name: params['environment']['name']}, as: :worker)

    environment.deploys.create!(params['deploy'], as: :worker)

    head :ok
  end

  # API endpoint for uploading symbolication data. This data typically comes
  # from symbolicating scripts that run on compiled projects.
  #
  # Routes
  # ------
  #
  # * `POST /api/1.0/symbolication`

  def symbolication
    require_params :symbolications

    params['symbolications'].each do |attrs|
      Symbolication.where(uuid: attrs['uuid']).create_or_update do |symbolication|
        symbolication.send :write_attribute, :symbols, attrs['symbols']
        symbolication.send :write_attribute, :lines, attrs['lines']
      end
    end

    head :created
  end

  # API endpoint for uploading deobfuscation data. This data typically comes
  # from a renamelog.xml file generated by yGuard.
  #
  # Routes
  # ------
  #
  # * `POST /api/1.0/deobfuscation`

  def deobfuscation
    require_params :api_key, :environment, :build, :namespace

    map = YAML.load(Zlib::Inflate.inflate(Base64.decode64(params['namespace'])))
    return head(:unprocessable_entity) unless map.kind_of?(Squash::Java::Namespace)

    deploy = Project.find_by_api_key!(params['api_key']).
        environments.with_name(params['environment']).first!.
        deploys.find_by_build!(params['build'])
    deploy.obfuscation_map.try :destroy
    deploy.create_obfuscation_map!({namespace: map}, as: :api)

    head :created
  end

  # API endpoint for uploading source-map data. This data typically comes from
  # scripts that upload source maps generated in the process of compiling and
  # minifying JavaScript assets.
  #
  # Routes
  # ------
  #
  # * `POST /api/1.0/sourcemap`

  def sourcemap
    require_params :api_key, :environment, :revision, :sourcemap

    sourcemap = YAML.load(Zlib::Inflate.inflate(Base64.decode64(params['sourcemap'])))
    return head(:unprocessable_entity) unless sourcemap.kind_of?(Squash::Javascript::SourceMap)

    Project.find_by_api_key!(params['api_key']).
        environments.with_name(params['environment']).find_or_create!({name: params['environment']}, as: :worker).
        source_maps.create({map: sourcemap, revision: params['revision']}, as: :api)
    head :created
  end

  private

  def require_params(*req)
    raise(API::InvalidAttributesError, "Missing required parameter") unless req.map(&:to_s).all? { |key| params[key].present? }
  end
end
