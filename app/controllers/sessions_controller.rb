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

# Controller for logging in and logging out of the application. See
# {AuthenticationHelpers} for more information on how authentication works.

class SessionsController < ApplicationController
  skip_before_filter :login_required, only: [:new, :create]
  before_filter :must_be_unauthenticated, except: :destroy

  respond_to :html

  # Displays a page where the user can enter his/her credentials to log in.
  #
  # Routes
  # ------
  #
  # * `GET /login`

  def new
  end

  # Attempts to log a user in. If login fails, or the LDAP server is
  # unreachable, renders the `new` page with a flash alert.
  #
  # If the login is successful, takes the user to the next URL stored in the
  # params; or, if none is set, the root URL.
  #
  # Routes
  # ------
  #
  # * `POST /login`
  #
  # Request Parameters
  # ------------------
  #
  # |        |                                                 |
  # |:-------|:------------------------------------------------|
  # | `next` | A URL to redirect to after login is successful. |
  #
  # Body Parameters
  # ---------------
  #
  # |            |                        |
  # |:-----------|:-----------------------|
  # | `username` | The {User}'s username. |
  # | `password` | The User's password.   |

  def create
    if params[:username].blank? || params[:password].blank?
      return respond_to do |format|
        format.html do
          flash.now[:alert] = t('controllers.sessions.create.missing_field')
          render 'new'
        end
      end
    end

    if log_in(params[:username], params[:password])
      respond_to do |format|
        format.html do
          flash[:success] = t('controllers.sessions.create.logged_in', name: current_user.first_name || current_user.username)
          redirect_to(params[:next].presence || root_url)
        end
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] ||= t('controllers.sessions.create.incorrect_login')
          render 'new'
        end
      end
    end
  end

  # Logs a user out and clears his/her session. Redirects to the login URL.
  #
  # Routes
  # ------
  #
  # * `GET /logout`

  def destroy
    log_out
    redirect_to login_url, notice: t('controllers.sessions.destroy.logged_out')
  end
end
