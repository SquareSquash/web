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

# Singleton resource controller for working with the current {User}'s
# {Membership} in a {Project}.

class Project::MembershipController < ApplicationController
  before_filter :find_project
  before_filter :find_membership, except: :join
  before_filter :must_not_be_owner, only: :destroy

  respond_to :html, :json

  # Creates a new Membership linking this Project to the current User. The user
  # will have member privileges.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/membership/join`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                                                                       |
  # |:-------------|:----------------------------------------------------------------------|
  # | `project_id` | The Project's slug.                                                   |
  # | `next`       | For HTML requests, the URL to be taken to next (default project URL). |

  def join
    @membership = @project.memberships.where(user_id: current_user.id).find_or_create! { |m| m.user = current_user }
    respond_with @membership, location: project_url(@project)
  end

  # Displays a form where a User can modify their Membership settings.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/membership/edit`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                     |
  # |:-------------|:--------------------|
  # | `project_id` | The Project's slug. |

  def edit
    respond_with @membership
  end

  # Updates a User's email settings for this Membership's Project.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/membership`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                     |
  # |:-------------|:--------------------|
  # | `project_id` | The Project's slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |              |                                                        |
  # |:-------------|:-------------------------------------------------------|
  # | `membership` | Parameterized hash of new Membership attribute values. |

  def update
    @membership.update_attributes membership_params
    respond_with @membership, location: edit_project_my_membership_url(@project)
  end

  # Removes membership from a Project. A Project owner cannot leave his/her
  # Project without first reassigning ownership.
  #
  # Routes
  # ------
  #
  # * `DELETE /project/:project_id/membership`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                     |
  # |:-------------|:--------------------|
  # | `project_id` | The Project's slug. |
  #
  # Responses
  # ---------
  #
  # ### Deleting an owned project
  #
  # If the User attempts to delete a Project s/he owns, a 401 Unauthorized
  # status is returned with an empty response body.

  def destroy
    @membership.destroy
    respond_with @membership do |format|
      format.html { redirect_to account_url, flash: {success: t('controllers.project.membership.destroy.deleted', name: @membership.project.name)} }
    end
  end

  private

  def find_membership
    @membership = current_user.memberships.find_by_project_id!(@project.id)
  end

  def must_not_be_owner
    if @membership.role == :owner
      respond_to do |format|
        format.html { redirect_to account_url, alert: t('controllers.project.membership.must_not_be_owner') }
      end
      return false
    else
      return true
    end
  end

  def membership_params
    params.require(:membership).permit(:send_assignment_emails,
                                       :send_comment_emails,
                                       :send_resolution_emails)
  end
end
