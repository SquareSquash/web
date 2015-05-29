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

# Includes methods for authentication with LDAP. Information for the LDAP server
# is stored in the `authentication.yml` Configoro file for the current
# environment. A successful BIND yields an authenticated session.
#
# If this is the user's first time logging in, the User will be created for him
# or her.

module GoogleAuthenticationHelpers
  def log_in
    return false unless google_auth_data
    # If you're authenticated by Google, if this fails, it should asplode:
    log_in_user User.find_or_create_by_google_auth_data!(google_auth_data)
  end

  # We don't want to redirect to a the Squash login page with this
  # authenticator
  def login_required
    logger.info "Current User = #{current_user.inspect}"
    logger.info "Google Auth Data = #{google_auth_data.inspect}"

    return true if logged_in?

    respond_to do |format|
      format.xml { head :unauthorized }
      format.json { head :unauthorized }
      format.atom { head :unauthorized }
      format.html do
        logger.info "Redirecting to Big G for Authentication"
        # If we're Google authenticated, find/create user
        # If we're not google-authenticated, then go get it!
        redirect_if_not_google_authenticated unless log_in
      end
    end
    return false
  end
end
