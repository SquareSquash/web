# Vagrant box
server '33.33.33.20', :app, :web, :db, :primary => true
default_run_options[:pty] = true
