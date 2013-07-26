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
# SourceMap, and attempts to sourcemap them using the new map.

class SourceMapWorker
  include BackgroundRunner::Job

  # Creates a new worker instance and performs a sourcemapping.
  #
  # @param [Integer] map_id The ID of an {SourceMap}.

  def self.perform(map_id)
    new(SourceMap.find(map_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [SourceMap] map A source map to process.

  def initialize(map)
    @map = map
  end

  # Locates relevant Occurrences and attempts to sourcemap them.

  def perform
    @map.environment.bugs.cursor.each do |bug|
      bug.occurrences.where(revision: @map.revision).cursor.each do |occurrence|
        begin
          occurrence.sourcemap! @map
          occurrence.recategorize!
        rescue => err
          # for some reason the cursors gem eats exceptions
          Squash::Ruby.notify err, occurrence: occurrence
        end
      end
    end
  end
end
