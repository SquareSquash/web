# encoding: utf-8

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

require Rails.root.join('app', 'views', 'layouts', 'application.html.rb')

module Views
  # @private
  module Sessions
    # @private
    class New < Views::Layouts::Application
      protected

      def page_title() "Log In" end
      def modal_view?() true end

      def body_content
        modal_section do
          title_section
          div(class: 'body-portion') do
            login_form
            if display_registration_form?
              signup_form
            end
          end
        end
      end

      private

      def title_section
          h1 "Log in to Squash"
          p "Use your LDAP credentials to log in." if Squash::Configuration.authentication.strategy == 'ldap'
      end

      def login_form
        div(class: 'row') do
          div(class: 'four columns') { text! '&nbsp;' }
          form(method: 'post', action: login_url, class: 'four columns whitewashed') do
            input type: 'hidden', name: request_forgery_protection_token, value: form_authenticity_token
            input type: 'hidden', name: 'next', value: params[:next]
            div { input type: 'text', name: 'username', placeholder: 'username' }
            div { input type: 'password', name: 'password', placeholder: 'password' }
            div { input type: 'submit', class: 'default', value: 'Log In' }
          end
          div(class: 'four columns') { text! '&nbsp;' }
        end
      end

      def signup_form
        div(class: 'row') do
          div(class: 'two columns') { text! '&nbsp;' }
          form_for(@user || User.new, url: signup_url, html: {class: 'eight columns whitewashed'}) do |f|
            h3 "Don’t have an account yet?"

            input type: 'hidden', name: 'next', value: params[:next]
            div { f.text_field :username, required: true, placeholder: 'username' }
            div { f.email_field :email_address, required: true, placeholder: 'email' }
            div(class: 'row') do
              div(class: 'remaining columns') { f.password_field :password, required: true, placeholder: 'password' }
              div(class: 'remaining columns') { f.password_field :password_confirmation, required: true, placeholder: 'again' }
            end
            div(class: 'row') do
              div(class: 'remaining columns') { f.text_field :first_name, placeholder: 'first', placeholder: 'first' }
              div(class: 'remaining columns') { f.text_field :last_name, placeholder: 'last', placeholder: 'last' }
            end
            div { f.submit class: 'default' }
          end
          div(class: 'two columns') { text! '&nbsp;' }
        end
      end

      def display_registration_form?
        Squash::Configuration.authentication.strategy == 'password' &&
          Squash::Configuration.authentication.registration_enabled?
      end
    end
  end
end
