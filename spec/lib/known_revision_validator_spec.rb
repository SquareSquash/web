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

describe KnownRevisionValidator do
  before :all do
    env    = FactoryGirl.create(:environment)
    @model = FactoryGirl.build(:deploy, environment: env)
  end

  it "should not accept unknown revisions" do
    @model.revision = '3dc20c984283bede1f45863b8f3b4dd9b5b554cc'
    @model.should_not be_valid
    @model.errors[:revision].should eql(['does not exist in the repository'])
  end

  it "should accept known revisions" do
    @model.revision = '2dc20c984283bede1f45863b8f3b4dd9b5b554cc'
    @model.should be_valid
  end

  it "should normalize known revisions" do
    @model.revision = 'HEAD'
    @model.should be_valid
    @model.revision.should =~ /^[0-9a-f]{40}$/
  end

  context "[:repo option]" do
    before :each do
      @model  = double('Model', :foo= => nil)
      @commit = double('Git::Object::Commit', sha: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc')
    end

    it "should accept repository objects" do
      repo = double('Git::Repository', fetch: nil)
      repo.should_receive(:object).once.and_return(@commit)

      validator = KnownRevisionValidator.new(repo: repo, attributes: [:foo])
      validator.validate_each(@model, :foo, 'HEAD')
    end

    it "should accept method names" do
      repo = double('Git::Repository', fetch: nil)
      repo.should_receive(:object).once.and_return(@commit)
      @model.stub(:repo).and_return(repo)

      validator = KnownRevisionValidator.new(repo: :repo, attributes: [:foo])
      validator.validate_each(@model, :foo, 'HEAD')
    end

    it "should accept procs" do
      repo = double('Git::Repository', fetch: nil)
      repo.should_receive(:object).once.and_return(@commit)
      @model.stub(:repo).and_return(repo)

      validator = KnownRevisionValidator.new(repo: ->(m) { m.repo }, attributes: [:foo])
      validator.validate_each(@model, :foo, 'HEAD')
    end
  end
end
