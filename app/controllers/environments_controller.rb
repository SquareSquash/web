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

# Controller that works with a {Project}'s {Environment Environments}.
#
# Common
# ======
#
# Path Parameters
# ---------------
#
# |              |                     |
# |:-------------|:--------------------|
# | `project_id` | The Project's slug. |

class EnvironmentsController < ApplicationController
  before_filter :find_project
  before_filter :find_environment, only: :update
  before_filter :admin_login_required, only: :update

  respond_to :json

  # Edits an Environment. Only the Project owner or an admin can modify an
  # Environment.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/environments/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                         |
  # |:-----|:------------------------|
  # | `id` | The Environment's name. |
  #
  # Body Parameters
  # ---------------
  #
  # The body can be JSON- or form URL-encoded.
  #
  # |               |                                           |
  # |:--------------|:------------------------------------------|
  # | `environment` | Parameterized hash of Environment fields. |

  def update
    @environment.update_attributes environment_params
    respond_with @environment, location: project_url(@project)
  end

  private

  def find_environment
    @environment = @project.environments.find_by_name!(params[:id])
  end

  def environment_params
    params.require(:environment).permit(:sends_emails, :notifies_pagerduty)
  end
end
