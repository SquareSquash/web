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

# Adds GoogleAuth-based authentication to the {User} model. Mixed in if this
# Squash install is configured to use "google" authentication.

module GoogleAuthentication
  extend ActiveSupport::Concern

  class GoogleAuthError <RuntimeError; end
  class InvalidGoogleUsernameError <GoogleAuthError; end

  included do
    attr_accessor :google_auth_data

    # We choose the username:
    before_validation(on: :create) {|obj| obj.username = unique_username }

    validates :google_auth_data,
      presence: true,
      on:       :create
    validates :google_email_address,
      presence: true,
      email:    true,
      on:       :create
    validate :validate_email_address_unique, on: :create

    # Because we need an associated email object for the google_email_address
    # validates_associated :emails  ?

    def self.find_by_google_auth_data(auth_data)
      return nil unless auth_data && auth_data["email"]
      e = (Email.find_by(email: auth_data["email"]) or return nil)
      logger.info "Email found = #{e}"
      e.user.tap {|u| u.google_auth_data = auth_data }
    end

    def self.find_or_create_by_google_auth_data!(auth_data)
      # find_by_google_auth_data(auth_data) || create_by_google_auth_data(auth_data)
      find_by_google_auth_data(auth_data) or
        User.create!(google_auth_data: auth_data)
    end
  end

  #####
  # Instance methods

  # @return [Boolean] Is this a third-party login service?
  def third_party_login?
    true
  end

  # @return [String] The unique Google ID for the authenticated account
  def google_user_id
    google_auth_data.try(:fetch, "sub", nil)
  end

  # @return [String] The Google email for the authenticated account
  def google_email_address
    google_auth_data.try(:fetch, "email", nil)
  end

  # @return [String] Calculate a username that's not already in-use for a new
  #                  Google account / email-address
  def unique_username
    errors.add(:username, "google_auth_data is null") if google_auth_data.nil?
    [sanitised_google_username, sanitised_google_username_id].each do |a_username|
      logger.info "Searching for #{a_username.inspect}"
      return a_username unless User.where(username: a_username).exists?
    end
  end

  private

  # @return [String] The username part of the Google email, sanitised for Squash's use
  def sanitised_google_username
    sanitised_username(google_email_address)
  end

  # @return [String] The username part of the Google email, sanitised for Squash's use, combined with the Unique Google ID
  def sanitised_google_username_id
    [sanitised_username(google_email_address), google_user_id].join("-")
  end

  def sanitised_username(an_email_address)
    # Google also allows "." and "'" in a G.Apps email username
    # but Squash doesn't:
    m = an_email_address.match(/^(.+)@.+$/) or
      raise InvalidGoogleUsernameError, "Can't extract username from #{an_email_address.inspect}"
    m[1].gsub(/[\.\']/, "_")
  end

  def create_primary_email
    emails.create!(email: google_email_address, primary: true)
  end

  def validate_email_address_unique
    errors.add(:google_email_address, :taken) if Email.primary.where(email: google_email_address).exists?
  end
end
