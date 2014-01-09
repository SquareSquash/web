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

require 'set'
require 'thread'

# A shared module that performs background processing. Objects that would like
# to perform tasks in a separate thread (and do not need the results of those
# tasks in-line) can call the {#spinoff} method.
#
# Multithread implements a thread pool backed by a priority queue. The size of
# the thread pool is configured in
# `config/environments/common/concurrency.yml`, in a hash under the
# `multithread` key. That file also contains the keys `priority_threshold` and
# `max_threads`; if the number of waiting threads exceeds the latter value,
# incoming jobs with a priority lower than the former value are ignored.
#
# Each job is given a name that uniquely describes the operation. If later
# jobs share the same name as a job already executing or waiting, these jobs
# are ignored.
#
# Each of the methods defined in Multithread have an alternative behavior if the
# `allow_concurrency` Rails option is `false`.
#
# Note that this module is not used directly; it is only used (if so configured)
# by the {BackgroundRunner} module.

module Multithread
  extend self

  # Spins off a new thread to perform a task. This thread will grab a new
  # connection from the ActiveRecord connection pool and close it when it
  # completes. Any exceptions raised in the thread will be sent to
  # `Squash::Ruby`.
  #
  # Executes the block immediately in the current thread if `allow_concurrency`
  # is `false`.
  #
  # @param [String, nil] name A name that uniquely identifies this job; used to
  #   prevent redundant duplicate jobs. If `nil`, the job is assumed to be
  #   unique.
  # @param [Fixnum] priority The job priority as a number between 0 and 100.
  #   All jobs of a greater priority are executed before those of a lower
  #   priority.
  # @param [Hash] user_data Additional user data to give to
  #   `Squash::Ruby.notify` in the event of an exception.
  # @yield The code to run in a separate thread.

  def spinoff(name, priority, user_data={})
    if Squash::Application.config.allow_concurrency
      @queue.enq(name, priority) { with_connection { with_dogfood(user_data) { yield } } }
    else
      yield
    end
  end

  # Spawns threads for the pool and begins executing jobs as they are pushed.
  # You should call this method at the start of your process.
  #
  # Does nothing if `allow_concurrency` is `false`.

  def start
    @queue = PriorityQueue.new(Squash::Configuration.concurrency.multithread.priority_threshold, Squash::Configuration.concurrency.multithread.max_threads)
    return unless Squash::Application.config.allow_concurrency
    @pool = Squash::Configuration.concurrency.multithread.pool_size.times.map do |i|
      Thread.new { catch(:exit) { loop { @queue.deq.() } } }
    end
  end

  # Schedules a kill job for each thread in the pool. Once the thread processes
  # that job, it will die. This method will block until all threads have died.
  #
  # Does nothing if `allow_concurrency` is `false`.

  def stop
    return unless Squash::Application.config.allow_concurrency
    Squash::Configuration.concurrency.multithread.pool_size.times { |i| spinoff(nil, 100) { throw :exit } }
    @pool.map &:join # make this a synchronous call
  end

  private

  def with_connection(&block)
    ActiveRecord::Base.connection_pool.with_connection &block
  end

  def with_dogfood(user_data={})
    begin
      yield
    rescue Object => err
      Squash::Ruby.notify err, user_data
    end
  end

  # @private A data structure that sorts its contents in priority order using a
  # maxheap algorithm. This class is specifically for handling jobs in a
  # priority queue.
  class PriorityQueue
    extend Forwardable

    # @private Creates a new queue with specified concurrency options.
    def initialize(priority_threshold, max_size)
      @operation_names    = Set.new
      @priority_threshold = priority_threshold
      @max_size           = max_size
      @mutex              = Mutex.new
      @waiting            = []
      @jobs               = []
    end

    # @private Adds a job onto the array.
    def enq(name, priority=50, &block)
      raise ArgumentError, "Invalid priority" unless priority >= 0 && priority <= 100

      if name && @operation_names.include?(name)
        Rails.logger.warn "[Multithread] Dropping operation #{name}: duplicate"
        return
      end
      if priority < @priority_threshold && saturated?
        Rails.logger.warn "[Multithread] Dropping operation #{name}: at capacity"
        return
      end

      @mutex.synchronize do
        @operation_names << name if name
        push Job.new(block, -1, name)
        escalate size - 1, priority
        begin
          @waiting.shift.try!(:wakeup)
        rescue ThreadError
          retry
        end
      end

      return self
    end

    # @private Returns true if we should fall low priority jobs off the queue.
    def saturated?() size >= @max_size end

    # @private Returns and removes the highest-priority job. See Ruby's Queue
    # object.
    def deq(block=true)
      @mutex.synchronize do
        begin
          loop do
            if empty?
              raise ThreadError, "queue empty" unless block
              @waiting.push(Thread.current) unless @waiting.include?(Thread.current)
              @mutex.sleep
            else
              max = first
              if size > 1
                self[0] = pop
                root 0
              else
                clear
              end
              @operation_names.delete(max.name) if max.name
              return max.operation
            end
          end
        ensure
          @waiting.delete Thread.current
        end
      end
    end

    # @private Returns the highest-priority job.
    def peek() first end

    # @private
    def inspect
      "#<#{self.class} #{map(&:name).join(', ')}>"
    end

    private

    def_delegators :@jobs,
      :[],
      :[]=,
      :clear,
      :empty?,
      :first,
      :pop,
      :push,
      :size

    def parent(i)
      return ((i+1)/2) - 1
    end

    def left(i)
      return (2*i) + 1
    end

    def right(i)
      return (2*i) + 2
    end

    def root(index)
      l = left(index)
      r = right(index)
      if l < size && self[l].priority > self[index].priority
        largest = l
      else
        largest = index
      end
      if r < size && self[r].priority > self[largest].priority
        largest = r
      end
      if largest != index
        self[index], self[largest] = self[largest], self[index]
        root largest
      end

      return self
    end

    def escalate(index, new_priority)
      raise ArgumentError, "Cannot escalate #{self[index]} to #{new_priority}" if self[index].priority > new_priority
      self[index].priority = new_priority
      while index > 0 && self[parent(index)].priority < self[index].priority
        self[index], self[parent(index)] = self[parent(index)], self[index]
        index = parent(index)
      end
    end

    # @private A job and associated metadata.
    Job = Struct.new(:operation, :priority, :name)
  end
end
