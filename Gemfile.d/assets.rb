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
