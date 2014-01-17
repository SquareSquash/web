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

require 'spec_helper'

describe "ActiveRecord::Base.find_in_batches" do
  context "[single surrogate key]" do
    before :all do
      Project.delete_all; User.delete_all
      @users = FactoryGirl.create_list(:user, 48).in_groups_of(10, false)
    end

    before(:each) { @batches = [] }

    it "should yield all records for lists < batch size" do
      User.find_in_batches(batch_size: 100) { |batch| @batches << batch }
      expect(@batches.size).to eql(1)
      expect(@batches.first.map(&:id)).to eql(@users.flatten.map(&:id))
    end

    it "should yield all records for lists = batch size" do
      User.find_in_batches(batch_size: 48) { |batch| @batches << batch }
      expect(@batches.size).to eql(1)
      expect(@batches.first.map(&:id)).to eql(@users.flatten.map(&:id))
    end

    it "should yield groups of records for lists > batch size" do
      User.find_in_batches(batch_size: 10) { |batch| @batches << batch }
      expect(@batches.size).to eql(5)
      @batches.zip(@users).each do |(batch, users)|
        expect(batch.map(&:id)).to eql(users.map(&:id))
      end
    end

    it "should allow a custom start" do
      User.find_in_batches(batch_size: 10, start: @users.flatten[21].id) { |batch| @batches << batch }
      expect(@batches.size).to eql(3)
      @batches.zip(@users.flatten[21..-1].in_groups_of(10, false)).each do |(batch, users)|
        expect(batch.map(&:id)).to eql(users.map(&:id))
      end
    end
  end

  context "[composite primary keys]" do
    before :all do
      Membership.delete_all
      project = FactoryGirl.create(:project)
      FactoryGirl.create_list(:membership, 47, project: project)
      @memberships = Membership.order(Membership.all.send(:batch_order)).in_groups_of(10, false) # get project owner membership
    end

    before(:each) { @batches = [] }

    it "should yield all records for lists < batch size" do
      Membership.find_in_batches(batch_size: 100) { |batch| @batches << batch }
      expect(@batches.size).to eql(1)
      expect(@batches.first.map { |m| [m.user_id, m.project_id] }).to eql(@memberships.flatten.map { |m| [m.user_id, m.project_id] })
    end

    it "should yield all records for lists = batch size" do
      Membership.find_in_batches(batch_size: 48) { |batch| @batches << batch }
      expect(@batches.size).to eql(1)
      expect(@batches.first.map { |m| [m.user_id, m.project_id] }).to eql(@memberships.flatten.map { |m| [m.user_id, m.project_id] })
    end

    it "should yield groups of records for lists > batch size" do
      Membership.find_in_batches(batch_size: 10) { |batch| @batches << batch }
      expect(@batches.size).to eql(5)
      @batches.zip(@memberships).each do |(batch, memberships)|
        expect(batch.map { |m| [m.user_id, m.project_id] }).to eql(memberships.map { |m| [m.user_id, m.project_id] })
      end
    end

    it "should allow a custom start" do
      start = @memberships.flatten[21].attributes.slice('user_id', 'project_id').values
      Membership.find_in_batches(batch_size: 10, start: start) { |batch| @batches << batch }
      expect(@batches.size).to eql(3)
      @batches.zip(@memberships.flatten[21..-1].in_groups_of(10, false)).each do |(batch, memberships)|
        expect(batch.map { |m| [m.user_id, m.project_id] }).to eql(memberships.map { |m| [m.user_id, m.project_id] })
      end
    end
  end
end
