group :assets do
  gem 'sass-rails'
  gem 'libv8', '~> 3.11.8', platform: :mri
  gem 'therubyracer', '>= 0.11.1', platform: :mri
  # Version 2.0 of TheRubyRhino breaks asset compilation
  gem 'therubyrhino', platform: :jruby
  gem 'less-rails'

  gem 'coffee-rails'
  gem 'uglifier'

  gem 'font-awesome-rails'
end
