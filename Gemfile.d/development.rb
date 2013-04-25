group :development do
  gem 'yard', require: nil
  gem 'redcarpet', require: nil, platform: :mri
  gem 'fdoc'
end

gem 'sql_origin', groups: [:development, :test]
