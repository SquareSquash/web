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

# Controller that works with the {Membership Memberships} belonging to the
# current {User}.

class Account::MembershipsController < ApplicationController
  respond_to :json

  # Returns a list of the 10 most recent Project Memberships belonging to the
  # current User.
  #
  # Routes
  # ------
  #
  # * `GET /account/memberships.json`
  #
  # Query Parameters
  # ----------------
  #
  # |         |                                                                                                    |
  # |:--------|:---------------------------------------------------------------------------------------------------|
  # | `query` | If set, includes only those Memberships whose Project name begins with `query` (case-insensitive). |

  def index
    @memberships = current_user.memberships.order('memberships.created_at DESC').limit(10)
    @memberships = @memberships.project_prefix(params[:query]) if params[:query].present?
    # as much as i'd love to add includes(:project), it breaks the join in project_prefix.
    # go ahead, try it and see.

    render json: decorate(@memberships)
  end

  private

  def decorate(memberships)
    memberships.map do |membership|
      membership.as_json.deep_merge(
          project:        membership.project.as_json.merge(url: project_url(membership.project)),
          created_string: l(membership.created_at, format: :short_date),
          human_role:     membership.human_role.capitalize,
          role:           membership.role,
          url:            edit_project_my_membership_url(membership.project),
          delete_url:     project_my_membership_url(membership.project)
      )
    end
  end
end
