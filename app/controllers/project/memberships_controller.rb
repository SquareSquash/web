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

# Controller that works with {Membership Memberships} belonging to a {Project}.
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

class Project::MembershipsController < ApplicationController
  before_filter :find_project
  before_filter :find_membership, only: [:update, :destroy]
  before_filter :admin_login_required, except: :index

  respond_to :json

  # Returns a list of the 10 most recently-created memberships to a project.
  #
  # Routes
  # ------
  #
  # * `GET /projects/:project_id/memberships.json`
  #
  # Query Parameters
  # ----------------
  #
  # |         |                                                                                                    |
  # |:--------|:---------------------------------------------------------------------------------------------------|
  # | `query` | If set, includes only those memberships where the username begins with `query` (case-insensitive). |

  def index
    respond_to do |format|
      format.json do
        @memberships = @project.memberships.order('created_at DESC').limit(10)
        @memberships = @memberships.user_prefix(params[:query]) if params[:query].present?

        render json: decorate(@memberships)
      end
    end
  end

  # Adds a user to this project.
  #
  # Routes
  # ------
  #
  # * `POST /projects/:project_id/memberships.json`
  #
  # Body Parameters
  # ---------------
  #
  # The body parameters can be JSON- or form URL-encoded.
  #
  # |              |                                          |
  # |:-------------|:-----------------------------------------|
  # | `membership` | Parameterized hash of Membership fields. |

  def create
    if params[:membership][:user_username]
      params[:membership][:user_id] = User.find_by_username(params[:membership].delete('user_username')).try!(:id)
    end

    @membership = @project.memberships.create(membership_params)
    respond_with @project, @membership
  end

  # Alters a user's membership to this project.
  #
  # Routes
  # ------
  #
  # * `PATCH /projects/:project_id/memberships/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                        |
  # |:-----|:-----------------------|
  # | `id` | The {User}'s username. |
  #
  # Body Parameters
  # ---------------
  #
  # The body parameters can be JSON- or form URL-encoded.
  #
  # |              |                                          |
  # |:-------------|:-----------------------------------------|
  # | `membership` | Parameterized hash of Membership fields. |

  def update
    @membership.update_attributes membership_params

    respond_with @project, @membership
  end

  # Removes a user from this project.
  #
  # Routes
  # ------
  #
  # * `DELETE /projects/:project_id/memberships/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                      |
  # |:-----|:---------------------|
  # | `id` | The User's username. |

  def destroy
    if current_user.role(@project) == :admin && @membership.admin?
      return respond_to do |format|
        format.json { head :forbidden }
      end
    end

    @membership.destroy
    head :no_content
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id])
  end

  def find_membership
    @membership = @project.memberships.find_by_user_id!(User.find_by_username!(params[:id]))
  end

  def decorate(memberships)
    memberships.map do |membership|
      membership.as_json(include: [:user, :project]).deep_merge(
          user:           membership.user.as_json.merge(url: user_url(membership.user), name: membership.user.name),
          created_string: l(membership.created_at, format: :short_date),
          human_role:     membership.human_role.capitalize,
          role:           membership.role
      )
    end
  end

  def membership_params
    params.require(:membership).permit(*(
        case current_user.role(@project)
          when :admin
            [:user_id]
          when :owner
            [:user_id, :admin]
        end
    ))
  end
end
