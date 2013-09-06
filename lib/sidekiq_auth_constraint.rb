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

# Authorization constraint, used by the Sidekiq routes, that ensures that there
# exists a current user session.

module SidekiqAuthConstraint

  # The default `authorized?` implementation if there is no refined
  # implementation provided by the authentication strategy.

  module Default
    
    # Determines whether a user can access the Sidekiq admin page.
    #
    # @param [ActionDispatch::Request] request A request.
    # @return [true, false] Whether the user can access the Sidekiq admin page.

    def authorized?(request)
      return false unless request.session[:user_id]
      user = User.find(request.session[:user_id])
      !user.nil?
    end
  end

  # first incorporate the default behavior
  extend Default

  # then, if available, incorporate the auth-specific behavior
  begin
    auth_module = "sidekiq_auth_constraint/#{Squash::Configuration.authentication.strategy}".camelize.constantize
    extend auth_module
  rescue NameError
    # no auth module; ignore
  end
end
