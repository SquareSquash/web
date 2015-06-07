# Copyright 2015 Powershop Ltd.
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

# Includes methods for authentication with Google OAuth.
# NONO: Information for the LDAP server
# is stored in the `authentication.yml` Configoro file for the current
# environment. A successful BIND yields an authenticated session.
#
# If this is the user's first time logging in, the User will be created for him
# or her.

module GoogleAuthenticationHelpers
  extend ActiveSupport::Concern

  included do
    def self.third_party_login?
      true
    end
  end

  def log_in
    unless google_auth_data
      logger.tagged('AuthenticationHelpers') { logger.info "Denying login: not Google Auth data provided." }
      return false
    end

    unless user = User.find_or_create_by_google_auth_data(google_auth_data)
      logger.tagged('AuthenticationHelpers') { logger.info "Denying login to #{google_auth_data["email"]}: could not find or create." }
      return false
    end

    log_in_user user
  end

  def login_required_redirect
    logger.info "Redirecting to Big G for Authentication"

    # If we're Google authenticated, find/create user
    # If we're not google-authenticated, then go get it!
    redirect_if_not_google_authenticated unless log_in
  end
end
