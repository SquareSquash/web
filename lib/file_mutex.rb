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

require 'fileutils'
require 'socket'

# A mutex that uses a lockfile to synchronize on. The presence of the lockfile
# indicates that the resource is in use; the contents of the file identify the
# owner of the lock.

class FileMutex
  # The default timeout to wait for an exclusive lock before raising
  # `Timeout::Error`.
  DEFAULT_TIMEOUT = 60.minutes

  # Creates a new file-based mutex.
  #
  # @param [String] path The path to the lockfile (can be any file; will be
  # created if it doesn't exist).

  def initialize(path)
    @path = path
  end

  # Attempts to acquire an exclusive lock on the resource. Blocks until a lock
  # is available. Once a lock is available, acquires it, executes the provided
  # block, and then releases the lock.
  #
  # @yield The code to run in the lock.
  # @return The result of the block.

  def lock!(timeout_duration = DEFAULT_TIMEOUT)
    result = nil

    File.open(@path, File::CREAT|File::EXCL|File::WRONLY, 0644) do |f|
      f.puts contents
      f.flush
      Timeout.timeout(timeout_duration) do
        begin
          result = yield
        ensure
          unlock!
        end
      end
    end
    return result
  rescue Errno::EEXIST
    sleep 1
    retry
  ensure
    unlock!
  end
  alias synchronize lock!

  # Forces this lock to be unlocked. Does nothing if the lock is already
  # unlocked.

  def unlock!
    FileUtils.rm_f @path
  end

  private

  def contents
    "created=#{Time.now.to_s}, pid=#{Process.pid}, thread=#{Thread.current.object_id}\n\n" + caller.join("\n")
  end
end
