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

require 'digest/sha2'

module Blamer

  # A simple, Git-free blamer that groups occurrences with identical stack
  # traces. While less cool than the {Blamer::Recency Recency} blamer, it has
  # the advantage of not requiring access to the Git repository.

  class Simple < Base

    protected

    def bug_search_criteria
      @special = true
      file     = '[S] ' + Digest::SHA2.hexdigest(occurrence.faulted_backtrace.to_json)

      {
          class_name:      occurrence.bug.class_name,
          file:            file,
          line:            1,
          blamed_revision: nil
      }
    end
  end
end
