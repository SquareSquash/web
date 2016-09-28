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

RSpec.describe BugsController, type: :controller do
  describe "#index" do
    before :all do
      membership = FactoryGirl.create(:membership)
      @env       = FactoryGirl.create(:environment, project: membership.project)
      @bugs      = 10.times.map do |i|
        FactoryGirl.create :bug,
                           environment:      @env,
                           message_template: 'bug is ' + (i.even? ? 'even' : 'odd'),
                           irrelevant:       (i % 10 == 3)
        # set some random field values to filter on
      end
      @user      = membership.user

      # create an increasing number of occurrences per each bug
      # also creates a random first and latest occurrence
      @bugs.each_with_index do |bug, i|
        Bug.where(id: bug.id).update_all occurrences_count: i + 1,
                                         first_occurrence:  Time.now - rand*86400,
                                         latest_occurrence: Time.now - rand*86400
      end
      @bugs = @env.bugs(true).to_a # reload to get those fields set by triggers
    end

    before(:each) { stub_const 'BugsController::PER_PAGE', 5 } # speed it up

    def sort(bugs, field, reverse=false)
      bugs.sort_by! { |b| [b.send(field), b.number] }
      bugs.reverse! if reverse
      bugs
    end

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      get :index, polymorphic_params(@env, true)
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @user }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@env, true)'

      context '[JSON]' do
        it "should load 50 of the most recently occurring bugs by default" do
          get :index, polymorphic_params(@env, true, format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :latest_occurrence, true).map(&:number)[0, 5])

          get :index, polymorphic_params(@env, true, dir: 'asc', format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :latest_occurrence).map(&:number)[0, 5])
        end

        it "should also sort by first occurrence" do
          get :index, polymorphic_params(@env, true, sort: 'first', format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :first_occurrence).map(&:number)[0, 5])

          get :index, polymorphic_params(@env, true, sort: 'first', dir: 'desc', format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :first_occurrence, true).map(&:number)[0, 5])
        end

        it "should also sort by occurrence count" do
          get :index, polymorphic_params(@env, true, sort: 'occurrences', format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :occurrences_count, true).map(&:number)[0, 5])

          get :index, polymorphic_params(@env, true, sort: 'occurrences', dir: 'asc', format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :occurrences_count).map(&:number)[0, 5])
        end

        it "should return the next 50 bugs when given a last parameter" do
          sort @bugs, :latest_occurrence, true
          get :index, polymorphic_params(@env, true, last: @bugs[4].number, format: 'json')
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(@bugs.map(&:number)[5, 5])
        end

        it "should decorate the bug JSON" do
          get :index, polymorphic_params(@env, true, format: 'json')
          JSON.parse(response.body).each { |bug| expect(bug['href']).to eql(project_environment_bug_url(@env.project, @env, bug['number'])) }
        end

        it "should filter by bug attributes" do
          get :index, polymorphic_params(@env, true, format: 'json', filter: {irrelevant: 'true'})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :latest_occurrence, true).select(&:irrelevant).map(&:number)[0, 5])
        end

        it "should treat deploy_id=nil as any deploy_id value" do
          deployed   = FactoryGirl.create(:bug, environment: @env, deploy: FactoryGirl.create(:deploy, environment: @env))
          undeployed = FactoryGirl.create(:bug, environment: @env, deploy: nil)
          get :index, polymorphic_params(@env, true, format: 'json', filter: {deploy_id: nil})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(deployed.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(undeployed.number)
        end

        it "should treat crashed=nil as any crashed value" do
          crashed = FactoryGirl.create(:bug, environment: @env, any_occurrence_crashed: true)
          uncrashed = FactoryGirl.create(:bug, environment: @env, any_occurrence_crashed: false)

          get :index, polymorphic_params(@env, true, format: 'json', filter: {any_occurrence_crashed: nil})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(crashed.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(uncrashed.number)

          get :index, polymorphic_params(@env, true, format: 'json', filter: {any_occurrence_crashed: true})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(crashed.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).not_to include(uncrashed.number)

          get :index, polymorphic_params(@env, true, format: 'json', filter: {any_occurrence_crashed: false})
          expect(JSON.parse(response.body).map { |r| r['number'] }).not_to include(crashed.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(uncrashed.number)
        end

        it "should treat assigned_user_id=anybody as all exceptions" do
          assigned   = FactoryGirl.create(:bug, environment: @env, assigned_user: @user)
          unassigned = FactoryGirl.create(:bug, environment: @env, assigned_user: nil)
          get :index, polymorphic_params(@env, true, format: 'json', filter: {assigned_user_id: 'anybody'})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(assigned.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(unassigned.number)
        end

        it "should treat assigned_user_id=nobody as all unassigned bugs" do
          assigned   = FactoryGirl.create(:bug, environment: @env, assigned_user: @user)
          unassigned = FactoryGirl.create(:bug, environment: @env, assigned_user: nil)
          get :index, polymorphic_params(@env, true, format: 'json', filter: {assigned_user_id: 'nobody'})
          expect(JSON.parse(response.body).map { |r| r['number'] }).not_to include(assigned.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(unassigned.number)
        end

        it "should treat assigned_user_id=somebody as any assigned user" do
          assigned   = FactoryGirl.create(:bug, environment: @env, assigned_user: @user)
          unassigned = FactoryGirl.create(:bug, environment: @env, assigned_user: nil)
          get :index, polymorphic_params(@env, true, format: 'json', filter: {assigned_user_id: 'somebody'})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to include(assigned.number)
          expect(JSON.parse(response.body).map { |r| r['number'] }).not_to include(unassigned.number)
        end

        it "should filter by search query" do
          get :index, polymorphic_params(@env, true, format: 'json', filter: {search: 'even'})
          expect(JSON.parse(response.body).map { |r| r['number'] }).to eql(sort(@bugs, :latest_occurrence, true).select { |b| b.message_template.include?('even') }.map(&:number)[0, 5])
        end

        it "should gracefully handle an invalid search query" do
          get :index, polymorphic_params(@env, true, format: 'json', filter: {search: 'A:Toaster'})
          expect(response.status).to eql(422)
        end
      end
    end
  end

  describe "#show" do
    before(:each) do
      Project.where(repository_url: 'https://github.com/RISCfuture/better_caller.git').delete_all
      @project = FactoryGirl.create(:project, repository_url: 'https://github.com/RISCfuture/better_caller.git')
      @bug     = FactoryGirl.create(:bug, environment: FactoryGirl.create(:environment, project: @project))
      FactoryGirl.create :rails_occurrence, bug: @bug
      repo = double('Git::Repo')
    end

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      get :show, polymorphic_params(@bug, false)
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :get, :show, 'polymorphic_params(@bug, false)'

      it "should set duplicate_of_number" do
        dupe = FactoryGirl.create(:bug, environment: @bug.environment)
        @bug.update_attribute :duplicate_of, dupe

        get :show, polymorphic_params(@bug, false)
        expect(assigns(:bug).duplicate_of_number).to eql(dupe.number)
      end
    end
  end

  describe "#update" do
    before(:each) { @bug = FactoryGirl.create(:bug) }

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true'})
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect(@bug.reload).not_to be_fixed
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :patch, :update, 'polymorphic_params(@bug, false, bug: { fixed: true })'
      it_should_behave_like "singleton action that 404s at appropriate times", :patch, :update, 'polymorphic_params(@bug, false, bug: { fixed: true })'

      it "should update the bug" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true'}, format: 'json')
        expect(@bug.reload).to be_fixed
        expect(response.body).to eql(@bug.to_json)
      end

      it "should set the bug modifier" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true'}, format: 'json')
        expect(assigns(:bug).modifier).to eql(@bug.environment.project.owner)
      end

      it "should add a comment if in the params" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true'}, comment: {body: 'hai!'}, format: 'json')
        expect(@bug.reload).to be_fixed
        expect(@bug.comments.count).to eql(1)
        expect(@bug.comments.first.body).to eql('hai!')
        expect(@bug.comments.first.user_id).to eql(@bug.environment.project.owner_id)
      end

      it "should not add a blank comment" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true'}, comment: {body: '  '}, format: 'json')
        expect(@bug.reload).to be_fixed
        expect(@bug.comments.count).to eql(0)
      end

      it "should limit owners to only updating owner-accessible fields"
      it "should limit admins to only updating admin-accessible fields"
      it "should limit members to only updating member-accessible fields"

      it "should set duplicate_of_id from duplicate_of_number" do
        other = FactoryGirl.create(:bug, environment: @bug.environment)
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true', duplicate_of_number: other.number}, format: 'json')
        expect(@bug.reload.duplicate_of_id).to eql(other.id)
        expect(@bug).to be_fixed
      end

      it "should copy errors of duplicate_of_id to duplicate_of_number" do
        FactoryGirl.create :bug, environment: @bug.environment, duplicate_of: @bug
        other = FactoryGirl.create(:bug, environment: @bug.environment)
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true', duplicate_of_number: other.number}, format: 'json')
        expect(response.status).to eql(422)
        expect(JSON.parse(response.body)['bug']['duplicate_of_number']).to eql(['cannot be marked as duplicate because other bugs have been marked as duplicates of this bug'])
      end

      it "should add an error and not save the record if the duplicate-of number does not exist" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true', duplicate_of_number: 0}, format: 'json')
        expect(response.status).to eql(422)
        expect(JSON.parse(response.body)['bug']['duplicate_of_number']).to eql(['unknown bug number'])
      end

      it "... unless no duplicate-of number was entered" do
        patch :update, polymorphic_params(@bug, false, bug: {fixed: 'true', duplicate_of_number: ' '}, format: 'json')
        expect(response.status).to eql(200)
      end

      it "should allow the JIRA status to be nullified" do
        @bug.update_attribute :jira_status_id, 6
        patch :update, polymorphic_params(@bug, false, bug: {jira_status_id: ''}, format: 'json')
        expect(response.status).to eql(200)
        expect(@bug.reload.jira_status_id).to be_nil
      end
    end
  end

  describe "#destroy" do
    before(:each) { @bug = FactoryGirl.create(:bug) }

    include_context "setup for required logged-in user"
    it "should require a logged-in user" do
      delete :destroy, polymorphic_params(@bug, false)
      expect(response).to redirect_to(login_required_redirection_url(next: request.fullpath))
      expect { @bug.reload }.not_to raise_error
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@bug, false)'
      it_should_behave_like "singleton action that 404s at appropriate times", :delete, :destroy, 'polymorphic_params(@bug, false)'

      it "should destroy the bug" do
        delete :destroy, polymorphic_params(@bug, false)
        expect { @bug.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "should redirect with a notice" do
        delete :destroy, polymorphic_params(@bug, false)
        expect(response).to redirect_to(project_environment_bugs_url(@bug.environment.project, @bug.environment))
        expect(flash[:success]).to include('was deleted')
      end
    end
  end

  describe "#watch" do
    before(:each) { @bug = FactoryGirl.create(:bug) }

    it "should require a logged-in user" do
      post :watch, polymorphic_params(@bug, false, format: 'json')
      expect(response.status).to eql(401)
    end

    context '[authenticated]' do
      before(:each) { login_as(@user = @bug.environment.project.owner) }

      it_should_behave_like "action that 404s at appropriate times", :post, :watch, 'polymorphic_params(@bug, false, format: "json")'
      it_should_behave_like "singleton action that 404s at appropriate times", :post, :watch, 'polymorphic_params(@bug, false, format: "json")'

      it "should watch an unwatched bug" do
        post :watch, polymorphic_params(@bug, false, format: 'json')
        expect(@user.watches.where(bug_id: @bug.id)).not_to be_empty
      end

      it "should unwatch a watched bug" do
        FactoryGirl.create :watch, user: @user, bug: @bug
        post :watch, polymorphic_params(@bug, false, format: 'json')
        expect(@user.watches.where(bug_id: @bug.id)).to be_empty
      end
    end
  end

  describe "#notify_deploy" do
    before(:each) { @bug = FactoryGirl.create(:bug) }

    it "should require a logged-in user" do
      post :notify_deploy, polymorphic_params(@bug, false, format: 'json')
      expect(response.status).to eql(401)
      expect { @bug.reload }.not_to change(@bug, :notify_on_deploy)
    end

    context '[authenticated]' do
      before(:each) { login_as(@user = @bug.environment.project.owner) }

      it_should_behave_like "action that 404s at appropriate times", :post, :notify_deploy, 'polymorphic_params(@bug, false, format: "json")'
      it_should_behave_like "singleton action that 404s at appropriate times", :post, :notify_deploy, 'polymorphic_params(@bug, false, format: "json")'

      it "should add the current user to the deploy notifications list" do
        post :notify_deploy, polymorphic_params(@bug, false, format: 'json')
        expect(@bug.reload.notify_on_deploy).to include(@user.id)
      end

      it "should remove the current user from the deploy notifications list" do
        @bug.update_attribute :notify_on_deploy, [@user.id]
        post :notify_deploy, polymorphic_params(@bug, false, format: 'json')
        expect(@bug.reload.notify_on_deploy).not_to include(@user.id)
      end
    end
  end

  describe "#notify_occurrence" do
    before(:each) { @bug = FactoryGirl.create(:bug) }

    it "should require a logged-in user" do
      post :notify_occurrence, polymorphic_params(@bug, false, format: 'json')
      expect(response.status).to eql(401)
      expect { @bug.reload }.not_to change(@bug, :notify_on_occurrence)
    end

    context '[authenticated]' do
      before(:each) { login_as(@user = @bug.environment.project.owner) }

      it_should_behave_like "action that 404s at appropriate times", :post, :notify_occurrence, 'polymorphic_params(@bug, false, format: "json")'
      it_should_behave_like "singleton action that 404s at appropriate times", :post, :notify_occurrence, 'polymorphic_params(@bug, false, format: "json")'

      it "should add the current user to the occurrence notifications list" do
        post :notify_occurrence, polymorphic_params(@bug, false, format: 'json')
        expect(@bug.reload.notify_on_occurrence).to include(@user.id)
      end

      it "should remove the current user from the occurrence notifications list" do
        @bug.update_attribute :notify_on_occurrence, [@user.id]
        post :notify_occurrence, polymorphic_params(@bug, false, format: 'json')
        expect(@bug.reload.notify_on_occurrence).not_to include(@user.id)
      end
    end
  end
end
