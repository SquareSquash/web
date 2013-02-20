server 'squash.optiturn.com', :app, :web, :db, :primary => true
before 'deploy:assets:precompile', 'deploy:link_credentials'
