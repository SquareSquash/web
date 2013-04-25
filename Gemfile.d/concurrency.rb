conditionally('concurrency.background_runner', 'Resque') do
  gem 'resque'
  gem 'resque-pool'
end
