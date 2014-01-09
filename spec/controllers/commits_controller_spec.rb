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

describe CommitsController do
  describe '#index' do
    before :all do
      Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
    end

    it "should require a logged-in user" do
      get :index, project_id: @project.to_param, format: 'json'
      response.status.should eql(401)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should return the 10 most recent commits" do
        get :index, project_id: @project.to_param, format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).size.should eql(10)
      end
    end
  end

  describe "#context" do
    before :all do
      Project.where(repository_url: "git@github.com:RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "git@github.com:RISCfuture/better_caller.git")
    end
    before(:each) { @valid_params = {project_id: @project.to_param, id: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44', file: 'lib/better_caller/extensions.rb', line: 7, format: 'json'} }

    it "should require a logged-in user" do
      get :context, @valid_params
      response.status.should eql(401)
    end

    context '[authenticated]' do
      before(:each) { login_as @project.owner }

      it "should return an error if the project has no repository" do
        project = FactoryGirl.create(:project, owner: @project.owner, repository_url: 'git@github.com:RISCfuture/doesnt-exist.git')
        get :context, @valid_params.merge(project_id: project.to_param)
        response.status.should eql(422)
        JSON.parse(response.body)['error'].should include('repository')
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
        Project.stub(:find_from_slug!).and_return(@project)
        @project.repo.should_receive(:fetch).once

        get :context, @valid_params.merge(id: '39aacf78b603ade2034e93b9b12420b350dfa151') # unknown revision
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
