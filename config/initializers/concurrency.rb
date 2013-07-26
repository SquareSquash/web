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

# Spawn and stop the thread pool

if defined?(PhusionPassenger)
  PhusionPassenger.on_event(:starting_worker_process) do |forked|
    Multithread.start
  end

  PhusionPassenger.on_event(:stopping_worker_process) do
    Multithread.stop
  end
elsif defined?(Unicorn)
  Unicorn::HttpServer.class_eval do
    old = instance_method(:worker_loop)
    define_method(:worker_loop) do |worker|
      Multithread.start
      old.bind(self).call(worker)
    end
  end
else
  # Not in Passenger at all
  Multithread.start
  at_exit { Multithread.stop }
end

# Load concurrency setup

BackgroundRunner.runner.setup if BackgroundRunner.runner.respond_to?(:setup)
