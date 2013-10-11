#!/usr/bin/env ruby

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

# To remove all Gem dependencies for the setup script, the Colored gem is
# included here wholesale. For authorship, etc.: https://github.com/defunkt/colored

module Colored
  extend self

  COLORS = {
      'black'   => 30,
      'red'     => 31,
      'green'   => 32,
      'yellow'  => 33,
      'blue'    => 34,
      'magenta' => 35,
      'cyan'    => 36,
      'white'   => 37
  }

  EXTRAS = {
      'clear'     => 0,
      'bold'      => 1,
      'underline' => 4,
      'reversed'  => 7
  }

  COLORS.each do |color, value|
    define_method(color) do
      colorize(self, :foreground => color)
    end

    define_method("on_#{color}") do
      colorize(self, :background => color)
    end

    COLORS.each do |highlight, value|
      next if color == highlight
      define_method("#{color}_on_#{highlight}") do
        colorize(self, :foreground => color, :background => highlight)
      end
    end
  end

  EXTRAS.each do |extra, value|
    next if extra == 'clear'
    define_method(extra) do
      colorize(self, :extra => extra)
    end
  end

  define_method(:to_eol) do
    tmp = sub(/^(\e\[[\[\e0-9;m]+m)/, "\\1\e[2K")
    if tmp == self
      return "\e[2K" << self
    end
    tmp
  end

  def colorize(string, options = {})
    colored = [color(options[:foreground]), color("on_#{options[:background]}"), extra(options[:extra])].compact * ''
    colored << string
    colored << extra(:clear)
  end

  def colors
    @@colors ||= COLORS.keys.sort
  end

  def extra(extra_name)
    extra_name = extra_name.to_s
    "\e[#{EXTRAS[extra_name]}m" if EXTRAS[extra_name]
  end

  def color(color_name)
    background = color_name.to_s =~ /on_/
    color_name = color_name.to_s.sub('on_', '')
    return unless color_name && COLORS[color_name]
    "\e[#{COLORS[color_name] + (background ? 10 : 0)}m"
  end
end unless Object.const_defined? :Colored

String.send(:include, Colored)

############################## BEGIN SETUP SCRIPT ##############################

def bool(str) 'YyTt1'.include? str[0, 1] end
def say(*strs) puts strs.join(' ') end

def prompt(message, default_yes=true)
  y = default_yes ? 'Y' : 'y'
  n = default_yes ? 'n' : 'N'
  say message.green.bold, "[#{y}/#{n}]".green

  answer = gets.strip
  if answer.empty?
    answer = default_yes
  else
    answer = bool(answer)
  end

  return answer
end

def prompt_or_quit(*args) exit unless prompt(*args) end

def run(*command)
  args = ["Running".cyan]
  args += command.map { |s| s.cyan.bold }
  args << "...".cyan
  say *args

  stdout, stderr, status = Open3.capture3(*command)
  unless status.success?
    say "Command exited unsuccessfully:".red.bold, status.inspect.red
    puts
    say "stdout".underline.bold
    puts stdout
    puts
    say "stderr".underline.bold
    puts stderr
    exit 1
  end
  stdout
end

def run_ignore(*command)
  args = ["Running".cyan]
  args += command.map { |s| s.cyan.bold }
  args <<  "... (failure OK)".cyan
  say *args

  system *command
end

def query(question, default=nil)
  output = ''
  begin
    if default
      say question.green.bold, "[#{default.empty? ? 'blank' : default}]".green
    else
      say question.green.bold
    end

    output = gets.strip
    output = default if default && output.empty?
  end while output.empty? && default != ''
  output == '' ? nil : output
end

def choose(question, choices, default=nil)
  output = nil
  until choices.include?(output)
    if default
      say question.green.bold, "(#{choices.join('/')})".green, "[#{default}]".green
    else
      say question.green.bold, "(#{choices.join('/')})".green
    end

    output = gets.strip.downcase
    output = default if default && output == ''
    output = choices.detect { |c| c.downcase =~ /^#{Regexp.escape output}/ }
  end

  return output
end

if RUBY_VERSION < '1.9.2'
  say "You need Ruby 1.9.2 or newer to use Squash.".red.bold
  say "Please re-run this script under a newer version of Ruby.".magenta
  exit 1
end

if RUBY_PLATFORM == 'java'
  say "This setup script must be run on MRI 1.9.2 or newer.".red.bold
  say "You can run Squash itself on JRuby, but this script must be run on MRI."
  say "See http://jira.codehaus.org/browse/JRUBY-6409 for the reason why."
  exit 1
end

say "Welcome! Let's set up your Squash installation.".bold
puts "I'll ask you some questions to help configure Squash for your needs.",
     "Remember to read the README.md file to familiarize yourself with the Squash",
     "codebase, as there's a strong likelihood you'll need to make other tweaks",
     "to fully support your particular environment."
puts
puts "If something's not right, you can abort this script at any time; it's",
     "resumable. Simply rerun it when you are ready."

say
say "Checking the basic environment..."

if File.absolute_path(Dir.getwd) != File.absolute_path(File.dirname(__FILE__))
  say "You are not running this script from the Rails project's root directory.".red.bold
  say "Please cd into the project root and re-run this script.".magenta
  exit 1
end

step = File.read('/tmp/squash_install_progress').to_i rescue 0

if step == 0 && !`git status --porcelain`.empty?
  say "You have a dirty working directory.".red.bold
  puts "It's #{"highly".bold} recommended to run this script on a clean working",
       "directory. In the event you get some answers wrong, or change your mind",
       "later, it will be easy to see what files the script changed, and update",
       "them accordingly."
  prompt_or_quit "Continue?", false
end

say "Checking for required software..."

require 'open3'
require 'yaml'
require 'fileutils'
require 'securerandom'

if `which psql`.empty?
  say "You need PostgreSQL version 9.0 or newer to use Squash.".red.bold
  say "Please install PostgreSQL and re-run this script.".magenta
  exit 1
end

unless `psql -V` =~ /^psql \(PostgreSQL\) (\d{2,}|9)\./
  say "You need PostgreSQL version 9.0 or newer to use Squash.".red.bold
  say "Please upgrade PostgreSQL and re-run this script.".magenta
  exit 1
end

if `which bundle`.empty?
  say "You need Bundler to use Squash.".red.bold
  say "Please run", "gem install bundler".bold, "and re-run this script.".magenta
  exit 1
end

say
say "We will now install gems if you are ready (in the correct gemset, etc.)."

prompt_or_quit "Are you ready to install required gems?"
run 'bundle', 'install'

if step < 1
  say
  say "Now let's configure production hostname and URL settings.".bold
  puts "If you don't know what URL your production instance will have, just make",
       "something up. You can always change it later."

  hostname     = query("What hostname will your production instance have (e.g., squash.mycompany.com)?")
  https        = prompt("Will your production instance be using HTTPS?", hostname)
  email_domain = query("What is the domain portion of your organization's email addresses?", hostname)
  sender       = query("What sender should Squash emails use?", "squash@#{email_domain}")

  say "Updating config/environments/common/mailer.yml..."
  File.open('config/environments/common/mailer.yml', 'w') do |f|
    f.puts({
               'from'   => sender,
               'domain' => email_domain
           }.to_yaml)
  end
  say "Updating config/environments/production/mailer.yml..."
  File.open('config/environments/production/mailer.yml', 'w') do |f|
    f.puts({
               'default_url_options' => {
                   'host'     => hostname,
                   'protocol' => https ? 'https' : 'http'
               }
           }.to_yaml)
  end
  unless https
    say "Updating config/environments/production.rb..."
    prod_config = File.read('config/environments/production.rb')
    prod_config.sub! 'config.force_ssl = true', 'config.force_ssl = false'
    prod_config.sub! 'config.middleware.insert_before ::ActionDispatch::SSL, Ping',
                     'config.middleware.insert_before ::Rack::Runtime, Ping'
    File.open('config/environments/production.rb', 'w') do |f|
      f.puts prod_config
    end
  end

  url = query("What URL will production Squash be available at?", "http#{'s' if https}://#{hostname}")
  say "Updating config/environments/production/javascript_dogfood.yml..."
  File.open('config/environments/production/javascript_dogfood.yml', 'w') do |f|
    f.puts({'APIHost' => url}.to_yaml)
  end
  say "Updating config/environments/production/dogfood.yml..."
  dogfood = YAML.load_file('config/environments/production/dogfood.yml')
  File.open('config/environments/production/dogfood.yml', 'w') do |f|
    f.puts dogfood.merge('api_host' => url).to_yaml
  end

  File.open('/tmp/squash_install_progress', 'w') { |f| f.puts '1' }
end

if step < 2
  say
  say "Now we'll cover authentication.".bold

  auth = choose("How will users authenticate to Squash?", %w(password LDAP))
  if auth == 'LDAP'
    ldap_host  = query("What's the hostname of your LDAP server?")
    ldap_ssl   = prompt("Is your LDAP service using SSL?")
    ldap_port  = query("What port is your LDAP service running on?", ldap_ssl ? '636' : '389').to_i
    tree_base  = query("Under what tree base can the user records be found in LDAP?")
    search_key = query("What search key should I use to locate a user by username under that tree?", 'uid')
    bind_dn = query("Will you be using a different DN to bind to the LDAP server? If so, enter it now.", '')
    bind_pw = query("What is the password for #{bind_dn}?") if bind_dn
    say "Updating config/environments/common/authentication.yml..."
    File.open('config/environments/common/authentication.yml', 'w') do |f|
      f.puts({
                 'strategy' => 'ldap',
                 'ldap'     => {
                     'host'          => ldap_host,
                     'port'          => ldap_port,
                     'ssl'           => ldap_ssl,
                     'tree_base'     => tree_base,
                     'search_key'    => search_key,
                     'bind_dn'       => bind_dn,
                     'bind_password' => bind_pw
                 }
             }.to_yaml)
    end
  elsif auth == 'password'
    say "Updating config/environments/common/authentication.yml..."
    File.open('config/environments/common/authentication.yml', 'w') do |f|
      f.puts({
                 'strategy' => 'password',
                 'registration_enabled' => true,
                 'password' => {
                     'salt' => SecureRandom.base64
                 }
             }.to_yaml)
    end
  end

  File.open('/tmp/squash_install_progress', 'w') { |f| f.puts '2' }
end

if step < 3
  say
  say "Let's set up your database now.".bold
  say "If you don't know the answer to a question, give a best guess. You can always",
      "change your database.yml file later."

  dev_host = query("What is the hostname of the development PostgreSQL server?", 'localhost')
  dev_user = query("What PostgreSQL user will Squash use in development?", 'squash')
  dev_pw   = query("What is #{dev_user}@#{dev_host}'s password?", '')
  dev_local = dev_host.nil? || dev_host == 'localhost' || dev_host == '0.0.0.0' || dev_host == '127.0.0.1'
  dev_db   = query("What is the name of your PostgreSQL development database?#{" (It doesn't have to exist yet.)" if dev_local}", 'squash_development')

  test_host = query("What is the hostname of the test PostgreSQL server?", 'localhost')
  test_user = query("What PostgreSQL user will Squash use in test?", dev_user)
  test_pw   = query("What is #{test_user}@#{test_host}'s password?", '')
  test_db   = query("What is the name of your PostgreSQL test database?", 'squash_test')

  prod_host = query("What is the hostname of the production PostgreSQL server?", 'localhost')
  prod_user = query("What PostgreSQL user will Squash use in production?", dev_user)
  prod_pw   = query("What is #{prod_user}@#{prod_host}'s password?", '')
  prod_db   = query("What is the name of your PostgreSQL production database?", 'squash_production')

  say "Updating config/database.yml..."
  File.open('config/database.yml', 'w') do |f|
    common = {
        'adapter'  => 'postgresql', # temporarily for the rake db:migrate calls
        'encoding' => 'utf8'
    }
    f.puts({
               'development' => common.merge(
                   'host' => dev_host,
                   'username' => dev_user,
                   'password' => dev_pw,
                   'database' => dev_db
               ),
               'test'        => common.merge(
                   'host' => test_host,
                   'username' => test_user,
                   'password' => test_pw,
                   'database' => test_db
               ),
               'production'  => common.merge(
                   'host' => prod_host,
                   'username' => prod_user,
                   'password' => prod_pw,
                   'database' => prod_db,
                   'pool'     => 30
               )
           }.to_yaml)
  end

  File.open('/tmp/squash_install_progress', 'w') { |f| f.puts '3' }
end

if step < 4
  db_config = YAML.load_file('config/database.yml')

  dev_host  = db_config['development']['host']
  dev_user  = db_config['development']['username']
  dev_db    = db_config['development']['database']
  dev_local = (dev_host.nil? || dev_host == 'localhost' || dev_host == '0.0.0.0' || dev_host == '127.0.0.1')

  test_host  = db_config['test']['host']
  test_user  = db_config['test']['username']
  test_db    = db_config['test']['database']
  test_local = (test_host.nil? || test_host == 'localhost' || test_host == '0.0.0.0' || test_host == '127.0.0.1')

  run_ignore 'createuser', '-DSR', 'squash' if dev_local

  dbs = `psql -ltA | awk -F'|' '{ print $1 }'`.split(/\n/)

  if dev_local
    unless dbs.include?(dev_db)
      prompt_or_quit "Ready to create the development database?"
      run "createdb", '-O', dev_user, dev_db
    end
  end
  prompt_or_quit "Ready to migrate the development database?"
  run 'rake', 'db:migrate'

  if test_local
    unless dbs.include?(test_db)
      prompt_or_quit "Ready to create the test database?"
      run "createdb", '-O', test_user, test_db
    end
  end
  prompt_or_quit "Ready to migrate the test database?"
  run 'env', 'RAILS_ENV=test', 'rake', 'db:migrate'

  File.open('/tmp/squash_install_progress', 'w') { |f| f.puts '4' }
end

if step < 5
  say "Generating session secret..."
  secret = SecureRandom.hex
  contents = File.read('config/initializers/secret_token.rb')
  File.open('config/initializers/secret_token.rb', 'w') do |f|
    f.puts contents.sub('_SECRET_', secret)
  end
  File.open('/tmp/squash_install_progress', 'w') { |f| f.puts '5' }
end

say
say "All done!".green.bold, "You should now be able to run".green,
    "rails server.".green.bold, "Some notes:".green
puts
say "* If you want Squash to monitor itself for errors in production, edit".yellow
say " ", "config/environments/production/dogfood.yml".bold.yellow, "and set".yellow, "disabled".bold.yellow, "to".yellow
say " ", "false.".bold.yellow, "When you deploy Squash to production, create a project for itself".yellow
say "  and copy the generated API key to this file.".yellow
puts
say "* Test that all specs pass by running".yellow, 'rspec spec.'.bold.yellow
puts
puts "* You can delete this setup script now if you wish.".yellow

FileUtils.rm '/tmp/squash_install_progress'
