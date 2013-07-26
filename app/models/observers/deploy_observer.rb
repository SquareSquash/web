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

# This observer on the {Deploy} model:
#
# * sets a Project's `uses_releases` attribute if the Deploy has release
#   information.

class DeployObserver < ActiveRecord::Observer
  # @private
  def after_create(deploy)
    update_project_release_setting deploy
  end

  private

  def update_project_release_setting(deploy)
    return unless deploy.release?
    return if deploy.environment.project.uses_releases_override?
    deploy.environment.project.update_attribute :uses_releases, true
  end
end
