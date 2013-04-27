conditionally('concurrency.background_runner', 'Resque') do
  gem 'resque'
  gem 'resque-pool'
end

conditionally('concurrency.background_runner', 'Sidekiq') do
  gem 'sidekiq'
end
