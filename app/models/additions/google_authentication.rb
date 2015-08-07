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

  class InvalidGoogleAuthError <RuntimeError; end
  class InvalidGoogleUsernameError <InvalidGoogleAuthError; end

  included do
    attr_accessor :google_auth_data

    # We choose the username:
    before_validation(on: :create) {|obj| obj.username ||= unique_username.downcase }

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

    # @return [User] Searches the Users for an entry that matches appropriate Google Auth data
    # @return [nil] If it can't find a user that matches the provided Google Auth data
    #
    # In this case, we search for a matching email address
    def self.find_by_google_auth_data(auth_data)
      return nil unless auth_data && auth_data["email"]
      e = (Email.find_by(email: auth_data["email"]) or return nil)
      logger.info "Email found = #{e}"
      e.user.tap {|u| u.google_auth_data = auth_data }
    end

    # @return [User] Finds or Creates a User from Google Auth data
    # @raise [RecordInvalid] If it fails to create the User (this should never happen!)
    def self.find_or_create_by_google_auth_data(auth_data)
      find_by_google_auth_data(auth_data) or
        User.create(google_auth_data: auth_data)
    end
  end

  # @return [String] The unique Google ID for the authenticated account
  def google_user_id
    google_auth_data["sub"]
  end

  # @return [String] The Google email for the authenticated account
  def google_email_address
    google_auth_data["email"]
  end

  private

  # @return [String] Calculate a username that's not already in-use for a new Google account / email-address
  def unique_username
    raise InvalidGoogleAuthError, "google_auth_data is null" if google_auth_data.nil?

    [sanitised_google_username, sanitised_google_username_id].each do |a_username|
      logger.info "Searching for #{a_username.inspect}"
      return a_username unless User.where(username: a_username).exists?
    end
  end

  # @return [String] The username part of the Google email, sanitised for Squash's use
  def sanitised_google_username
    sanitised_username(google_email_address)
  end

  # @return [String] The username part of the Google email, sanitised for Squash's use, combined with the Unique Google ID
  def sanitised_google_username_id
    [sanitised_username(google_email_address), google_user_id].join("-")
  end

  # @return [String] A username extracted from a Google email-address, and then sanitised.
  #
  # In this context, "sanitised" means certain disallowed char's are replaced with "_" as Google also
  # allows `.` and `'` in a G.Apps email username but Squash doesn't.
  def sanitised_username(an_email_address)
    raise InvalidGoogleUsernameError, "Can't extract username from #{an_email_address.inspect}" if an_email_address.nil?
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
