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

require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(:default, Rails.env)

# Load preinitializers
Dir.glob(File.expand_path('../preinitializers/**/*.rb', __FILE__)).each { |f| require f }

module Squash
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths << config.root.join('app', 'models', 'additions')
    config.autoload_paths << config.root.join('app', 'models', 'observers')
    config.autoload_paths << config.root.join('app', 'controllers', 'additions')
    config.autoload_paths << config.root.join('app', 'views', 'additions')
    config.autoload_paths << config.root.join('lib')
    config.autoload_paths << config.root.join('lib', 'workers')

    # Activate observers that should always be running.
    config.active_record.observers = :bug_observer, :comment_observer,
        :event_observer, :watch_observer, :occurrence_observer, :deploy_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Pacific Time (US & Canada)'

    # Use SQL instead of Active Record's schema dumper when creating the database.
    # This is necessary if your schema can't be completely dumped by the schema dumper,
    # like if you have constraints or database-specific column types
    config.active_record.schema_format = :sql

    # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
    config.assets.precompile << 'flot/excanvas.js'

    # Use custom generators
    config.generators do |g|
      g.template_engine     :erector
      g.test_framework      :rspec, fixture: true, views: false
      g.integration_tool    :rspec
      g.fixture_replacement :factory_girl, dir: 'spec/factories'
    end
  end
end

require 'api/errors'
