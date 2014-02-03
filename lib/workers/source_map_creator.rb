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

# Worker that decodes a source map from parameters given to the API controller,
# and creates the {SourceMap} object.

class SourceMapCreator
  include BackgroundRunner::Job

  # Creates a new instance and creates the SourceMap.
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

  # Decodes parameters and creates the SourceMap.

  def perform
    project = Project.find_by_api_key(@params['api_key']) or raise(API::UnknownAPIKeyError)
    project.
        environments.with_name(@params['environment']).find_or_create!(name: @params['environment']).
        source_maps.create(raw_map:  @params['sourcemap'],
                           revision: @params['revision'],
                           from:     @params['from'],
                           to:       @params['to'])
  end
end
