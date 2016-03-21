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

RSpec.describe SourceMap, type: :model do
  context "[hooks]" do
    it "should source-map pending occurrences when created" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'https://github.com/RISCfuture/better_caller.git')
      env     = FactoryGirl.create(:environment, project: project)

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
      expect(occurrence).not_to be_sourcemapped

      map = GemSourceMap::Map.new([
                                   GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(25, 1))
                               ], 'http://test.host/example/asset.js')
      FactoryGirl.create :source_map, environment: env, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', map: map

      expect(occurrence.reload).to be_sourcemapped
      expect(occurrence.redirect_target_id).to be_nil
    end

    it "should reassign to another bug if blame changes" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'https://github.com/RISCfuture/better_caller.git')
      env     = FactoryGirl.create(:environment, project: project)

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
      expect(occurrence).not_to be_sourcemapped

      map = GemSourceMap::Map.new([
                                   GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(2, 1))
                               ], 'http://test.host/example/asset.js')
      FactoryGirl.create :source_map, environment: env, revision: bug1.blamed_revision, map: map

      expect(bug2.occurrences.count).to eql(1)
      o2 = bug2.occurrences.first
      expect(occurrence.reload.redirect_target_id).to eql(o2.id)
    end
  end

  describe '#resolve' do
    before :all do
      @map1 = GemSourceMap::Map.new([
                                   GemSourceMap::Mapping.new('app/assets/javascripts/example/url.coffee', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(2, 1)),
                               ], 'http://test.host/example/url.js')
      @map2 = GemSourceMap::Map.new([
                                    GemSourceMap::Mapping.new('app/assets/javascripts/source.js', GemSourceMap::Offset.new(3, 140), GemSourceMap::Offset.new(2, 1)),
                                ], '/example/path.js')
    end

    it "should resolve a route, line, and column" do
      map = FactoryGirl.create(:source_map, map: @map1)
      expect(map.resolve('http://test.host/example/url.js', 3, 144)).
          to eql(
                 'file'   => 'app/assets/javascripts/example/url.coffee',
                 'line'   => 2,
                 'column' => 1
             )
    end

    it "should resolve a URL path, line, and column" do
      map = FactoryGirl.create(:source_map, map: @map2)
      expect(map.resolve('http://test.host/example/path.js', 3, 144)).
          to eql(
                 'file'   => 'app/assets/javascripts/source.js',
                 'line'   => 2,
                 'column' => 1
             )
    end
  end
end
