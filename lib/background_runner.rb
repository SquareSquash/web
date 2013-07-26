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

# Parent container for the BackgroundRunner module cluster. This module stores
# the modules that encapsulate different strategies for executing long-running
# background tasks outside of the scope of a request-response handler.
#
# @example Running a DeployFixMarker job
#   BackgroundRunner.run DeployFixMarker, deploy.id
#
# All `BackgroundRunner` modules should implement a `run` class method that
# takes, as its first argument, the name of a worker class under `lib/workers`.
# It should take any other number of arguments as long as they are serializable.

module BackgroundRunner

  # @return [Module] The active module that should be used to handle
  #   background jobs.

  def self.runner
    BackgroundRunner.const_get Squash::Configuration.concurrency.background_runner.to_sym, false
  end

  # Shortcut for `BackgroundRunner.runner.run`.

  def self.run(*args)
    runner.run *args
  end
end
