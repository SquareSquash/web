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

describe ObfuscationMap do
  context "[hooks]" do
    it "should deobfuscate pending occurrences when created" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
      env     = FactoryGirl.create(:environment, project: project)

      bug        = FactoryGirl.create(:bug,
                                      file:            'lib/better_caller/extensions.rb',
                                      line:            5,
                                      environment:     env,
                                      deploy:          FactoryGirl.create(:deploy), environment: env,
                                      blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      occurrence = FactoryGirl.create(:rails_occurrence,
                                      revision:   '2dc20c984283bede1f45863b8f3b4dd9b5b554cc',
                                      bug:        bug,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"file"   => "lib/better_caller/extensions.rb",
                                                                     "line"   => 5,
                                                                     "symbol" => "foo"},
                                                                    {"type"   => "obfuscated",
                                                                     "file"   => "B.java",
                                                                     "line"   => 15,
                                                                     "symbol" => "int b(int)",
                                                                     "class_name"  => "com.A.B"}]}])
      occurrence.should_not be_deobfuscated

      namespace = Squash::Java::Namespace.new
      namespace.add_package_alias 'com.foo', 'A'
      namespace.add_class_alias('com.foo.Bar', 'B').path = 'src/foo/Bar.java'
      namespace.add_method_alias 'com.foo.Bar', 'int foo(int)', 'b'
      FactoryGirl.create :obfuscation_map, namespace: namespace, deploy: bug.deploy
      occurrence.reload.should be_deobfuscated
      occurrence.redirect_target_id.should be_nil
    end

    it "should reassign to another bug if blame changes" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git@github.com:RISCfuture/better_caller.git')
      env     = FactoryGirl.create(:environment, project: project)

      bug1 = FactoryGirl.create(:bug,
                                file:            '_JAVA_',
                                line:            1,
                                blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44',
                                deploy:          FactoryGirl.create(:deploy, environment: env),
                                environment:     env)
      bug2 = FactoryGirl.create(:bug,
                                file:            'lib/better_caller/extensions.rb',
                                line:            5,
                                blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44',
                                deploy:          bug1.deploy,
                                environment:     env)

      occurrence = FactoryGirl.create(:rails_occurrence,
                                      bug:        bug1,
                                      revision:   bug1.blamed_revision,
                                      backtraces: [{"name"      => "Thread 0",
                                                    "faulted"   => true,
                                                    "backtrace" => [{"type"   => "obfuscated",
                                                                     "file"   => "B.java",
                                                                     "line"   => 5,
                                                                     "symbol" => "int b(int)",
                                                                     "class_name"  => "com.A.B"}]}])

      namespace = Squash::Java::Namespace.new
      namespace.add_package_alias 'com.foo', 'A'
      namespace.add_class_alias('com.foo.Bar', 'B').path = 'lib/better_caller/extensions.rb'
      namespace.add_method_alias 'com.foo.Bar', 'int foo(int)', 'b'
      FactoryGirl.create :obfuscation_map, namespace: namespace, deploy: bug1.deploy

      bug2.occurrences.count.should eql(1)
      o2 = bug2.occurrences.first
      occurrence.reload.redirect_target_id.should eql(o2.id)
    end
  end
end
