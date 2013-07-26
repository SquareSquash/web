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

require 'spec_helper'

describe Account::MembershipsController do
  describe "#index" do
    before :all do
      @user               = FactoryGirl.create(:user)
      @filter_memberships = 11.times.map { FactoryGirl.create(:membership, user: @user, created_at: Time.now - 1.month, project: FactoryGirl.create(:project, name: 'Filter me')) }
      @memberships        = FactoryGirl.create_list(:membership, 11, user: @user)
    end

    it "should require a logged-in user" do
      get :index, format: 'json'
      response.status.should eql(401)
      response.body.should be_blank
    end

    context "[authenticated]" do
      before(:each) { login_as @user }

      it "should load the first 10 memberships" do
        get :index, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['project']['name'] }.should eql(@memberships.sort_by(&:created_at).reverse.map(&:project).map(&:name)[0, 10])
      end

      it "should filter memberships by name when a query is given" do
        get :index, format: 'json', query: 'filter'
        response.status.should eql(200)
        JSON.parse(response.body).map { |r| r['project']['name'] }.should eql(@filter_memberships.sort_by(&:created_at).reverse.map(&:project).map(&:name)[0, 10])
      end
    end
  end
end
