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

# A mutex that uses a lockfile to synchronize on. The presence of the lockfile
# does not necessarily indicate that the resource is in use; synchronization is
# done using flock, so the presence of an advisory lock is the only indicator
# that the resource is in use.
#
# The {#lock} method is for creating _shared_ locks; the {#lock!} method for
# creating _exclusive_ locks. Multiple threads/processes can open shared locks
# on a resource simultaneously, but the presence of one exclusive lock denies
# access to any other locks.

class FileMutex

  # Creates a new file-based mutex.
  #
  # @param [String] path The path to the lockfile (can be any file; will be
  # created if it doesn't exist).

  def initialize(path)
    @path = path
  end

  # @overload lock
  #   Attempts to acquire a shared lock on the resource. Returns `false` if
  #   the lock could not be acquired, `true` if it can. Returning `true` at one
  #   instant is not a guarantee that the lock will be available at the next
  #   instant.
  #   @return [true, false] Whether a shared lock is currently available.
  # @overload lock
  #   Attempts to acquire a shared lock on the resource. Blocks until a lock is
  #   available. Once a lock is available, acquires it, executes the provided
  #   block, and then releases the lock.
  #   @yield The code to run in the lock.
  #   @return The result of the block.

  def lock
    result = nil
    File.open(@path, File::RDONLY|File::CREAT) do |f|
      if block_given?
        f.flock File::LOCK_SH
        result = yield
      else
        return f.flock File::LOCK_SH|File::LOCK_NB
      end
    end
    return result
  end
  alias with_shared_lock lock

  # @overload lock!
  #   Attempts to acquire an exclusive lock on the resource. Returns `false` if
  #   the lock could not be acquired, `true` if it can. Returning `true` at one
  #   instant is not a guarantee that the lock will be available at the next
  #   instant.
  #   @return [true, false] Whether an exclusive lock is currently available.
  # @overload lock!
  #   Attempts to acquire an exclusive lock on the resource. Blocks until a lock
  #   is available. Once a lock is available, acquires it, executes the provided
  #   block, and then releases the lock.
  #   @yield The code to run in the lock.
  #   @return The result of the block.

  def lock!
    result = nil
    File.open(@path, File::RDWR|File::CREAT, 0644) do |f|
      if block_given?
        f.flock File::LOCK_EX
        result = yield
      else
        return f.flock File::LOCK_EX|File::LOCK_NB
      end
    end
    return result
  end
  alias synchronize lock!
  alias with_exclusive_lock lock!
end
