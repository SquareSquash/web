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
