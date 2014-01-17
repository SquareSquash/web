# encoding: utf-8

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

describe ProjectsController do
  describe "#index" do
    before(:all) { @user = FactoryGirl.create(:user) }

    it "should require a logged-in user" do
      get :index
      expect(response).to redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before :all do
        26.times { |i| FactoryGirl.create :project, name: "Find me #{i}" }
        FactoryGirl.create :project, name: "Red Herring"
      end

      before(:each) { login_as @user }

      context '[JSON]' do
        it "should find up to 25 projects by search query" do
          get :index, query: 'find me', format: 'json'

          expect(response.status).to eql(200)
          json = JSON.parse(response.body)
          expect(json.size).to eql(25)
          json.each_with_index do |proj, i|
            expect(proj['url']).to eql("http://test.host/projects/find-me-#{25-i}")
            expect(proj['join_url']).to eql("http://test.host/projects/find-me-#{25-i}/membership/join")
            expect(proj['owner']['url']).to include('/users/')
          end
        end

        it "should return all projects if the query is empty" do
          get :index, format: 'json'
          expect(response.status).to eql(200)
          expect(JSON.parse(response.body).size).to eql(25)
        end
      end
    end
  end

  describe "#create" do
    it "should require a logged-in user" do
      expect { post :create, project: {name: 'New Project', repository_url: 'git@github.com:RISCfuture/better_caller.git'}, format: 'json' }.not_to change(Project, :count)
      expect(response.status).to eql(401)
    end

    context '[authenticated]' do
      before :each do
        login_as(@user = FactoryGirl.create(:user))
        Project.delete_all
      end

      it "should create the new project" do
        post :create, project: {name: 'New Project', repository_url: 'git@github.com:RISCfuture/better_caller.git'}, format: 'json'
        expect(response.status).to eql(201)
        json = JSON.parse(response.body)
        expect(json['name']).to eql('New Project')
        expect(json['repository_url']).to eql('git@github.com:RISCfuture/better_caller.git')
      end

      it "should validate project connectivity" do
        post :create, project: {name: 'New Project', repository_url: 'git@github.com:RISCfuture/nonexistent.git'}, format: 'json'
        expect(response.status).to eql(422)
        json = JSON.parse(response.body)
        expect(json).to eql({'project' => {'repository_url' => ['is not accessible']}})
      end

      it "should not allow protected fields to be set" do
        pending "No protected fields"
      end
    end
  end

  describe "#edit" do
    before(:each) { @project = FactoryGirl.create(:project) }

    it "should require a logged-in user" do
      get :edit, id: @project.to_param
      expect(response).to redirect_to(login_url(next: request.fullpath))
    end

    it "should allow a project member" do
      login_as FactoryGirl.create(:membership, project: @project).user
      get :edit, id: @project.to_param
      expect(response).to be_success
    end

    it "should allow a project admin" do
      login_as FactoryGirl.create(:membership, project: @project, admin: true).user
      get :edit, id: @project.to_param
      expect(response).to be_success
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should create filter_paths_string and whitelist_paths_string attributes" do
        get :edit, id: @project.to_param
        expect(assigns(:project).filter_paths_string).to eql(@project.filter_paths.join("\n"))
        expect(assigns(:project).whitelist_paths_string).to eql(@project.whitelist_paths.join("\n"))
      end
    end
  end

  describe "#update" do
    before :each do
      Project.delete_all
      @project = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
    end

    it "should require a logged-in user" do
      patch :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
      expect(response.status).to eql(401)
      expect(@project.reload.name).not_to eql('New Name')
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should not allow admins to alter the project owner" do
        user = FactoryGirl.create(:membership, project: @project, admin: true).user
        login_as user

        patch :update, id: @project.to_param, project: {owner_id: user.id}, format: 'json'
        expect(response.status).to eql(400)
        expect(@project.reload.owner).not_to eql(user)
      end

      it "should not allow members to alter the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: false).user
        patch :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        expect(response.status).to eql(403)
        expect(@project.reload.name).not_to eql('New Name')
      end

      it "should allow owners to alter the project" do
        patch :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        expect(response.status).to eql(200)
        expect(@project.reload.name).to eql('New Name')
        expect(response.body).to eql(@project.to_json)
      end

      it "should convert filter_paths_string into filter_paths" do
        patch :update, id: @project.to_param, project: {filter_paths_string: "a\nb\n"}, format: 'json'
        expect(@project.reload.filter_paths).to eql(%w( a b ))
      end

      it "should convert whitelist_paths_string into whitelist_paths" do
        patch :update, id: @project.to_param, project: {whitelist_paths_string: "a\nb\n"}, format: 'json'
        expect(@project.reload.whitelist_paths).to eql(%w( a b ))
      end

      it "should not allow protected fields to be set" do
        pending "No protected fields"
      end

      it "should set Project#uses_releases_override if uses_releases is changed" do
        @project.update_attribute :uses_releases, true
        patch :update, id: @project.to_param, project: {uses_releases: false}, format: 'json'
        expect(@project.reload.uses_releases?).to be_false
        expect(@project.reload.uses_releases_override?).to be_true
      end

      it "should not set Project#uses_releases_override if uses_releases is not changed" do
        patch :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        expect(@project.reload.uses_releases_override?).to be_false
      end
    end
  end

  describe "#rekey" do
      before(:each) { @project = FactoryGirl.create(:project) }

      it "should require a logged-in user" do
        patch :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        expect(response.status).to eql(401)
        expect(@project.reload.name).not_to eql('New Name')
      end

      context '[authenticated]' do
        before(:each) { login_as @project.owner }

        it "should not allow members to generate an API key" do
          login_as FactoryGirl.create(:membership, project: @project, admin: false).user
          patch :rekey, id: @project.to_param, format: 'json'
          expect(response.status).to eql(403)
          expect { @project.reload }.not_to change(@project, :api_key)
        end

        it "should allow admins to generate an API key" do
          patch :rekey, id: @project.to_param, format: 'json'
          expect(response.status).to redirect_to(edit_project_url(@project))
          expect { @project.reload }.to change(@project, :api_key)
          expect(flash[:success]).to include(@project.api_key)
        end

        it "should allow owners to generate an API key" do
          patch :rekey, id: @project.to_param, format: 'json'
          expect(response.status).to redirect_to(edit_project_url(@project))
          expect { @project.reload }.to change(@project, :api_key)
          expect(flash[:success]).to include(@project.api_key)
        end
      end
    end

  describe "#destroy" do
    before(:each) { @project = FactoryGirl.create(:project) }

    it "should require a logged-in user" do
      delete :destroy, id: @project.to_param
      expect(response.status).to redirect_to(login_url(next: request.fullpath))
      expect { @project.reload }.not_to raise_error
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should not allow admins to delete the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        delete :destroy, id: @project.to_param
        expect(response.status).to redirect_to(root_url)
        expect { @project.reload }.not_to raise_error
      end

      it "should not allow members to delete the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: false).user
        delete :destroy, id: @project.to_param
        expect(response.status).to redirect_to(root_url)
        expect { @project.reload }.not_to raise_error
      end

      it "should allow owners to delete project" do
        delete :destroy, id: @project.to_param
        expect(response.status).to redirect_to root_url
        expect(flash[:success]).to include('was deleted')
        expect { @project.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
