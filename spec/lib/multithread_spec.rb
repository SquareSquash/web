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
