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

if defined?(Squash::Configuration) && Squash::Configuration.concurrency.background_runner == 'Multithread'
  gem 'rails', github: 'rails/rails', branch: '3-2-stable'
  # We need to use this branch of Rails because it includes fixes for
  # ActiveRecord and concurrency that we need for our thread-spawning background
  # job paradigm to work
else
  gem 'rails', '~> 3.2.0'
end

gem 'configoro', '>= 1.2.4'
gem 'rack-cors', require: 'rack/cors'
