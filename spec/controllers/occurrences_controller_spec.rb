# Copyright 2012 Square Inc.
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

describe OccurrencesController do
  describe "#index" do
    before :all do
      @bug         = FactoryGirl.create(:bug)
      @occurrences = FactoryGirl.create_list(:rails_occurrence, 100, bug: @bug)
    end

    def sort(occurrences, reverse=false)
      occurrences.sort_by! { |b| [b.occurred_at, b.number] }
      occurrences.reverse! if reverse
      occurrences
    end

    it "should require a logged-in user" do
      get :index, polymorphic_params(@bug, true)
      response.should redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before(:each) { login_as @bug.environment.project.owner }

      it_should_behave_like "action that 404s at appropriate times", :get, :index, 'polymorphic_params(@bug, true, format: "json")'

      context '[JSON]' do
        it "should load the first 50 occurrences" do
          get :index, polymorphic_params(@bug, true, format: 'json')
          response.status.should eql(200)
          JSON.parse(response.body).map { |r| r['number'] }.should eql(sort(@occurrences, true).map(&:number)[0, 50])
        end

        it "should load the first 50 occurrences ascending" do
          get :index, polymorphic_params(@bug, true, format: 'json', dir: 'asc')
          response.status.should eql(200)
          JSON.parse(response.body).map { |r| r['number'] }.should eql(sort(@occurrences).map(&:number)[0, 50])
        end

        it "should load the next 50 occurrences" do
          sort @occurrences, true
          get :index, polymorphic_params(@bug, true, format: 'json', last: @occurrences[49].number)
          response.status.should eql(200)
          JSON.parse(response.body).map { |r| r['number'] }.should eql(@occurrences.map(&:number)[50, 50])
        end
      end
    end
  end

  describe "#histogram" do
    before :all do
      @env = FactoryGirl.create(:environment)
      @bug = FactoryGirl.create(:bug, environment: @env)
    end

    it "should require a logged-in user" do
      get :histogram, polymorphic_params(@bug, true)
      response.should redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before :all do
        27.times do |i|
          Timecop.freeze(Time.at(1234567890) - (i*13).minutes)
          FactoryGirl.create :rails_occurrence, bug: @bug
        end

        FactoryGirl.create(:deploy, environment: @env, revision: '30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44', deployed_at: Time.at(1234567890))
        FactoryGirl.create(:deploy, environment: @env, revision: '2dc20c984283bede1f45863b8f3b4dd9b5b554cc', deployed_at: Time.at(123467890) - 1.year)
      end

      before :each do
        login_as @bug.environment.project.owner
        Timecop.freeze Time.at(1234567890) # make sure we don't get boundary errors
      end

      after(:each) { Timecop.return }

      it_should_behave_like "action that 404s at appropriate times", :get, :histogram, "polymorphic_params(@bug, true, dimensions: %w( host pid ), step: 1000*60*60*5, size: 20, format: 'json')"

      it "should return a histogram of occurrence frequencies and deploys" do
        get :histogram, polymorphic_params(@bug, true, dimensions: %w( host pid ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(200)
        json = JSON.parse(response.body)
        json['occurrences'].should eql([
                                                                [1234544400000, 1], [1234548000000, 5], [1234551600000, 4], [1234555200000, 5], [1234558800000, 4], [1234562400000, 5], [1234566000000, 3]
                                                            ])
        json['deploys'].map { |d| d['revision'] }.should eql(%w(30e7c2ff8758f4f19bfbc0a57e26c19ab69d1d44))
      end

      it "should return empty arrays for bugs with no recent occurrences" do
        @bug.occurrences.delete_all
        OccurrenceData.where(bug_id: @bug.id).delete_all
        get :histogram, polymorphic_params(@bug, true, dimensions: %w( host pid ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(200)
        JSON.parse(response.body).should eql('occurrences' => [], 'deploys' => [])
      end
    end
  end

  describe "#aggregate" do
    before(:all) { @bug = FactoryGirl.create(:bug) }

    it "should require a logged-in user" do
      get :aggregate, polymorphic_params(@bug, true)
      response.should redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before :all do
        # we'll build fake graphs that look like this:
        #
        # HOST (* = host1, . = host2)
        #
        # 100% |***************
        #  75% |**********.....
        #  50% |****...........
        #  25% |...............
        #      +---------------
        #      |    |    |    |
        #     3:00 4:00 5:00 6:00
        #
        # PID (* = 1, . = 2)
        #
        # 100% |***************
        #  75% |....***********
        #  50% |.........******
        #  25% |...............
        #      +---------------
        #      |    |    |    |
        #     3:00 4:00 5:00 6:00

        day = Time.now.yesterday.beginning_of_day.advance(minutes: 15)
        # don't put it right on the hour in order to prevent boundary errors

        # at time 3:00, 75% of occurrences are on host1, 25% on host2, and
        # 25% of occurrences are on PID 1, 75% on PID 2
        Timecop.freeze(day.advance(hours: 3))
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 2
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 2
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 2

        # at time 4:00, 75% of occurrences are on host1, 25% on host2, and
        # 25% of occurrences are on PID 1, 75% on PID 2
        Timecop.freeze(day.advance(hours: 4))
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 2
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 2
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 2

        # at time 5:00, 50% of occurrences are on host1, 50% on host2, and
        # 50% of occurrences are on PID 1, 50% on PID 2
        Timecop.freeze(day.advance(hours: 5))
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 2
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 2

        # at time 6:00, 25% of occurrences are on host1, 75% on host2, and
        # 75% of occurrences are on PID 1, 25% on PID 2
        Timecop.freeze(day.advance(hours: 6))
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host1', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 1
        FactoryGirl.create :rails_occurrence, bug: @bug, host: 'host2', pid: 2

        Timecop.return

        @time_300 = day.change(hour: 3, min: 0)
        @time_400 = day.change(hour: 4, min: 0)
        @time_500 = day.change(hour: 5, min: 0)
        @time_600 = day.change(hour: 6, min: 0)
      end

      before :each do
        login_as @bug.environment.project.owner
      end

      it_should_behave_like "action that 404s at appropriate times", :get, :aggregate, "polymorphic_params(@bug, true, dimensions: %w( host pid ), step: 1000*60*60*5, size: 20, format: 'json')"

      it "should aggregate occurrences based on given dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: %w( host pid ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(200)
        JSON.parse(response.body).
            should eql(
                       'host' => [
                           {'label' => 'host1', 'data' => [[@time_300.to_i*1000, 75.0], [@time_400.to_i*1000, 75.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 25.0]]},
                           {'label' => 'host2', 'data' => [[@time_300.to_i*1000, 25.0], [@time_400.to_i*1000, 25.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 75.0]]}
                       ],
                       'pid'  => [
                           {'label' => '1', 'data' => [[@time_300.to_i*1000, 25.0], [@time_400.to_i*1000, 25.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 75.0]]},
                           {'label' => '2', 'data' => [[@time_300.to_i*1000, 75.0], [@time_400.to_i*1000, 75.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 25.0]]}
                       ]
                   )
      end

      it "should collapse duplicate dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: %w( host host pid ), step: 1000*60*60*5, size: 20, format: 'json')
        JSON.parse(response.body).
            should eql(
                       'host' => [
                           {'label' => 'host1', 'data' => [[@time_300.to_i*1000, 75.0], [@time_400.to_i*1000, 75.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 25.0]]},
                           {'label' => 'host2', 'data' => [[@time_300.to_i*1000, 25.0], [@time_400.to_i*1000, 25.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 75.0]]}
                       ],
                       'pid'  => [
                           {'label' => '1', 'data' => [[@time_300.to_i*1000, 25.0], [@time_400.to_i*1000, 25.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 75.0]]},
                           {'label' => '2', 'data' => [[@time_300.to_i*1000, 75.0], [@time_400.to_i*1000, 75.0], [@time_500.to_i*1000, 50.0], [@time_600.to_i*1000, 25.0]]}
                       ]
                   )
      end

      it "should 422 for non-aggregating dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: %w( host pid lat ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(422)
      end

      it "should 422 for nonexistent dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: %w( host pid madeup ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(422)
      end

      it "should return an empty array given no dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: [], step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(200)
        response.body.should eql('[]')
      end

      it "should 422 given too many dimensions" do
        get :aggregate, polymorphic_params(@bug, true, dimensions: %w( host pid client revision browser_os ), step: 1000*60*60*5, size: 20, format: 'json')
        response.status.should eql(422)
      end
    end
  end

  describe "#show" do
    before(:all) { @occurrence = FactoryGirl.create(:rails_occurrence) }

    it "should require a logged-in user" do
      get :aggregate, polymorphic_params(@occurrence, false)
      response.should redirect_to(login_url(next: request.fullpath))
    end

    context '[authenticated]' do
      before :each do
        login_as @occurrence.bug.environment.project.owner
      end

      it_should_behave_like "action that 404s at appropriate times", :get, :show, "polymorphic_params(@occurrence, false)"

      it "should not raise an exception for improperly-formatted JSON" do
        @occurrence.ivars = {foo: {bar: 'baz'}}
        -> { get :show, polymorphic_params(@occurrence, false) }.should_not raise_error
      end
    end
  end
end
