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

# Worker that decodes an obfuscation map from parameters given to the API
# controller, and creates the {ObfuscationMap} object.

class ObfuscationMapCreator
  include BackgroundRunner::Job

  # Creates a new instance and creates the ObfuscationMap.
  #
  # @param [Hash] params Parameters passed to the API controller.

  def self.perform(params)
    new(params).perform
  end

  # Creates a new instance with the given parameters.
  #
  # @param [Hash] params Parameters passed to the API controller.

  def initialize(params)
    @params = params
  end

  # Decodes parameters and creates the ObfuscationMap.

  def perform
    map = YAML.load(Zlib::Inflate.inflate(Base64.decode64(@params['namespace'])), safe: true, deserialize_symbols: false)
    return unless map.kind_of?(Squash::Java::Namespace)

    project = Project.find_by_api_key(@params['api_key']) or raise(API::UnknownAPIKeyError)
    deploy = project.
        environments.with_name(@params['environment']).first!.
        deploys.find_by_build!(@params['build'])
    deploy.obfuscation_map.try! :destroy
    deploy.create_obfuscation_map!(namespace: map)
  end
end
