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

unless defined?(Squash)
  puts "You must run this script using `rails runner`."
  exit 1
end

if Squash::Configuration.jira.disabled?
  puts "JIRA integration is disabled. Set disabled: false in your environment's"
  puts "jira.yml file."
  exit 1
end

if Squash::Configuration.jira.authentication.strategy != 'oauth'
  puts "JIRA integration is not using OAuth authentication. Set"
  puts "authentication.strategy to 'oauth' in your environment's jira.yml file."
  exit 1
end

if !Squash::Configuration.jira.authentication[:private_key_file] || !Squash::Configuration.jira.authentication[:consumer_key]
  puts "You need to set the 'consumer_key' and 'private_key_file' keys in the"
  puts "authentication section of your environment's jira.yml file. You generate"
  puts "the consumer key and private key as part of creating an OAuth application"
  puts "entry in your JIRA administration panel. You can have Squash generate"
  puts "them for you by running `rake jira:generate_consumer_key` and"
  puts "`jira:generate_public_cert`."
  exit 1
end

client        = Service::JIRA.client(timeout:      60,
                                     open_timeout: 60,
                                     read_timeout: 60)
request_token = client.request_token

puts "Visit the following URL in your browser: #{request_token.authorize_url}"
puts "Log in as the JIRA user you wish Squash to use, authorize Squash, and then"
puts "enter the verification code below."
puts
verification_code = nil
while verification_code.blank?
  puts "Verification code:"
  verification_code = gets.strip
end

access_token = client.init_access_token(oauth_verifier: verification_code)

puts "Place the following entries in your jira.yml file under the authentication"
puts "section:"
puts
puts "token: #{access_token.token}"
puts "secret: #{access_token.secret}"
