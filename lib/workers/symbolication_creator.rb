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

# Worker that decodes a symbolication table from parameters given to the API
# controller, and creates the {Symbolication} object.

class SymbolicationCreator
  include BackgroundRunner::Job

  # Creates a new instance and creates the Symbolication.
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

  # Decodes parameters and creates the Symbolication.

  def perform
    @params['symbolications'].each do |attrs|
      Symbolication.where(uuid: attrs['uuid']).create_or_update do |symbolication|
        symbolication.send :write_attribute, :symbols, attrs['symbols']
        symbolication.send :write_attribute, :lines, attrs['lines']
      end
    end  end
end
