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

# Adds password-based authentication to the {User} model. Mixed in if this
# Squash install is configured to use password-based authentication.
#
# All Users require a primary email. To facilitate this for password-based
# installs, a virtual attribute called "email_address" is added to the User
# model and exposed on the signup form. When the User is created, this attribute
# is used to create the primary email address.

module PasswordAuthentication
  extend ActiveSupport::Concern

  included do
    # @return [String] Virtual attribute containing the unencrypted password on
    #   signup.
    attr_accessor :password
    # @return [String] Virtual attribute containing the User's primary email
    #   address.
    attr_accessor :email_address

    attr_readonly :username

    has_metadata_column(
        crypted_password: {allow_nil: true},
        pepper:           {allow_nil: true}
    )

    before_validation :generate_pepper, on: :create
    before_validation :encrypt_password

    validates :password,
              presence:     true,
              confirmation: true,
              length:       {within: 6..100},
              exclusion:    {in: %w(123456 password welcome ninja abc123 123456789 princess sunshine 12345678 qwerty)},
              if: ->(obj) { obj.password.present? || obj.new_record? }
    validates :email_address,
              presence: true,
              email:    true,
              on:       :create
    validate :email_address_unique, on: :create
  end

  # Validates a password against this user. Not applicable for LDAP
  # authenticating installs.
  #
  # @param [String] password A proposed password.
  # @return [true, false] Whether it is the User's password.

  def authentic?(password)
    encrypt(password) == crypted_password
  end

  private

  def generate_pepper
    self.pepper = SecureRandom.base64
  end

  def encrypt_password
    self.crypted_password = encrypt(password) if password.present?
  end

  def encrypt(password)
    Digest::SHA2.hexdigest "#{Squash::Configuration.authentication.password.salt}#{password}#{pepper}"
  end

  def create_primary_email
    emails.create!(email: email_address, primary: true)
  end

  def email_address_unique
    errors.add(:email_address, :taken) if Email.primary.where(email: email_address).exists?
  end
end
