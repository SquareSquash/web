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

# Includes methods for authentication using logins and passwords. Passwords are
# stored as salted, hashed strings in accordance with normal security standards.

module PasswordAuthenticationHelpers
  # Attempts to log in a user, given his/her credentials. If the login fails,
  # the reason is logged and tagged with "[AuthenticationHelpers]". If the login
  # is successful, the user ID is written to the session.
  #
  # @param [String] username The username.
  # @param [String] password The password.
  # @return [true, false] Whether or not the login was successful.

  def log_in(username, password)
    user = User.find_by_username(username)
    if user && user.authentic?(password)
      log_in_user user
      return true
    else
      logger.tagged('AuthenticationHelpers') { logger.info "Denying login to #{username}: Invalid credentials." }
      return false
    end
  end
end
