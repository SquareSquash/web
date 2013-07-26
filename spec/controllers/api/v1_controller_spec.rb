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
require 'fdoc/spec_watcher'

describe Api::V1Controller do
  include Fdoc::SpecWatcher

  describe "#notify", fdoc: '/notify' do
    before :all do
      Project.where(repository_url: "https://github.com/RISCfuture/better_caller.git").delete_all
      @project   = FactoryGirl.create(:project, repository_url: "https://github.com/RISCfuture/better_caller.git")
      @commit    = @project.repo.object('HEAD^')

      # this will be a valid exception but with a stack trace that doesn't make
      # sense in the context of the project (the files don't actually exist in the
                                                                   # repo). this will test the scenarios where no blamed commits can be found.
      @exception = nil
      begin
        raise ArgumentError, "Well crap"
      rescue
        @exception = $!
      end
      @line        = @exception.backtrace.first.split(':')[1].to_i # get the line number of the first line of the backtrace

      # this is a valid stack trace in the context of the repo, and will produce
      # valid blamed commits.
      @valid_trace = [
          ["lib/better_caller/extensions.rb", 11, 'set_better_backtrace'],
          ["lib/better_caller/extensions.rb", 4, 'set_better_backtrace'],
          ["lib/better_caller/extensions.rb", 2, nil]
      ]
    end

    before :each do
      Bug.delete_all
      @valid_params = Squash::Ruby.send(:exception_info_hash, @exception, Time.now.utc, {}, nil).deep_clone
      @valid_params['occurred_at'] = @valid_params['occurred_at'].iso8601
      @valid_params.merge!('api_key'     => @project.api_key,
                           'environment' => 'production',
                           'revision'    => @commit.sha,
                           'user_data'   => {'foo' => 'bar'})
    end

    it "should return 403 given an invalid API key" do
      post :notify, @valid_params.merge('api_key' => 'not-found')
      response.status.should eql(403)
    end

    it "should return 422 given invalid parameters" do
      post :notify, @valid_params.merge('client' => '')
      response.status.should eql(422)
    end

    it "should start a worker thread and return 200 given valid parameters" do
      mock = mock('OccurrencesWorker')
      OccurrencesWorker.stub!(:new).and_return(mock)
      Thread.stub!(:new).and_yield

      mock.should_receive(:perform).once
      post :notify, @valid_params
      response.status.should eql(200)
    end
  end

  describe "#deploy", fdoc: '/deploy' do
    before :all do
      Project.where(repository_url: "https://github.com/RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "https://github.com/RISCfuture/better_caller.git")
    end

    before :each do
      @env    = FactoryGirl.create(:environment, project: @project)
      @params = {
          'project'     => {'api_key' => @env.project.api_key},
          'environment' => {'name' => @env.name},
          'deploy'      => {
              'deployed_at' => (@time = Time.now.utc).iso8601,
              'revision'    => (@rev = @project.repo.object('HEAD').sha),
              'hostname'    => 'myhost.local'
          }
      }
    end

    %w( project environment deploy ).each do |key|
      it "should require the #{key} key" do
        post :deploy, @params.merge(key => ' ')
        response.status.should eql(422)
      end
    end

    it "should return 403 if the API key is invalid" do
      @params['project'].merge!('api_key' => 'not-found')
      post :deploy, @params
      response.status.should eql(403)
    end

    it "should create a new environment if one doesn't exist with that name" do
      @params['environment'].merge!('name' => 'new')
      post :deploy, @params

      env = @project.environments.with_name('new').first!
      env.should_not be_nil
      env.deploys.count.should eql(1)
    end

    it "should create a deploy with the given parameters" do
      @env.deploys.delete_all
      post :deploy, @params

      @env.deploys.count.should eql(1)
      @env.deploys(true).first.deployed_at.to_i.should eql(@time.to_i)
      @env.deploys.first.revision.should eql(@rev)
      @env.deploys.first.hostname.should eql('myhost.local')
    end
  end

  describe "#symbolication", fdoc: '/symbolication' do
    it "should return 422 if the symbolication param is not provided" do
      post :symbolication, format: 'json'
      response.status.should eql(422)
    end

    it "should create a new symbolication" do
      Symbolication.delete_all

      uuid = SecureRandom.uuid
      params = {
          'symbolications' => [
              'uuid'    => uuid,
              'symbols' => Base64.encode64(Zlib::Deflate.deflate(Squash::Symbolicator::Symbols.new.to_yaml)),
              'lines'   => Base64.encode64(Zlib::Deflate.deflate(Squash::Symbolicator::Lines.new.to_yaml))
          ]
      }

      post :symbolication, params

      response.status.should eql(201)
      Symbolication.count.should eql(1)
      Symbolication.first.uuid.should eql(uuid)
    end
  end

  describe "#sourcemap", fdoc: '/sourcemap' do
    before :all do
      Project.where(repository_url: "https://github.com/RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "https://github.com/RISCfuture/better_caller.git")
    end

    before :each do
      @env    = FactoryGirl.create(:environment, project: @project)
      @map    = FactoryGirl.build(:source_map)
      @params = {
          'sourcemap'   => @map.send(:read_attribute, :map),
          'api_key'     => @project.api_key,
          'environment' => @env.name,
          'revision'    => (@rev = @project.repo.object('HEAD').sha)
      }
    end

    %w( sourcemap api_key environment revision ).each do |key|
      it "should require the #{key} key" do
        post :sourcemap, @params.merge(key => ' ')
        response.status.should eql(422)
      end
    end

    it "should return 403 if the API key is invalid" do
      post :sourcemap, @params.merge('api_key' => 'not-found')
      response.status.should eql(403)
    end

    it "should create a new environment if one doesn't exist with that name" do
      post :sourcemap, @params.merge('environment' => 'new')

      env = @project.environments.with_name('new').first!
      env.should_not be_nil
      env.source_maps.count.should eql(1)
    end

    it "should create a sourcemap with the given parameters" do
      @env.source_maps.delete_all
      post :sourcemap, @params

      @env.source_maps.count.should eql(1)
      @env.source_maps(true).first.revision.should eql(@rev)
    end
  end

  describe "#deobfuscation", fdoc: '/deobfuscation' do
    before :all do
      Project.where(repository_url: "https://github.com/RISCfuture/better_caller.git").delete_all
      @project = FactoryGirl.create(:project, repository_url: "https://github.com/RISCfuture/better_caller.git")
    end

    before :each do
      @env     = FactoryGirl.create(:environment, project: @project)
      @release = FactoryGirl.create(:release, environment: @env)
      @ns      = FactoryGirl.build(:obfuscation_map)
      @params  = {
          'namespace'   => @ns.send(:read_attribute, :namespace),
          'api_key'     => @project.api_key,
          'environment' => @env.name,
          'build'       => @release.build
      }
    end

    %w( namespace api_key environment build ).each do |key|
      it "should require the #{key} key" do
        post :deobfuscation, @params.merge(key => ' ')
        response.status.should eql(422)
      end
    end

    it "should return 403 if the API key is invalid" do
      post :deobfuscation, @params.merge('api_key' => 'not-found')
      response.status.should eql(403)
    end

    it "should return 404 if the environment name is unknown" do
      post :deobfuscation, @params.merge('environment' => 'new')
      response.status.should eql(404)
    end

    it "should return 404 if the build number is unknown" do
      post :deobfuscation, @params.merge('build' => 'nil')
      response.status.should eql(404)
    end

    it "should create an obfuscation map with the given parameters" do
      post :deobfuscation, @params

      @release.obfuscation_map(true).send(:read_attribute, :namespace).should eql(@ns.send(:read_attribute, :namespace))
    end
  end
end
