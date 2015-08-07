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

require 'rails_helper'

RSpec.describe Account::BugsController, type: :controller do
  describe "#index" do
    def sort(bugs, field, reverse=false)
      bugs.sort_by! { |b| [b.send(field), b.number] }
      bugs.reverse! if reverse
      bugs
    end

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      get :index
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      context '[JSON]' do
        context "[type = watched]" do
          before :all do
            @user = FactoryGirl.create(:user)
            env   = FactoryGirl.create(:environment)
            FactoryGirl.create :membership, user: @user, project: env.project
            @bugs = FactoryGirl.create_list(:bug, 10, environment: env)
            @bugs.each { |bug| FactoryGirl.create :watch, user: @user, bug: bug }

            # create an increasing number of occurrences per each bug
            # also creates a random first and latest occurrence
            @bugs.each_with_index do |bug, i|
              Bug.where(id: bug.id).update_all occurrences_count: i + 1,
                                               first_occurrence:  Time.now - rand*86400,
                                               latest_occurrence: Time.now - rand*86400
            end
            @watches = @user.watches.includes(:bug).order('created_at DESC') # reload to get new triggered values
          end

          before(:each) { stub_const 'Account::BugsController::PER_PAGE', 5 } # speed it up

          it "should load 50 of the most recently watched bugs by default" do
            get :index, format: 'json', type: 'watched'
            expect(response.status).to eql(200)
            expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@watches.map(&:bug).map(&:number)[0, 5])
          end

          it "should return the next 50 bugs when given a last parameter" do
            get :index, last: @watches[4].bug.id, format: 'json', type: 'watched'
            expect(response.status).to eql(200)
            expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@watches.map(&:bug).map(&:number)[5, 5])
          end

          it "should decorate the bug JSON" do
            get :index, format: 'json', type: 'watched'
            JSON.parse(response.body).each { |bug| expect(bug['href']).to match(/\/projects\/.+?\/environments\/.+?\/bugs\/#{bug['number']}/) }
          end
        end

        context "[type = assigned]" do
          before :all do
            @user = FactoryGirl.create(:user)
            env   = FactoryGirl.create(:environment)
            FactoryGirl.create :membership, user: @user, project: env.project
            @bugs = FactoryGirl.create_list(:bug, 10, environment: env, assigned_user: @user)

            # create an increasing number of occurrences per each bug
                                # also creates a random first and latest occurrence
            @bugs.each_with_index do |bug, i|
              Bug.where(id: bug.id).update_all occurrences_count: i + 1,
                                               first_occurrence:  Time.now - rand*86400,
                                               latest_occurrence: Time.now - rand*86400
            end
            @bugs.map(&:reload) # get the new triggered values
            sort @bugs, 'latest_occurrence', true
          end

          before(:each) { stub_const 'Account::BugsController::PER_PAGE', 5 } # speed it up

          it "should load 50 of the newest assigned bugs by default" do
            get :index, format: 'json'
            expect(response.status).to eql(200)
            expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@bugs.map(&:number)[0, 5])
          end

          it "should return the next 50 bugs when given a last parameter" do
            get :index, last: @bugs[4].number, format: 'json'
            expect(response.status).to eql(200)
            expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@bugs.map(&:number)[5, 5])
          end

          it "should decorate the bug JSON" do
            get :index, format: 'json'
            JSON.parse(response.body).each { |bug| expect(bug['href']).to match(/\/projects\/.+?\/environments\/.+?\/bugs\/#{bug['number']}/) }
          end
        end
      end
    end
  end
end
