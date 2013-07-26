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

# Worker that loads Occurrences affected by the addition of a new
# ObfuscationMap, and attempts to deobfuscate them using the new map.

class ObfuscationMapWorker
  include BackgroundRunner::Job

  # Creates a new worker instance and performs a deobfuscation.
  #
  # @param [Integer] map_id The ID of an {ObfuscationMap}.

  def self.perform(map_id)
    new(ObfuscationMap.find(map_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [ObfuscationMap] map An obfuscation map to process.

  def initialize(map)
    @map = map
  end

  # Locates relevant Occurrences and attempts to deobfuscate them.

  def perform
    @map.deploy.bugs.cursor.each do |bug|
      bug.occurrences.cursor.each do |occ|
        begin
          occ.deobfuscate! @map
          occ.recategorize!
        rescue => err
          # for some reason the cursors gem eats exceptions
          Squash::Ruby.notify err, occurrence: occ
        end
      end
    end
  end
end
