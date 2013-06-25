group :development do
  gem 'yard', require: nil
  gem 'redcarpet', require: nil, platform: :mri

  gem 'json-schema', '< 2.0.0' # version 2.0 breaks fdoc
  gem 'fdoc'
end

gem 'sql_origin', groups: [:development, :test]
