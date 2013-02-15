require 'resque/tasks'
require 'resque/pool/tasks'

namespace :resque do
  task :setup => :environment

  task 'pool:setup' do 
    ActiveRecord::Base.connection.disconnect!
    Resque::Pool.after_prefork do |job|
      ActiveRecord::Base.establish_connection
    end
  end
end
