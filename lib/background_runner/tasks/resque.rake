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

require 'resque/tasks'
require 'resque/pool/tasks'

# We'll override the default pool task in order to use our Squash config
Rake::Task['resque:pool'].clear

namespace :resque do
  task setup: :environment

  task 'pool:setup' do
    ActiveRecord::Base.connection.disconnect!
    Resque::Pool.after_prefork do |_job|
      ActiveRecord::Base.establish_connection
    end
  end

  desc "Launch a pool of resque workers"
  task pool: %w[resque:setup resque:pool:setup] do
    require 'resque/pool'

    rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
    rails_env  = ENV['RAILS_ENV'] || 'development'

    common_file = File.join(rails_root.to_s, 'config', 'environments', 'common', 'concurrency.yml')
    env_file    = File.join(rails_root.to_s, 'config', 'environments', rails_env, 'concurrency.yml')

    config = YAML.load_file(common_file)
    if File.exist?(env_file)
      config.merge! YAML.load_file(env_file)
    end

    if GC.respond_to?(:copy_on_write_friendly=)
      GC.copy_on_write_friendly = true
    end

    Resque::Pool.new(config['resque']['pool']).start.join
  end
end
