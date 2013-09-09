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

# Subclasses `ActionController::Responder` to include a little more detail in
# the JSON response for 422 errors and successful updates. In particular:
#
# * Alters the default response for successful `create` API requests to render
#   the resource representation to the response body.
# * Alters the default response for failing `create` and `update` requests to
#   render the errors object with the object's class name
#   (see {ApplicationController}, section **Typical Responses**).

class JsonDetailResponder < ActionController::Responder
  protected

  # @private
  def json_resource_errors
    {resource.class.model_name.singular => resource.errors}
  end

  # @private
  def api_behavior(error)
    raise error unless resourceful?

    if get?
      display resource
    elsif post?
      display resource, status: :created, location: api_location
    elsif put? || patch?
      display resource, location: api_location
    else
      head :no_content
    end
  end
end
