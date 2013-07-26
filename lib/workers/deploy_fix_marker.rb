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

# This worker is invoked after a new {Deploy} is created. It finds all
# {Bug Bugs} that have been resolved with a resolution commit that is included
# as part of this deploy, and then sets `fix_deployed` for those bugs to true.
#
# Loading commits is paginated to prevent locks when processing a repo with a
# large history.

class DeployFixMarker
  include BackgroundRunner::Job

  # The number of commits to load per page.
  COMMIT_PAGE_SIZE = 50

  # Loads a Deploy from an ID, and marks appropriate Bugs as `fix_deployed`.
  #
  # @param [Integer] deploy_id The ID of a {Deploy} to process.

  def self.perform(deploy_id)
    new(Deploy.find(deploy_id)).perform
  end

  # Creates a new instance.
  #
  # @param [Deploy] deploy A deploy to process.

  def initialize(deploy)
    @deploy = deploy
  end

  # Marks appropriate Bugs as `fix_deployed`.

  def perform
    offset = 0

    @deploy.environment.project.repo(&:fetch)

    while (commits = @deploy.environment.project.repo.log(COMMIT_PAGE_SIZE).skip(offset).object(@deploy.revision)).any?
      @deploy.environment.bugs.where(resolution_revision: commits.map(&:sha), fixed: true, fix_deployed: false).find_each do |bug|
        bug.fixing_deploy = @deploy
        bug.fix_deployed = true
        bug.save!
      end
      offset += COMMIT_PAGE_SIZE
    end
  rescue Git::GitExecuteError
    # chances are this occurred because the deploy revision was unknown
    # probably due to a force-push that deleted the revision
    # in this case, just eat the exception and abort
  end
end
