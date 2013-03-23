# Copyright 2012 Square Inc.
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

require 'spec_helper'

describe "/projects/:project_id/memberships" do
  describe "/:id [PUT]" do
    it "should route to usernames with dots in them" do
      expect(put: '/projects/my-project/memberships/user.dot.json').
          to route_to(
                 controller: 'project/memberships',
                 action:     'update',
                 project_id: 'my-project',
                 id:         'user.dot',
                 format:     'json'
             )
    end
  end
end
