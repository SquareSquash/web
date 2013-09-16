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

root = exports ? this

# Formats a Bug's file name, taking into account special files.
#
# @param [Object] bug The Bug.
# @return [String] The abbreviated file name.
#
root.formatBugFile = (bug) ->
  #TODO don't guess, record this information
  if bug.file.match(/^\[S\] /)
    "<simple blamer>"
  else
    parts = bug.file.split('/')
    parts[parts.length  - 1]
