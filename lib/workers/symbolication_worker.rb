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
# Symbolication, and attempts to symbolicate them using the new map.

class SymbolicationWorker
  include BackgroundRunner::Job

  # Creates a new worker instance and performs a symbolication.
  #
  # @param [Integer] uuid The UUID of a {Symbolication}.

  def self.perform(uuid)
    new(Symbolication.find_by_uuid!(uuid)).perform
  end

  # Creates a new worker instance.
  #
  # @param [Symbolication] sym A symbolication to process.

  def initialize(sym)
    @symbolication = sym
  end

  # Locates relevant Occurrences and attempts to symbolicate them.

  def perform
    @symbolication.occurrences.cursor.each do |occ|
      begin
        occ.symbolicate! @symbolication
        occ.recategorize!
      rescue => err
        # for some reason the cursors gem eats exceptions
        Squash::Ruby.notify err, occurrence: occ
      end
    end
  end
end
