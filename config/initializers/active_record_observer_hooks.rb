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

#HACK Because the config/initializers load before rspec/rails, we need to delay
# loading this file until after RSpec has been configured. Thus, we require it
# a second time in spec_helper, and make sure it only executes then.

if !defined?(RSpec) ||                                            # we're running in a non-test environment, OR
    (RSpec.respond_to?(:configuration) &&                         # we're not running a console in test and
    RSpec.configuration.respond_to?(:use_transactional_fixtures)) # the rspec/rails gem has loaded

  # Adds `after_commit_on_create`, `after_commit_on_update`,
  # `after_commit_on_save`, and `after_commit_on_destroy` hooks to
  # `ActiveRecord::Observer`. These hooks are run as `after_save` hooks in test
  # if `use_transactional_fixtures` is enabled.

  class ActiveRecord::Base
    if defined?(RSpec) && RSpec.configuration.use_transactional_fixtures
      puts "Attaching after_commit_on_* hooks to after_save"

      after_create do |obj|
        obj.send :notify_observers, :after_commit_on_create
      end

      after_update do |obj|
        #HACK after_commit(on: :update) would be executed after #changes had
        # been moved to #previous_changes ... so we have to simulate that here
        # for a consistent test environment
        obj.instance_variable_set :@previously_changed, obj.changes
        obj.send :notify_observers, :after_commit_on_update
      end

      after_save do |obj|
        obj.instance_variable_set :@previously_changed, obj.changes #HACK see previous
        obj.send :notify_observers, :after_commit_on_save
      end

      after_destroy do |obj|
        obj.send :notify_observers, :after_commit_on_destroy
      end

    else
      puts "Attaching after_commit_on_* hooks to after_commit"

      after_commit(on: :create) do |obj|
        obj.send :notify_observers, :after_commit_on_create
      end

      after_commit(on: :update) do |obj|
        obj.send :notify_observers, :after_commit_on_update
      end

      after_commit(if: :persisted?) do |obj|
        obj.send :notify_observers, :after_commit_on_save
      end

      after_commit(on: :destroy) do |obj|
        obj.send :notify_observers, :after_commit_on_destroy
      end
    end
  end
end
