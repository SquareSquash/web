module BackgroundRunner
  module Resque
    @@queue = :squash

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
      p rails_env
      ::Resque.inline = true if rails_env == 'test'
    end

    def self.run(job_name, *arguments)
      job_name = job_name.constantize unless job_name.kind_of?(Class)
      ::Resque.enqueue_to(@@queue, job_name, *arguments)
    end
  end
end

# If we're loading resque-web using this file, we'll need to run setup manually
#
# resque-web lib/background_runner/resque.rb

if File.expand_path(ARGV.first, Dir.getwd) == File.expand_path(__FILE__, Dir.getwd)
  BackgroundRunner::Resque.setup
end
