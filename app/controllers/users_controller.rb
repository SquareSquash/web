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

# Controller for working with {User Users}.

class UsersController < ApplicationController
  skip_before_filter :login_required, only: :create
  before_filter :must_be_unauthenticated, only: :create
  before_filter :find_user, only: :show

  respond_to :html, only: [:show, :create]
  respond_to :json, only: :index

  def index
    return respond_with([]) if params[:query].blank?

    @users = User.prefix(params[:query]).limit(10).order('username ASC')

    last = params[:last].present? ? User.find_by_username(params[:last]) : nil
    @users = @users.where(infinite_scroll_clause('username', 'ASC', last, 'username')) if last

    project = params[:project_id].present? ? Project.find_from_slug!(params[:project_id]) : nil
    respond_with decorate(@users, project)
  end

  # Displays information about a user.
  #
  # Routes
  # ------
  #
  # * `GET /users/:id`
  #
  # Path Parameters
  # ---------------
  #
  # |      |                      |
  # |:-----|:---------------------|
  # | `id` | The User's username. |

  def show
  end

  # Creates a new User account. For password authenticating installs only. The
  # `email_address` and `password_confirmation` virtual fields must be
  # specified.
  #
  # If the signup is successful, takes the user to the next URL stored in the
  # params; or, if none is set, the root URL.
  #
  # Routes
  # ------
  #
  # * `POST /users`
  #
  # Request Parameters
  #
  # |        |                                            |
  # |:-------|:-------------------------------------------|
  # | `next` | The URL to go to after signup is complete. |
  #
  # Body Parameters
  # ---------------
  #
  # |        |                          |
  # |:-------|:-------------------------|
  # | `user` | The new User parameters. |

  def create
    unless Squash::Configuration.authentication.registration_enabled?
      return redirect_to(login_url, alert: t('controllers.users.create.disabled'))
    end

    @user = User.create(user_params)
    respond_with @user do |format|
      format.html do
        if @user.valid?
          log_in_user @user
          flash[:success] = t('controllers.users.create.success', name: @user.first_name || @user.username)
          redirect_to (params[:next].presence || root_url)
        else
          render 'sessions/new'
        end
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'

  private

  def find_user
    @user = User.find_by_username!(params[:id])
  end

  def decorate(users, project=nil)
    users.map do |user|
      user.as_json.merge(is_member: project ? user.memberships.where(project_id: project.id).exists? : nil)
    end
  end

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation,
                                 :email_address, :first_name, :last_name)
  end
end
