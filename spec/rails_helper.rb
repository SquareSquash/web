# Copyright 2014 Square Inc.
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


# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require 'spec_helper'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.check_pending!

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir.glob(Rails.root.join('spec', 'support', '**', '*.rb')).each do |file|
  require file
end

# Clear out the database to avoid duplicate key conflicts
Dir[Rails.root.join('app', 'models', '**', '*.rb')].each { |f| require f }
ActiveRecord::Base.subclasses.each do |model|
  next if model == ActiveRecord::SchemaMigration
  model.connection.execute "TRUNCATE #{model.table_name} CASCADE"
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!
end

FakeWeb.allow_net_connect = false

require Rails.root.join('config', 'initializers', 'active_record_observer_hooks')
# see comments in this file for more info

# Common login-testing strategies in the specs
#
if Squash::Configuration.authentication.strategy == 'google'
  RSpec.shared_context "setup for required logged-in user" do
    unless Squash::Configuration.authentication.strategy == 'google'
      def login_required_redirection_url(*args)
        login_url(*args)
      end

    else
      before :each do
        allow(SecureRandom).to receive(:hex).and_return('1234')
      end

      def login_required_redirection_url(*args)
        controller.instance_eval { google_authentication_uri }
      end
    end

  end
end

# Logs a user in for spec purposes.
#
# @params [User] user A user.

def login_as(user)
  allow(controller).to receive(:current_user).and_return(user)
end

# Returns the parameters that would be created when a polymorphic route is hit
# corresponding to the given model object.
#
# @param [ActiveRecord::Base] object A model object.
# @param [true, false] nested Whether or not there are further route components
#   nested beneath this one.
# @param [Hash<Symbol, String>] overrides Additional items to merge into the result hash.
# @return [Hash<Symbol, String>] The URL parameters.
#
# @example
#   polymorphic_params(some_comment, false) #=> {project_id: 'foo', environment_id: 'development', bug_id: 123, id: 3}
#   polymorphic_params(some_bug, true) #=> {project_id: 'bar', environment_id: 'test', id: 123}

def polymorphic_params(object, nested, overrides={})
  hsh = case object
          when Occurrence
            {project_id: object.bug.environment.project.to_param, environment_id: object.bug.environment.to_param, bug_id: object.bug.to_param, occurrence_id: object.to_param}
          when Bug
            {project_id: object.environment.project.to_param, environment_id: object.environment.to_param, bug_id: object.to_param}
          when Environment
            {project_id: object.project.to_param, environment_id: object.to_param}
          when Comment
            {project_id: object.bug.environment.project.to_param, environment_id: object.bug.environment.to_param, bug_id: object.bug.to_param, comment_id: object.to_param}
          when Event
            {project_id: object.bug.environment.project.to_param, environment_id: object.bug.environment.to_param, bug_id: object.bug.to_param, event_id: object.to_param}
          when Project
            {project_id: object.to_param}
          when Membership
            {project_id: object.project.to_param, membership_id: object.user.to_param}
          when Email
            {id: object.to_param}
          when User
            {user_id: object.to_param}
          else
            raise ArgumentError, "Unknown model type #{object.class}"
        end

  unless nested
    id_key   = hsh.keys.last
    hsh[:id] = hsh[id_key]
    hsh.delete id_key
  end

  return hsh.reverse_merge(overrides)
end

# Builds a JIRA API URL as used by JIRA-Ruby.

def jira_url(path)
  host     = Squash::Configuration.jira.api_host
  root     = Squash::Configuration.jira.api_root
  user     = Squash::Configuration.jira.authentication.user
  password = Squash::Configuration.jira.authentication.password

  host = host.gsub('://', "://#{user}:#{password}@")
  host + root + path
end

# @return [String] A random 40-digit hex number.

def random_sha
  40.times.map { rand(16).to_s(16) }.join
end

