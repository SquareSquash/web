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

describe SourceMap do
  context "[hooks]" do
    it "should source-map pending occurrences when created" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
      env = FactoryGirl.create(:environment, project: project)

      bug        = FactoryGirl.create(:bug,
                                      file:            'lib/better_caller/extensions.rb',
                                      line:            5,
                                      environment:     env,
                                      blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      occurrence = FactoryGirl.create(:rails_occurrence,
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc',
                                      bug:        bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" =>
                                                        [{"file" => "lib/better_caller/extensions.rb", "line" => 5, "symbol" => "foo"},
                                                         {"type"    => "minified",
                                                          "url"     => "http://test.host/example/asset.js",
                                                          "line"    => 3,
                                                          "column"  => 144,
                                                          "symbol"  => "eval",
                                                          "context" => nil}]}])
      occurrence.should_not be_sourcemapped

      map = Squash::Javascript::SourceMap.new
      map << Squash::Javascript::SourceMap::Mapping.new('http://test.host/example/asset.js', 3, 140, 'app/assets/javascripts/source.js', 25, 1, 'foobar')
      FactoryGirl.create :source_map, environment: env, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', map: map

      occurrence.reload.should be_sourcemapped
      occurrence.redirect_target_id.should be_nil
    end

    it "should reassign to another bug if blame changes" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
      env = FactoryGirl.create(:environment, project: project)

      bug1       = FactoryGirl.create(:bug,
                                      file:            '_JS_ASSET_',
                                      line:            1,
                                      environment:     env,
                                      blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      bug2       = FactoryGirl.create(:bug,
                                      file:            'lib/better_caller/extensions.rb',
                                      line:            5,
                                      blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44',
                                      environment:     env)
      occurrence = FactoryGirl.create(:rails_occurrence,
                                      revision:   bug1.blamed_revision,
                                      bug:        bug1,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" =>
                                                        [{"file" => "lib/better_caller/extensions.rb", "line" => 5, "symbol" => "foo"},
                                                         {"type"    => "minified",
                                                          "url"     => "http://test.host/example/asset.js",
                                                          "line"    => 3,
                                                          "column"  => 144,
                                                          "symbol"  => "eval",
                                                          "context" => nil}]}])
      occurrence.should_not be_sourcemapped

      map = Squash::Javascript::SourceMap.new
      map << Squash::Javascript::SourceMap::Mapping.new('http://test.host/example/asset.js', 3, 140, 'lib/better_caller/extensions.rb', 2, 1, 'foobar')
      FactoryGirl.create :source_map, environment: env, revision: bug1.blamed_revision, map: map

      bug2.occurrences.count.should eql(1)
      o2 = bug2.occurrences.first
      occurrence.reload.redirect_target_id.should eql(o2.id)
    end
  end
end
