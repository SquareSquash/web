source :rubygems

# FRAMEWORK
gem 'rails', git: 'git://github.com/rails/rails.git', branch: '3-2-stable'
# We need to use this branch of Rails because it includes fixes for ActiveRecord
# and concurrency that we need for our thread-spawning background job paradigm
# to work
gem 'configoro'
gem 'rack-cors', require: 'rack/cors'

# MODELS
gem 'pg', platform: :mri
gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby
gem 'has_metadata_column', git: 'git://github.com/RISCfuture/has_metadata_column.git'
gem 'slugalicious'
gem 'email_validation'
gem 'url_validation'
gem 'json_serialize'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes'
gem 'composite_primary_keys', git: 'git://github.com/RISCfuture/composite_primary_keys.git'
gem 'activerecord-postgresql-cursors'

# VIEWS
gem 'erector'
gem 'jquery-rails'
gem 'kramdown'

# UTILITIES
gem 'json'
gem 'git', git: 'git://github.com/RISCfuture/ruby-git.git'
gem 'user-agent'

# AUTH
gem 'net-ldap', require: 'net/ldap'

# INTEGRATION
gem 'jira-ruby', require: 'jira'

# DOGFOOD
gem 'squash_ruby', require: 'squash/ruby'
gem 'squash_rails', require: 'squash/rails'
gem 'squash_ios_symbolicator', require: 'squash/symbolicator'
gem 'squash_javascript', require: 'squash/javascript'
gem 'squash_java', require: 'squash/java'

group :assets do
  gem 'sass-rails'
  gem 'libv8', '~> 3.11.8', platform: :mri
  gem 'therubyracer', '>= 0.11.1', platform: :mri
  # Version 2.0 of TheRubyRhino breaks asset compilation
  gem 'therubyrhino', '< 2.0', platform: :jruby
  gem 'less-rails'

  gem 'coffee-rails'
  gem 'uglifier'

  gem 'font-awesome-rails'
end

group :development do
  # DOCS
  gem 'yard', require: nil
  gem 'redcarpet', require: nil, platform: :mri
  gem 'fdoc'
end


group :test do
  # SPECS
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'fakeweb'
end

gem 'sql_origin', groups: [:development, :test]
