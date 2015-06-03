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

# Controller and view mixin with shared methods pertaining for authenticating
# and authorizing {User Users}. For specifics on different authentication
# methods, see {PasswordAuthenticationHelpers} and {LdapAuthenticationHelpers}.
#
# The ID of the authenticated user is stored in the session. The presence of a
# valid user ID in `session[:user_id]` is indicative of an authenticated
# session. Authorization is handled by the {User#role} method.
#
# All public and protected methods are available to all controllers. The
# following methods are also available to all views: {#current_user},
# {#logged_in?}, and {#logged_out?}.

module AuthenticationHelpers
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :logged_in?, :logged_out?, :third_party_login?

    # An overridable method to let the base view disable certain elements that
    # aren't appropriate when using a 3rd-party Login Service (e.g. Logout button)
    def self.third_party_login?
      false
    end
  end

  # Clears a user session.

  def log_out
    # Why doesn't this use #reset_session ?
    session[:user_id] = nil
    @current_user     = nil
  end

  # @return [User, nil] The currently logged-in User, or `nil` if the session is
  #   unauthenticated.

  def current_user
    if session[:user_id] then
      @current_user ||= User.find_by_id(session[:user_id])
    else
      nil
    end
  end

  # @return [true, false] Whether or not the session is authenticated.

  def logged_in?
    !current_user.nil?
  end

  # @return [true, false] Whether or not the session is unauthenticated.

  def logged_out?
    current_user.nil?
  end

  protected

  # A `before_filter` that requires an authenticated session to continue. If the
  # session is unauthenticated...
  #
  # * for HTML requests, redirects to the login URL with a flash notice.
  # * for API and Atom requests, returns a 401 Unauthorized response with an
  #   empty body.

  def login_required
    if logged_in? then
      return true
    else
      respond_to do |format|
        format.xml { head :unauthorized }
        format.json { head :unauthorized }
        format.atom { head :unauthorized }
        format.html { login_required_redirect }
      end
      return false
    end
  end

  # An overridable method for selecting where a not-logged-in redirect goes
  # Primarily used by 3rd-party Login Services

  def login_required_redirect
    redirect_to login_url(next: request.fullpath), notice: t('controllers.authentication.login_required')
  end

  def third_party_login?
    self.class.third_party_login?
  end

  # A `before_filter` that requires an unauthenticated session to continue. If
  # the session is authenticated...
  #
  # * for HTML requests, redirects to the root URL.
  # * for API and Atom requests, returns a 401 Unauthorized response with an
  #   empty body.

  def must_be_unauthenticated
    if logged_in?
      respond_to do |format|
        format.xml { head :unauthorized }
        format.json { head :unauthorized }
        format.atom { head :unauthorized }
        format.html { redirect_to root_url }
      end
      return false
    else
      return true
    end
  end

  # Sets the given user as the current user. Assumes that authentication has
  # already succeeded.
  #
  # @param [User] user A user to log in.

  def log_in_user(user)
    session[:user_id] = user.id
    @current_user     = user
  end
end
