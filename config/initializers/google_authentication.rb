# encoding: utf-8

#TODO: License
# Copyright 2015 Powershop Ltd.
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

SimpleGoogleAuth.configure do |config|
  config.client_id     = Squash::Configuration.authentication.google.client_id
  config.client_secret = Squash::Configuration.authentication.google.client_secret
  config.redirect_uri  = Squash::Configuration.authentication.google.redirect_uri
  config.authenticate  = lambda do |data|
    allowed_domains = Squash::Configuration.authentication.google.allowed_domains
    fail "Must provide a list of accepted Google domains" if allowed_domains.nil? || allowed_domains.empty?

    ! allowed_domains.select {|domain| data.email.ends_with? "@#{domain}" }.empty?
  end
end if Squash::Configuration.authentication.strategy == 'google'
