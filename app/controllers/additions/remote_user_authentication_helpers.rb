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

# Includes methods for authentication using headers from the request
#
# If this is the user's first time logging in, the User will be created for him
# or her.

module RemoteUserAuthenticationHelpers
  extend ActiveSupport::Concern

  included do
    prepend_before_filter do
      log_in
    end
  end

  # Attempts to log in a user, given his/her credentials. If the login fails,
  # the reason is logged and tagged with "[AuthenticationHelpers]". If the login
  # is successful, the user ID is written to the session. Also creates or
  # updates the User as appropriate.
  #
  # @return [true, false] Whether or not the login was successful.

  def log_in *_
    username = request.env['REMOTE_USER']

    if username
      user = find_or_create_user_from_env(username)
      log_in_user user
      return true
    else
      return false
    end
  end

  private

  def find_or_create_user_from_env(username)
    User.where(username: username).create_or_update!
  end
end
