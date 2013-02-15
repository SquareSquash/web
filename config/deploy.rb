require 'bundler/capistrano'
require 'capistrano/ext/multistage'

set :stages, %w(staging production)
set :default_stage, 'staging'
set :application, 'squash'
set :repository,  'git@github.com:optoro/squash-web.git'
set :scm, :git
set :deploy_to, "/var/www/railsapps/#{application}"
set :branch, 'master'
set :deploy_via, :remote_cache
set :use_sudo, false
set :user, 'deploy'
set :web_script, "/etc/init.d/unicorn-#{application}.sh"
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup"
after "deploy:restart", "deploy:resque:restart"

namespace :deploy do
  task :restart do
    run "sudo #{web_script} upgrade"
  end

  task :stop do
    run "sudo #{web_script} stop"
  end

  task :start do
    run "sudo #{web_script} start"
  end

  namespace :resque do
    task :restart do
      run ". ~/.profile ; /etc/init.d/#{application}_resque restart"
    end
  end
end


# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
