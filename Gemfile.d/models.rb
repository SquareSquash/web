# Copyright 2013 Square Inc.
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

gem 'pg', platform: :mri
gem 'activerecord-jdbcpostgresql-adapter', platform: :jruby
gem 'has_metadata_column', github: 'RISCfuture/has_metadata_column'
gem 'slugalicious'
gem 'email_validation'
gem 'url_validation'
gem 'json_serialize'
gem 'validates_timeliness'
gem 'find_or_create_on_scopes', '>= 1.2.1'
gem 'composite_primary_keys', github: 'RISCfuture/composite_primary_keys', branch: 'rebase'
gem 'rails-observers'

conditionally('activerecord.cursors', true) do
  gem 'activerecord-postgresql-cursors'
end
