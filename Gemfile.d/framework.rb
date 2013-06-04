if defined?(Squash::Configuration) && Squash::Configuration.concurrency.background_runner == 'Multithread'
  gem 'rails', github: 'rails/rails', branch: '3-2-stable'
  # We need to use this branch of Rails because it includes fixes for
  # ActiveRecord and concurrency that we need for our thread-spawning background
  # job paradigm to work
else
  gem 'rails', '>= 3.2.0'
end

gem 'configoro', '>= 1.2.4'
gem 'rack-cors', require: 'rack/cors'
