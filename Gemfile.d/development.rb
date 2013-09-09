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

group :development do
  gem 'yard', require: nil
  gem 'redcarpet', require: nil, platform: :mri

  gem 'json-schema', '< 2.0.0' # version 2.0 breaks fdoc
  gem 'fdoc'
end

gem 'sql_origin', groups: [:development, :test]
