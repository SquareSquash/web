require 'spec_helper'

describe "/users" do
  describe "/:id [GET]" do
    it "should route to usernames with dots in them" do
      expect(get: '/users/user.dot').
          to route_to(
                 controller: 'users',
                 action:     'show',
                 id:         'user.dot'
             )
    end

    it "should route to usernames ending in .json" do
      expect(get: '/users/user.json').
          to route_to(
                 controller: 'users',
                 action:     'show',
                 id:         'user.json'
             )
    end
  end
end
