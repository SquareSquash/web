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

# Adds LDAP-based authentication to the {User} model. Mixed in if this
# Squash install is configured to use LDAP-based authentication.

module LdapAuthentication
  extend ActiveSupport::Concern

  # @return [String] This user's LDAP distinguished name (DN).

  def distinguished_name
    "#{Squash::Configuration.authentication.ldap.search_key}=#{username},#{Squash::Configuration.authentication.ldap.tree_base}"
  end

  private

  def create_primary_email
    emails.create!(email: "#{username}@#{Squash::Configuration.mailer.domain}", primary: true)
  end
end

