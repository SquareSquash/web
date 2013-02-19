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
set :resque_script, ". ~/.profile ; /etc/init.d/#{application}_resque"
ssh_options[:forward_agent] = true

after "deploy", "deploy:cleanup"
after "deploy:restart", "deploy:resque:restart"
after "deploy:start", "deploy:resque:start"
after "deploy:stop", "deploy:resque:stop"

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
      run "#{resque_script} restart"
    end

    task :start do
      run "#{resque_script} start"
    end

    task :stop do
      run "#{resque_script} stop"
    end
  end
end

