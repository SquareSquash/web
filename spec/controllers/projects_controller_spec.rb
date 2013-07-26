# encoding: utf-8

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

describe ProjectsController do
  describe "#index" do
    before(:all) { @user = FactoryGirl.create(:user) }

    it "should require a logged-in user" do
      get :index
      response.should redirect_to(login_url(next: request.fullpath))
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

          response.status.should eql(200)
          json = JSON.parse(response.body)
          json.size.should eql(25)
          json.each_with_index do |proj, i|
            proj['url'].should eql("http://test.host/projects/find-me-#{25-i}")
            proj['join_url'].should eql("http://test.host/projects/find-me-#{25-i}/membership/join")
            proj['owner']['url'].should include('/users/')
          end
        end

        it "should return all projects if the query is empty" do
          get :index, format: 'json'
          response.status.should eql(200)
          JSON.parse(response.body).size.should eql(25)
        end
      end
    end
  end

  describe "#create" do
    it "should require a logged-in user" do
      -> { post :create, project: {name: 'New Project', repository_url: 'git://github.com/RISCfuture/better_caller.git'}, format: 'json' }.should_not change(Project, :count)
      response.status.should eql(401)
    end

    context '[authenticated]' do
      before :each do
        login_as(@user = FactoryGirl.create(:user))
        Project.delete_all
      end

      it "should create the new project" do
        post :create, project: {name: 'New Project', repository_url: 'git://github.com/RISCfuture/better_caller.git'}, format: 'json'
        response.status.should eql(201)
        json = JSON.parse(response.body)
        json['name'].should eql('New Project')
        json['repository_url'].should eql('git://github.com/RISCfuture/better_caller.git')
      end

      it "should validate project connectivity" do
        post :create, project: {name: 'New Project', repository_url: 'git://github.com/RISCfuture/nonexistent.git'}, format: 'json'
        response.status.should eql(422)
        json = JSON.parse(response.body)
        json.should eql({'project' => {'repository_url' => ['is not accessible']}})
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
      response.should redirect_to(login_url(next: request.fullpath))
    end

    it "should allow a project member" do
      login_as FactoryGirl.create(:membership, project: @project).user
      get :edit, id: @project.to_param
      response.should be_success
    end

    it "should allow a project admin" do
      login_as FactoryGirl.create(:membership, project: @project, admin: true).user
      get :edit, id: @project.to_param
      response.should be_success
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should create filter_paths_string and whitelist_paths_string attributes" do
        get :edit, id: @project.to_param
        assigns(:project).filter_paths_string.should eql(@project.filter_paths.join("\n"))
        assigns(:project).whitelist_paths_string.should eql(@project.whitelist_paths.join("\n"))
      end
    end
  end

  describe "#update" do
    before :each do
      Project.delete_all
      @project = FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git')
    end

    it "should require a logged-in user" do
      put :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
      response.status.should eql(401)
      @project.reload.name.should_not eql('New Name')
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should not allow admins to alter the project owner" do
        user = FactoryGirl.create(:membership, project: @project, admin: true).user
        login_as user

        put :update, id: @project.to_param, project: {owner_id: user.id}, format: 'json'
        response.status.should eql(400)
        @project.reload.owner.should_not eql(user)
      end

      it "should not allow members to alter the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: false).user
        put :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        response.status.should eql(403)
        @project.reload.name.should_not eql('New Name')
      end

      it "should allow owners to alter the project" do
        put :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        response.status.should eql(200)
        @project.reload.name.should eql('New Name')
        response.body.should eql(@project.to_json)
      end

      it "should convert filter_paths_string into filter_paths" do
        put :update, id: @project.to_param, project: {filter_paths_string: "a\nb\n"}, format: 'json'
        @project.reload.filter_paths.should eql(%w( a b ))
      end

      it "should convert whitelist_paths_string into whitelist_paths" do
        put :update, id: @project.to_param, project: {whitelist_paths_string: "a\nb\n"}, format: 'json'
        @project.reload.whitelist_paths.should eql(%w( a b ))
      end

      it "should not allow protected fields to be set" do
        pending "No protected fields"
      end

      it "should set Project#uses_releases_override if uses_releases is changed" do
        @project.update_attribute :uses_releases, true
        put :update, id: @project.to_param, project: {uses_releases: false}, format: 'json'
        @project.reload.uses_releases?.should be_false
        @project.reload.uses_releases_override?.should be_true
      end

      it "should not set Project#uses_releases_override if uses_releases is not changed" do
        put :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        @project.reload.uses_releases_override?.should be_false
      end
    end
  end

  describe "#rekey" do
      before(:each) { @project = FactoryGirl.create(:project) }

      it "should require a logged-in user" do
        put :update, id: @project.to_param, project: {name: 'New Name'}, format: 'json'
        response.status.should eql(401)
        @project.reload.name.should_not eql('New Name')
      end

      context '[authenticated]' do
        before(:each) { login_as @project.owner }

        it "should not allow members to generate an API key" do
          login_as FactoryGirl.create(:membership, project: @project, admin: false).user
          put :rekey, id: @project.to_param, format: 'json'
          response.status.should eql(403)
          -> { @project.reload }.should_not change(@project, :api_key)
        end

        it "should allow admins to generate an API key" do
          put :rekey, id: @project.to_param, format: 'json'
          response.status.should redirect_to(edit_project_url(@project))
          -> { @project.reload }.should change(@project, :api_key)
          flash[:success].should include(@project.api_key)
        end

        it "should allow owners to generate an API key" do
          put :rekey, id: @project.to_param, format: 'json'
          response.status.should redirect_to(edit_project_url(@project))
          -> { @project.reload }.should change(@project, :api_key)
          flash[:success].should include(@project.api_key)
        end
      end
    end

  describe "#destroy" do
    before(:each) { @project = FactoryGirl.create(:project) }

    it "should require a logged-in user" do
      delete :destroy, id: @project.to_param
      response.status.should redirect_to(login_url(next: request.fullpath))
      -> { @project.reload }.should_not raise_error(ActiveRecord::RecordNotFound)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should not allow admins to delete the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: true).user
        delete :destroy, id: @project.to_param
        response.status.should redirect_to(root_url)
        -> { @project.reload }.should_not raise_error(ActiveRecord::RecordNotFound)
      end

      it "should not allow members to delete the project" do
        login_as FactoryGirl.create(:membership, project: @project, admin: false).user
        delete :destroy, id: @project.to_param
        response.status.should redirect_to(root_url)
        -> { @project.reload }.should_not raise_error(ActiveRecord::RecordNotFound)
      end

      it "should allow owners to delete project" do
        delete :destroy, id: @project.to_param
        response.status.should redirect_to root_url
        flash[:success].should include('was deleted')
        -> { @project.reload }.should raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end

  describe "#context" do
    before(:all) do
      Project.where(repository_url: "https://github.com/RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "https://github.com/RISCfuture/better_caller.git")
    end
    before(:each) { @valid_params = {id: @project.to_param, revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44', file: 'lib/better_caller/extensions.rb', line: 7, format: 'json'} }

    it "should require a logged-in user" do
      get :context, @valid_params
      response.status.should eql(401)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should return an error if the project has no repository" do
        project = FactoryGirl.create(:project, owner: @project.owner, repository_url: 'git://github.com/RISCfuture/doesnt-exist.git')
        get :context, @valid_params.merge(id: project.to_param)
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('repository')
      end

      it "should return an error if the revision param is missing" do
        get :context, @valid_params.merge(revision: nil)
        response.status.should eql(400)
        JSON.parse(response.body)['error'].should include('Missing')
      end

      it "should return an error if the file param is missing" do
        get :context, @valid_params.merge(file: nil)
        response.status.should eql(400)
        JSON.parse(response.body)['error'].should include('Missing')
      end

      it "should return an error if the line param is missing" do
        get :context, @valid_params.merge(line: nil)
        response.status.should eql(400)
        JSON.parse(response.body)['error'].should include('Missing')
      end

      it "should return an error if the line param is less than 1" do
        get :context, @valid_params.merge(line: 0)
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('out of range')
      end

      it "should return an error if the line param is greater than the number of lines in the file" do
        get :context, @valid_params.merge(line: 15)
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('out of range')
      end

      it "should use 3 lines of context by default" do
        get :context, @valid_params
        response.status.should eql(200)
        JSON.parse(response.body)['code'].should eql(<<-TEXT.chomp)
  def set_better_backtrace(bt)
    @better_backtrace = bt.collect do |(file, line, meth, bind)|
      vars = {
        local_variables: eval("local_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        instance_variables: eval("instance_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        global_variables: eval("global_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
      }
        TEXT
      end

      it "should use 3 lines context if an invalid value for the context param is given" do
        get :context, @valid_params.merge(context: -1)
        response.status.should eql(200)
        JSON.parse(response.body)['code'].should eql(<<-TEXT.chomp)
  def set_better_backtrace(bt)
    @better_backtrace = bt.collect do |(file, line, meth, bind)|
      vars = {
        local_variables: eval("local_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        instance_variables: eval("instance_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        global_variables: eval("global_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
      }
        TEXT
      end

      it "should use a custom number of lines of context" do
        get :context, @valid_params.merge(context: 2)
        response.status.should eql(200)
        JSON.parse(response.body)['code'].should eql(<<-TEXT.chomp)
    @better_backtrace = bt.collect do |(file, line, meth, bind)|
      vars = {
        local_variables: eval("local_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        instance_variables: eval("instance_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        global_variables: eval("global_variables.inject({}) { |hsh, var| hsh[var] = eval(var) ; hsh }", bind),
        TEXT
      end

      it "should clamp the context at the top of the file" do
        get :context, @valid_params.merge(line: 1)
        response.status.should eql(200)
        JSON.parse(response.body)['code'].should eql(<<-TEXT.chomp)
# @private
class Exception
  # @private
  def set_better_backtrace(bt)
        TEXT
      end

      it "should clamp the context at the bottom of the file" do
        get :context, @valid_params.merge(line: 14)
        response.status.should eql(200)
        JSON.parse(response.body)['code'].should eql(<<-TEXT.chomp)
      [ file, line, meth, vars]
    end
  end
end
        TEXT
      end

      it "should return an error given a nonexistent path" do
        get :context, @valid_params.merge(file: 'foo/bar.rb')
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('Couldn’t find that commit')
      end

      it "should update the repo given an unknown revision" do
        Project.stub!(:find_from_slug!).and_return(@project)
        @project.repo.should_receive(:fetch).once

        get :context, @valid_params.merge(revision: '39aacf78b603ade2034e93b9b12420b350dfa151') # unknown revision
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('Couldn’t find that commit')
      end

      it "should return an error given a nonexistent file" do
        get :context, @valid_params.merge(file: 'lib/foo.rb')
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('Couldn’t find that commit')
      end

      it "should pick an appropriate brush" do
        get :context, @valid_params
        response.status.should eql(200)
        JSON.parse(response.body)['brush'].should eql('ruby')

        get :context, @valid_params.merge(file: 'Rakefile')
        response.status.should eql(200)
        JSON.parse(response.body)['brush'].should eql('ruby')

        get :context, @valid_params.merge(file: 'ext/better_caller.c')
        response.status.should eql(200)
        JSON.parse(response.body)['brush'].should eql('cpp')
      end

      it "should return a correct first_line value" do
        get :context, @valid_params
        response.status.should eql(200)
        JSON.parse(response.body)['first_line'].should eql(4)
      end

      it "should reject blank lines from the top of the snippet" do
        get :context, @valid_params.merge(file: 'LICENSE.txt', line: 5)
        response.status.should eql(200)
        rsp = JSON.parse(response.body)
        rsp['first_line'].should eql(3)
        rsp['code'].should eql(<<-TEXT.chomp)
Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
        TEXT
      end
    end
  end
end
