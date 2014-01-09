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

# Controller for working with a {User}'s {Email Emails}.

class EmailsController < ApplicationController
  before_filter :find_project
  before_filter :find_email, only: :destroy
  respond_to :json

  # Returns a list of the first 10 Emails belonging to the current User,
  # optionally only those under a {Project}.
  #
  # Routes
  # ------
  #
  # * `GET /account/emails.json`
  # * `GET /projects/:project_id/membership/emails.json`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                       |
  # |:-------------|:----------------------|
  # | `project_id` | The {Project}'s slug. |
  #
  # Query Parameters
  # ----------------
  #
  # |         |                                                                                          |
  # |:--------|:-----------------------------------------------------------------------------------------|
  # | `query` | If set, includes only those Emails whose address begins with `query` (case-insensitive). |


  def index
    @emails = current_user.emails.redirected.
        where(project_id: @project.try!(:id)).
        order('email ASC').
        limit(10).
        includes(:user)
    @emails = @emails.where('LOWER(email) LIKE ?', params[:query].downcase + '%') if params[:query].present?

    respond_with @emails do |format|
      format.json { render json: decorate(@emails) }
    end
  end

  # Adds a redirecting (non-primary) Email to the current User, optionally
  # limited to a Project.
  #
  # Routes
  # ------
  #
  # * `POST /account/emails.json`
  # * `POST /projects/:project_id/membership/emails.json`
  #
  # Path Parameters
  # ---------------
  #
  # |              |                       |
  # |:-------------|:----------------------|
  # | `project_id` | The {Project}'s slug. |
  #
  # Body Parameters
  # ---------------
  #
  # |         |                                                   |
  # |:--------|:--------------------------------------------------|
  # | `email` | Parameterized hash of new Email attribute values. |

  def create
    @email = current_user.emails.build(email_params)
    @email.project = @project
    @email.save
    respond_with @email, location: nil
  end

  # Removes a redirecting (non-primary) Email from the current User.
  #
  # Routes
  # ------
  #
  # * `DELETE /account/emails/:id.json`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                    |
  # |:-----|:-------------------|
  # | `id` | The email address. |

  def destroy
    @email.destroy
    respond_with @email
  end

  private

  def find_project
    @project = Project.find_from_slug!(params[:project_id]) if params.include?('project_id')
  end

  def find_email
    @email = current_user.emails.redirected.by_email(params[:id]).first!
  end

  def decorate(emails)
    emails.map do |email|
      email.as_json.merge(
          url: account_email_url(email)
      )
    end
  end

  def email_params
    params.require(:email).permit(:email)
  end
end
