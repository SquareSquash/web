require 'resque/tasks'
require 'resque/pool/tasks'

# We'll override the default pool task in order to use our Squash config
Rake::Task['resque:pool'].clear

namespace :resque do
  task :setup => :environment

  task 'pool:setup' do 
    ActiveRecord::Base.connection.disconnect!
    Resque::Pool.after_prefork do |job|
      ActiveRecord::Base.establish_connection
    end
  end

  desc "Launch a pool of resque workers"
  task :pool => %w[resque:setup resque:pool:setup] do
    require 'resque/pool'
    
    rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
    config = YAML.load_file(rails_root.to_s + '/config/environments/common/concurrency.yml')

    if GC.respond_to?(:copy_on_write_friendly=)
      GC.copy_on_write_friendly = true
    end

    Resque::Pool.new(config['resque']['pool']).start.join
  end
end
