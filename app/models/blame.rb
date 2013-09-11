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

# The cached result of a `git-blame` operation. Some blamers use this table as a
# write-through cache of these results by means of {Blamer::Cache}.
#
# Properties
# ----------
#
# |                   |                                                                                       |
# |:------------------|:--------------------------------------------------------------------------------------|
# | `repository_hash` | The SHA1 hash of the URL of the Git repository where the operation was run.           |
# | `revision`        | The Git revision active at the time of the blame operation.                           |
# | `file`            | The file on which the blame was run.                                                  |
# | `line`            | The line in the file on which the blame was run.                                      |
# | `blamed_revision` | The revision that most recently modified that file and line, on or before `revision`. |

class Blame < ActiveRecord::Base
  validates :repository_hash, :revision, :blamed_revision,
            presence: true,
            length:   {is: 40},
            format:   {with: /\A[0-9a-f]+\z/}
  validates :file,
            presence: true,
            length:   {maximum: 255}
  validates :line,
            presence:     true,
            numericality: {only_integer: true, greater_than: 0}

  scope :for_project, ->(project) { where(repository_hash: project.repository_hash) }
end
