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

describe SearchController do
  before :all do
    Environment.delete_all
    Project.delete_all
    Slug.delete_all
    User.delete_all
    Rails.cache.clear

    @project     = FactoryGirl.create(:project, name: 'Example Project')
    @environment = FactoryGirl.create(:environment, name: 'production', project: @project)
    @bug         = FactoryGirl.create(:bug, environment: @environment)
    @occurrence  = FactoryGirl.create(:rails_occurrence, bug: @bug)

    FactoryGirl.create :project, name: 'Example Other'
    FactoryGirl.create :environment, name: 'prodother', project: @project
    FactoryGirl.create :environment, name: 'producother'
  end

  describe "#search" do
    context "[user]" do
      it "should respond with the URL for a user given a @username" do
        user = FactoryGirl.create(:user, username: 'foobar', first_name: 'Foo', last_name: 'Bar')
        get :search, query: '@foobar', format: 'json'
        response.status.should eql(200)
        response.body.should eql(user_url(user))
      end

      it "should respond with nil for an unknown username" do
        get :search, query: '@unknown', format: 'json'
        response.status.should eql(200)
        response.body.should be_blank
      end
    end

    context "[project]" do
      it "should respond with the URL for a project given a project slug" do
        get :search, query: 'example-project'
        response.status.should eql(200)
        response.body.should eql(project_url(@project))
      end

      it "should respond with the URL for a project given a project prefix" do
        get :search, query: 'example-p'
        response.status.should eql(200)
        response.body.should eql(project_url(@project))
      end

      it "should respond with nil given an unknown project" do
        get :search, query: 'unknown'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous project prefix" do
        get :search, query: 'exam'
        response.status.should eql(200)
        response.body.should be_blank
      end
    end

    context "[environment]" do
      it "should respond with the URL for an environment given a project & environment slug" do
        get :search, query: 'example-project production'
        response.status.should eql(200)
        response.body.should eql(project_environment_bugs_url(@project, @environment))
      end

      it "should respond with the URL for an environment given a project & environment prefix" do
        get :search, query: 'example-p product'
        response.status.should eql(200)
        response.body.should eql(project_environment_bugs_url(@project, @environment))
      end

      it "should respond with nil given an unknown project" do
        get :search, query: 'unknown development'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown environment" do
        get :search, query: 'example-project dev'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous project prefix" do
        get :search, query: 'exam production'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous environment prefix" do
        get :search, query: 'example-project prod'
        response.status.should eql(200)
        response.body.should be_blank
      end
    end

    context "[bug]" do
      it "should respond with the URL for a bug given a project & environment slug and bug number" do
        get :search, query: 'example-project production 1'
        response.status.should eql(200)
        response.body.should eql(project_environment_bug_url(@project, @environment, @bug))
      end

      it "should respond with the URL for a bug given a project & environment prefix and bug number" do
        get :search, query: 'example-p product 1'
        response.status.should eql(200)
        response.body.should eql(project_environment_bug_url(@project, @environment, @bug))
      end

      it "should respond with nil given an unknown project" do
        get :search, query: 'unknown production 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown environment" do
        get :search, query: 'example-project unknown 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown bug number" do
        get :search, query: 'example-project production 123'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous project prefix" do
        get :search, query: 'exam production 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous environment prefix" do
        get :search, query: 'example-project prod 1'
        response.status.should eql(200)
        response.body.should be_blank
      end
    end

    context "[occurrence]" do
      it "should respond with the URL for an occurrence given a project & environment slug and bug & occurrence number" do
        get :search, query: 'example-project production 1 1'
        response.status.should eql(200)
        response.body.should eql(project_environment_bug_occurrence_url(@project, @environment, @bug, @occurrence))
      end

      it "should respond with the URL for an occurrence given a project & environment prefix and a bug & occurrence number" do
        get :search, query: 'example-p product 1 1'
        response.status.should eql(200)
        response.body.should eql(project_environment_bug_occurrence_url(@project, @environment, @bug, @occurrence))
      end

      it "should respond with nil given an unknown project" do
        get :search, query: 'unknown production 1 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown environment" do
        get :search, query: 'example-project unknown 1 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown occurrence number" do
        get :search, query: 'example-project production 1 2'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an unknown bug number" do
        get :search, query: 'example-project production 2 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous project prefix" do
        get :search, query: 'exam production 1 1'
        response.status.should eql(200)
        response.body.should be_blank
      end

      it "should respond with nil given an ambiguous environment prefix" do
        get :search, query: 'example-project prod 1 1'
        response.status.should eql(200)
        response.body.should be_blank
      end
    end
  end

  describe "#suggestions" do
    before :all do
      Environment.delete_all
      Project.delete_all
      Slug.delete_all
      User.delete_all
      Rails.cache.clear
    end

    context "[user]" do
      it "should respond with a list of username suggestions" do
        foo1 = FactoryGirl.create(:user, username: 'foo1', first_name: 'Foo', last_name: 'One')
        foo2 = FactoryGirl.create(:user, username: 'foo2', first_name: 'Foo', last_name: 'Two')

        get :suggestions, query: '@foo', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql([
                           {'user' => JSON.parse(foo1.to_json),
                            'url'  => user_url(foo1),
                            'type' => 'user'},
                           {'user' => JSON.parse(foo2.to_json),
                            'url'  => user_url(foo2),
                            'type' => 'user'},
                       ])
      end
    end

    context "[project]" do
      it "should respond with a list of project suggestions" do
        proj1 = FactoryGirl.create(:project, name: 'Project One')
        proj2 = FactoryGirl.create(:project, name: 'Project Two')

        get :suggestions, query: 'proj', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql([
                           {'project' => JSON.parse(proj1.to_json),
                            'url'     => project_url(proj1),
                            'type'    => 'project'},
                           {'project' => JSON.parse(proj2.to_json),
                            'type'    => 'project',
                            'url'     => project_url(proj2)},
                       ])
      end
    end

    context "[environment]" do
      it "should respond with a list of environment suggestions" do
        proj = FactoryGirl.create(:project, name: 'Another Project')
        env1 = FactoryGirl.create(:environment, name: 'env1', project: proj)
        env2 = FactoryGirl.create(:environment, name: 'env2', project: proj)

        get :suggestions, query: 'another env', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql([
                           {'project'     => JSON.parse(proj.to_json),
                            'environment' => JSON.parse(env1.to_json),
                            'type'        => 'environment',
                            'url'         => project_environment_bugs_url(proj, env1)},
                           {'project'     => JSON.parse(proj.to_json),
                            'environment' => JSON.parse(env2.to_json),
                            'type'        => 'environment',
                            'url'         => project_environment_bugs_url(proj, env2)},
                       ])
      end

      it "should respond with an empty list for an unknown project" do
        get :suggestions, query: 'unknown unknown', format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end
    end

    context "[bug]" do
      before(:all) { @bug = FactoryGirl.create :bug }

      it "should respond with the bug" do
        get :suggestions, query: "#{@bug.environment.project.slug} #{@bug.environment.name} #{@bug.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql([
                           {'project'     => JSON.parse(@bug.environment.project.to_json),
                            'environment' => JSON.parse(@bug.environment.to_json),
                            'bug'         => JSON.parse(@bug.to_json),
                            'type'        => 'bug',
                            'url'         => project_environment_bug_url(@bug.environment.project, @bug.environment, @bug)},
                       ])
      end

      it "should respond with an empty list for an unknown project" do
        get :suggestions, query: "unknown #{@bug.environment.name} #{@bug.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end

      it "should respond with an empty list for an unknown environment" do
        get :suggestions, query: "#{@bug.environment.project.slug} unknown #{@bug.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end

      it "should respond with an empty list for an unknown bug" do
        get :suggestions, query: "#{@bug.environment.project.slug} #{@bug.environment.name} 123", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end
    end

    context "[occurrence]" do
      before(:all) { @occurrence = FactoryGirl.create(:rails_occurrence) }

      it "should respond with the occurrence" do
        get :suggestions, query: "#{@occurrence.bug.environment.project.slug} #{@occurrence.bug.environment.name} #{@occurrence.bug.number} #{@occurrence.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql([
                           {'type'        => 'occurrence',
                            'url'         => project_environment_bug_occurrence_url(@occurrence.bug.environment.project, @occurrence.bug.environment, @occurrence.bug, @occurrence),
                            'project'     => JSON.parse(@occurrence.bug.environment.project.to_json),
                            'environment' => JSON.parse(@occurrence.bug.environment.to_json),
                            'bug'         => JSON.parse(@occurrence.bug.to_json),
                            'occurrence'  => JSON.parse(@occurrence.to_json)}
                       ])
      end

      it "should respond with an empty list for an unknown project" do
        get :suggestions, query: "unknown #{@occurrence.bug.environment.name} #{@occurrence.bug.number} #{@occurrence.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end

      it "should respond with an empty list for an unknown environment" do
        get :suggestions, query: "#{@occurrence.bug.environment.project.slug} unknown #{@occurrence.bug.number} #{@occurrence.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end

      it "should respond with an empty list for an unknown bug" do
        get :suggestions, query: "#{@occurrence.bug.environment.project.slug} #{@occurrence.bug.environment.name} 123 #{@occurrence.number}", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end

      it "should respond with an empty list for an unknown occurrence" do
        get :suggestions, query: "#{@occurrence.bug.environment.project.slug} #{@occurrence.bug.environment.name} #{@occurrence.bug.number} 123", format: 'json'
        response.status.should eql(200)
        JSON.parse(response.body).should eql([])
      end
    end

    it "should respond with an empty list for other queries" do
      get :suggestions, query: 'somethingelse', format: 'json'
      response.status.should eql(200)
      JSON.parse(response.body).should eql([])
    end
  end
end
