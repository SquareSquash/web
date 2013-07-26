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

describe Multithread::PriorityQueue do
  before(:each) { @queue = Multithread::PriorityQueue.new(50, 10) }

  describe "#deq" do
    it "should deq items from the queue in priority order" do
      @queue.enq('10:1', 10) { 10 }
      @queue.enq('50', 50) { 50 }
      @queue.enq('10:2', 10) { 10 }
      @queue.enq('20', 20) { 20 }

      @queue.deq(false).().should eql(50)
      @queue.deq(false).().should eql(20)
      @queue.deq(false).().should eql(10)
      @queue.deq(false).().should eql(10)
      -> { @queue.deq(false) }.should raise_error(ThreadError)
    end

    it "should raise if the queue is empty" do
      @queue.should be_empty
      -> { @queue.deq(false) }.should raise_error(ThreadError)
    end
  end

  describe "#enq" do
    it "should let low-priority jobs fall off if saturated" do
      10.times { |i| @queue.enq(i.to_s, 50) { 50 } }
      @queue.should be_saturated

      @queue.enq('new1', 10) { 10 }
      @queue.size.should eql(10)

      @queue.enq('new2', 50) { 50 }
      @queue.size.should eql(11)
      @queue.should be_saturated
    end

    it "should not enqueue multiple copies of the same job" do
      @queue.enq('10', 10) { 10 }
      @queue.enq('50', 50) { 50 }
      @queue.enq('10', 10) { 10 }
      @queue.enq('20', 20) { 20 }

      @queue.size.should eql(3)
      @queue.deq(false).().should eql(50)
      @queue.deq(false).().should eql(20)
      @queue.deq(false).().should eql(10)
    end
  end
end
