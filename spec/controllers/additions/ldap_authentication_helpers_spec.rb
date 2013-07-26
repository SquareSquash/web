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

require 'spec_helper'

if Squash::Configuration.authentication.strategy == 'ldap'
  class FakeController
    def self.helper_method(*) end
    def logger(*) Rails.logger end

    include AuthenticationHelpers
    include LdapAuthenticationHelpers
  end

  describe LdapAuthenticationHelpers do
    describe "#log_in" do
      before(:all) { @user = FactoryGirl.create(:user) }

      before :each do
        @controller = FakeController.new
        @ldap       = double('Net::LDAP')
        @controller.stub(:build_ldap_interface).and_return(@ldap)
      end

      it "should return true if the LDAP entry exists and can bind" do
        entry = {
            givenname: 'Foo',
            sn:        'Bar',
            dn:        "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username},#{Squash::Configuration.authentication.ldap.tree_base}"
        }
        entry.stub(:dn).and_return(entry[:dn])

        @ldap.should_receive(:search).once do |hsh|
          hsh[:filter].to_raw_rfc2254 == "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username}"
        end.and_yield(entry)

        @ldap.should_receive(:auth).once.with(
            /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=#{Regexp.escape @user.username},/,
            'password'
        )

        if Squash::Configuration.authentication.ldap[:bind_dn]
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
        end

        @ldap.stub(:bind).and_return(true)

        @controller.should_receive(:log_in_user).once.with(@user)
        @controller.log_in(@user.username, 'password').should be_true
      end

      it "should extract the username from an email address login" do
        entry = {
            givenname: 'Foo',
            sn:        'Bar',
            dn:        "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username},#{Squash::Configuration.authentication.ldap.tree_base}"
        }
        entry.stub(:dn).and_return(entry[:dn])

        @ldap.should_receive(:search).once do |hsh|
          hsh[:filter].to_raw_rfc2254 == "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username}"
        end.and_yield(entry)

        @ldap.should_receive(:auth).once.with(
            /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=#{Regexp.escape @user.username},/,
            'password'
        )

        if Squash::Configuration.authentication.ldap[:bind_dn]
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
        end

        @ldap.stub(:bind).and_return(true)

        @controller.should_receive(:log_in_user).once.with(@user)
        @controller.log_in("#{@user.username}@#{Squash::Configuration.mailer.domain}", 'password').should be_true
      end

      it "should return false if the LDAP entry does not exist" do
        @ldap.should_receive(:search).once do |hsh|
          hsh[:filter].to_raw_rfc2254 == "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username}"
        end

        if Squash::Configuration.authentication.ldap[:bind_dn]
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
        else
          @ldap.should_receive(:auth).once.with(
              /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=#{Regexp.escape @user.username},/,
              'password'
          )
        end

        @ldap.stub(:bind).and_return(true)

        @controller.should_not_receive :log_in_user
        @controller.log_in(@user.username, 'password').should be_false
      end

      if Squash::Configuration.authentication.ldap[:bind_dn]
        it "should return false if the user cannot bind" do
          entry = {
              givenname: 'Foo',
              sn:        'Bar',
              dn:        "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username},#{Squash::Configuration.authentication.ldap.tree_base}"
          }
          entry.stub(:dn).and_return(entry[:dn])

          @ldap.should_receive(:search).once do |hsh|
            hsh[:filter].to_raw_rfc2254 == "#{Squash::Configuration.authentication.ldap.search_key}=#{@user.username}"
          end.and_yield(entry)

          @ldap.should_receive(:auth).once.with(
              /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=#{Regexp.escape @user.username},/,
              'password'
          )
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
          @ldap.should_receive(:bind).twice.and_return(true, false)

          @controller.should_not_receive :log_in_user
          @controller.log_in(@user.username, 'password').should be_false
        end

        it "should return false if the LDAP authenticator cannot bind" do
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
          @ldap.stub(:bind).once.and_return(false)

          @controller.should_not_receive :log_in_user
          @controller.log_in(@user.username, 'password').should be_false
        end
      else
        it "should return false if the user cannot bind" do
          @ldap.should_not_receive :search

          @ldap.should_receive(:auth).once.with(
              /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=#{Regexp.escape @user.username},/,
              'password'
          )

          @ldap.should_receive(:bind).once.and_return(false)

          @controller.should_not_receive :log_in_user
          @controller.log_in(@user.username, 'password').should be_false
        end
      end

      it "should create a new user if one doesn't already exist" do
        entry = {
            givenname: 'New',
            sn:        'User',
            dn:        "#{Squash::Configuration.authentication.ldap.search_key}=newuser,#{Squash::Configuration.authentication.ldap.tree_base}"
        }
        entry.stub(:dn).and_return(entry[:dn])

        @ldap.should_receive(:search).once do |hsh|
          hsh[:filter].to_raw_rfc2254 == "#{Squash::Configuration.authentication.ldap.search_key}=newuser"
        end.and_yield(entry)

        @ldap.should_receive(:auth).once.with(
            /#{Regexp.escape Squash::Configuration.authentication.ldap.search_key}=newuser,/,
            'password'
        )

        if Squash::Configuration.authentication.ldap[:bind_dn]
          @ldap.should_receive(:auth).once.with(Squash::Configuration.authentication.ldap.bind_dn, Squash::Configuration.authentication.ldap.bind_password)
        end

        @ldap.stub(:bind).and_return(true)

        @controller.should_receive(:log_in_user).once do |user|
          user.username == 'newuser' &&
              user.first_name == 'New' &&
              user.last_name == 'User'
        end
        @controller.log_in('newuser', 'password').should be_true
      end
    end
  end
end
