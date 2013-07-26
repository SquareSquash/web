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

module BackgroundRunner

  # `BackgroundRunner` adapter for the Resque job system. See the
  # `concurrency.yml` Configoro file for configuration options.

  module Resque
    def self.setup
      rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
      rails_env  = ENV['RAILS_ENV'] || 'development'

      common_file = File.join(rails_root.to_s, 'config', 'environments', 'common', 'concurrency.yml')
      env_file    = File.join(rails_root.to_s, 'config', 'environments', rails_env, 'concurrency.yml')

      config = YAML.load_file(common_file)
      if File.exist?(env_file)
        config.merge! YAML.load_file(env_file)
      end

      ::Resque.redis = config['resque'][rails_env]
      ::Resque.inline = true if rails_env == 'test'
    end

    def self.run(job_name, *arguments)
      job_name = job_name.constantize unless job_name.kind_of?(Class)
      ::Resque.enqueue job_name.const_get(:ResqueAdapter), *arguments
    end

    def self.extend_job(mod)
      resque_adapter = Class.new
      resque_adapter.instance_variable_set :@queue, Squash::Configuration.concurrency.resque.queue[mod.to_s]
      resque_adapter.singleton_class.send(:define_method, :perform) do |*args|
        mod.perform *args
      end

      mod.const_set :ResqueAdapter, resque_adapter
    end
  end
end

if Squash::Configuration.concurrency.background_runner == 'Resque'
  # If we're loading resque-web using this file, we'll need to run setup manually
  #
  # resque-web lib/background_runner/resque.rb

  if !ARGV.empty? && File.expand_path(ARGV.first, Dir.getwd) == File.expand_path(__FILE__, Dir.getwd)
    BackgroundRunner::Resque.setup
  end
end
