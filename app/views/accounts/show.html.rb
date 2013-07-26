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
  module Accounts
    # @private
    class Show < Views::Layouts::Application
      protected

      def page_title()
        "My Account"
      end

      def body_content
        full_width_section { user_info }
        tabbed_section -> { tab_header }, -> { tab_content }
      end

      def breadcrumbs()
        'Account'
      end

      private

      def tab_header
        ul(class: 'tab-header') do
          li(class: 'active') { a "Statistics", href: '#stats', rel: 'tab' }
          li { a "Projects", href: '#projects', rel: 'tab' }
          li { a "Emails", href: '#emails', rel: 'tab' }
          li { a "Settings", href: '#user', rel: 'tab' } if Squash::Configuration.authentication.strategy == 'password'
        end
      end

      def tab_content
        div(class: 'tab-content tab-primary') do
          div(class: 'active', id: 'stats') { stats }
          div(id: 'projects') { projects }
          div(id: 'emails') { emails }
          div(id: 'user') { user_form } if Squash::Configuration.authentication.strategy == 'password'
        end
      end

      def user_info
        h1 do
          image_tag current_user.gravatar
          text current_user.name
        end

        p(class: 'alert info') do
          strong "Note:"
          text " Your profile picture is being provided by "
          link_to "Gravatar", 'http://en.gravatar.com'
          text ". Visit that site to change this image."
        end
      end

      def stats
        dl do
          dt "Username"
          dd current_user.username
          dt "Main Email"
          dd current_user.email
          dt "Joined"
          dd l(current_user.created_at, format: :short_date)
          dt "Projects"
          dd number_with_delimiter(current_user.memberships.count)
          dt "Projects Owned"
          dd number_with_delimiter(current_user.owned_projects.count)
        end
      end

      def projects
        form(class: 'whitewashed') do
          input type: 'search', id: 'project-filter', placeholder: 'Find a project'
        end
        ul(id: 'project-results', class: 'project-search-results')
      end

      def emails
        form id: 'email-aliases', class: 'whitewashed'

        p <<-TEXT
          If you want to take responsibility for all exceptions caused by
          someone else’s commits, add his or her email address above. You’ll be
          emailed instead. If you only want to take responsibility for his/her
          exceptions in a specific project (say, s/he moved to another team
          team), visit that project’s page and edit your membership settings.
        TEXT
        p do
          text "You can also add any email addresses that you commit under other than "
          tt current_user.email
          text " to become responsible for commits under those email addresses."
        end
      end

      def user_form
        form_for(current_user, url: account_url(anchor: 'user'), html: {class: 'labeled whitewashed'}) do |f|
          fieldset do
            f.label :first_name, "your name"
            div(class: 'field-group') do
              f.text_field :first_name, placeholder: "first"
              text ' '
              f.text_field :last_name, placeholder: "last"
            end

            f.label :password
            f.password_field :password

            f.label :password_confirmation
            f.password_field :password_confirmation
          end

          div(class: 'form-actions') { f.submit class: 'default' }
        end
      end
    end
  end
end
