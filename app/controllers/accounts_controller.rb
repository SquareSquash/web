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

# Controller that works with the current {User}.

class AccountsController < ApplicationController
  respond_to :html

  # Displays information about the User and his/her Memberships.
  #
  # Routes
  # ------
  #
  # * `GET /account`

  def show
  end

  # Updates the current user with the attributes in the `:user` parameterized
  # hash.
  #
  # Routes
  # ------
  #
  # * `PATCH /account`
  #
  # Body Parameters
  # ---------------
  #
  # |        |                                                           |
  # |:-------|:----------------------------------------------------------|
  # | `user` | New attributes for the current user (parameterized hash). |

  def update
    if params[:user][:password].blank?
      params[:user].delete 'password'
      params[:user].delete 'password_confirmation'
    end

    current_user.update_attributes user_params
    respond_with current_user do |format|
      format.html do
        if current_user.valid?
          flash[:success] = t('controllers.accounts.update.success')
          redirect_to account_url
        else
          render 'show'
        end
      end
    end
  end if Squash::Configuration.authentication.strategy == 'password'

  private

  def user_params
    params.require(:user).permit(:username, :password, :password_confirmation,
                                 :email_address, :first_name, :last_name)
  end
end
