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

# Very simple worker that fetches a {Project}'s repository.

class ProjectRepoFetcher

  # Creates a new instance and calls {#perform} on it.
  #
  # @param [Integer] project_id The ID of a {Project} whose repository should be
  #   updated.

  def self.perform(project_id)
    new(Project.find(project_id)).perform
  end

  # Creates a new instance.
  #
  # @param [Project] project A Project whose repository should be updated.

  def initialize(project)
    @project = project
  end

  # Fetches the Project's repository.

  def perform
    @project.repo &:fetch
  end
end
