require 'bundler/capistrano'

set :application, 'squash'
set :repository,  'git@github.com:optoro/squash-web.git'
set :scm, :git
set :deploy_to, "var/www/railsapps/#{application}"
server '33.33.33.20', :app, :web, :db, :primary => true
set :branch, 'master'
set :deploy_via, :remote_cache
set :use_sudo, false
set :user, 'deploy'
ssh_options[:forward_agent] = true

after "deploy:restart", "deploy:cleanup"


# If you are using Passenger mod_rails uncomment this:
# namespace :deploy do
#   task :start do ; end
#   task :stop do ; end
#   task :restart, :roles => :app, :except => { :no_release => true } do
#     run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
#   end
# end
