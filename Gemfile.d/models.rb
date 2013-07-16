gem 'pg', platform: :mri
# Version 1.2.6 introduces a bug relating to SQL binds
gem 'activerecord-jdbc-adapter', '1.2.5', platform: :jruby
gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby
gem 'has_metadata_column', github: 'RISCfuture/has_metadata_column', ref: 'b0ab7837884d78ec6da492d822d31f2da6682dc7'
gem 'slugalicious'
gem 'email_validation'
gem 'url_validation'
gem 'json_serialize'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes', '>= 1.2.1'
gem 'composite_primary_keys', github: 'RISCfuture/composite_primary_keys', ref: '94059068169ff1c0735329d600a80eed99ecd58c'

conditionally('activerecord.cursors', true) do
  gem 'activerecord-postgresql-cursors'
end
