require 'resque/tasks'

namespace :resque do
  task :setup => :environment
end
