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

# Includes methods for authentication with LDAP. Information for the LDAP server
# is stored in the `authentication.yml` Configoro file for the current
# environment. A successful BIND yields an authenticated session.
#
# If this is the user's first time logging in, the User will be created for him
# or her.

module LdapAuthenticationHelpers

  # Attempts to log in a user, given his/her credentials. If the login fails,
  # the reason is logged and tagged with "[AuthenticationHelpers]". If the login
  # is successful, the user ID is written to the session. Also creates or
  # updates the User as appropriate.
  #
  # @param [String] username The LDAP username.
  # @param [String] password The LDAP password.
  # @return [true, false] Whether or not the login was successful.

  def log_in(username, password)
    username = username.downcase
    username.sub! /@#{Regexp.escape Squash::Configuration.mailer.domain}$/, ''

    dn    = "#{Squash::Configuration.authentication.ldap.search_key}=#{username},#{Squash::Configuration.authentication.ldap.tree_base}"
    ldap  = build_ldap_interface
    entry = nil

    if Squash::Configuration.authentication.ldap[:bind_dn]
      ldap.auth Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password
      if ldap.bind
        if (entry = locate_ldap_user(ldap, username))
          ldap.auth entry.dn, password
          unless ldap.bind
            logger.tagged('AuthenticationHelpers') { logger.info "Denying login to #{username}: LDAP authentication failed." }
            return false
          end
        else
          logger.tagged('AuthenticationHelpers') { logger.info "Denying login to #{username}: Couldn't locate user." }
        end
      else
        logger.tagged('AuthenticationHelpers') { logger.info "Couldn't bind using authenticator DN." }
      end
    else
      ldap.auth dn, password
      if ldap.bind
        entry = locate_ldap_user(ldap, username)
      end
    end

    if entry
      user = find_or_create_user_from_ldap_entry(entry, username)
      log_in_user user
      return true
    else
      logger.tagged('AuthenticationHelpers') { logger.info "Denying login to #{username}: LDAP authentication failed." }
      return false
    end
  rescue Net::LDAP::LdapError
    respond_to do |format|
      format.html do
        flash.now[:alert] = t('controllers.sessions.create.ldap_error')
        return false
      end
    end
  end

  private

  def build_ldap_interface
    ldap      = Net::LDAP.new
    ldap.host = Squash::Configuration.authentication.ldap.host
    ldap.port = Squash::Configuration.authentication.ldap.port
    ldap.encryption(:start_tls) if Squash::Configuration.authentication.ldap.ssl
    ldap
  end

  def locate_ldap_user(ldap, username)
    entry  = nil
    filter = Net::LDAP::Filter.eq(Squash::Configuration.authentication.ldap.search_key, username)
    ldap.search(base: Squash::Configuration.authentication.ldap.tree_base, filter: filter) { |e| entry = e }
    entry
  end

  def find_or_create_user_from_ldap_entry(entry, username)
    User.where(username: username).create_or_update!(first_name: entry[:givenname].first,
                                                     last_name:  entry[:sn].first)
  end
end
