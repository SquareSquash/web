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

describe Symbolication do
  context "[hooks]" do
    it "should symbolicate pending occurrences when created" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git')
      env = FactoryGirl.create(:environment, project: project)

      bug        = FactoryGirl.create(:bug,
                                      file:            'lib/better_caller/extensions.rb',
                                      line:            5,
                                      environment:     env,
                                      blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44')
      occurrence = FactoryGirl.create(:rails_occurrence,
                                      revision:         '2dc20c984283bede1f45863b8f3b4dd9b5b554cc',
                                      symbolication_id: SecureRandom.uuid,
                                      bug:              bug,
                                      backtraces:       [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" =>
                                                              [{"file" => "lib/better_caller/extensions.rb", "line" => 5, "symbol" => "foo"},
                                                               {"type" => "address", "address" => 1}]}])
      occurrence.should_not be_symbolicated

      symbols = Squash::Symbolicator::Symbols.new
      symbols.add 1, 5, 'lib/better_caller/extensions.rb', 2, 'bar'
      FactoryGirl.create :symbolication, uuid: occurrence.symbolication_id, symbols: symbols
      occurrence.reload.should be_symbolicated
      occurrence.redirect_target_id.should be_nil
    end

    it "should reassign to another bug if blame changes" do
      if RSpec.configuration.use_transactional_fixtures
        pending "This is done in an after_commit hook, and it can't be tested with transactional fixtures (which are always rolled back)"
      end

      Project.delete_all
      project = FactoryGirl.create(:project, repository_url: 'git://github.com/RISCfuture/better_caller.git')
      env = FactoryGirl.create(:environment, project: project)

      bug1 = FactoryGirl.create(:bug,
                                file:            '0x00000042',
                                line:            3,
                                blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44',
                                environment:     env)
      bug2 = FactoryGirl.create(:bug,
                                file:            'lib/better_caller/extensions.rb',
                                line:            5,
                                blamed_revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44',
                                environment:     env)

      occurrence = FactoryGirl.create(:rails_occurrence,
                                      bug:              bug1,
                                      symbolication_id: SecureRandom.uuid,
                                      revision:         bug1.blamed_revision,
                                      backtraces:       [{"name"      => "Thread 0",
                                                          "faulted"   => true,
                                                          "backtrace" => [{"type" => "address", "address" => 3}]}])

      symbols = Squash::Symbolicator::Symbols.new
      symbols.add 1, 5, 'lib/better_caller/extensions.rb', 5, 'bar'
      FactoryGirl.create :symbolication, uuid: occurrence.symbolication_id, symbols: symbols

      bug2.occurrences.count.should eql(1)
      o2 = bug2.occurrences.first
      occurrence.reload.redirect_target_id.should eql(o2.id)
    end
  end

  describe "#symbolicate" do
    before :each do
      symbols = Squash::Symbolicator::Symbols.new
      symbols.add 1, 10, 'foo.rb', 4, 'bar'
      symbols.add 16, 20, 'foo2.rb', 15, 'baz'

      lines = Squash::Symbolicator::Lines.new
      lines.add 1, 'foo.rb', 5, 1
      lines.add 5, 'foo.rb', 7, 1
      lines.add 12, 'foo.rb', 12, 1

      @symbolication = FactoryGirl.build(:symbolication, symbols: symbols, lines: lines)
    end

    it "should symbolicate an address using lines" do
      @symbolication.symbolicate(12).should eql(
                                                'file' => 'foo.rb',
                                                'line' => 12
                                            )
    end

    it "should symbolicate an address using symbols" do
      @symbolication.symbolicate(16).should eql(
                                                'file'   => 'foo2.rb',
                                                'line'   => 15,
                                                'symbol' => 'baz'
                                            )
    end

    it "should symbolicate an address using lines and symbols" do
      @symbolication.symbolicate(5).should eql(
                                               'file'   => 'foo.rb',
                                               'line'   => 7,
                                               'symbol' => 'bar'
                                           )
    end

    it "should return nil for unsymbolicatable addresses" do
      @symbolication.symbolicate(50).should be_nil
    end
  end
end
