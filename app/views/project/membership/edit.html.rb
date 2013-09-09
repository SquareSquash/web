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
  module Project
    # @private
    module Membership
      # @private
      class Edit < Views::Layouts::Application
        needs :project, :membership

        protected

        def page_title() "My Membership in #{@project.name}" end

        def body_content
          full_width_section do
            div(class: 'row') do
              div(class: 'four columns') { h5 "Email notifications" }
              div(class: 'twelve columns') { email_settings }
            end
            div(class: 'row') do
              div(class: 'four columns') { h5 "Emails I’ve taken responsibility for" }
              div(class: 'twelve columns') { email_aliases }
            end
          end
        end

        def sidebar
          div(class: 'inset') do
            project_owner
            project_overview
            if current_user.role(@project) != :owner && !current_user.role(@project).nil?
              p { button_to "Leave Project", project_my_membership_url(@project), 'data-sqmethod' => 'DELETE', class: 'warning' }
            end
          end

          ul(class: 'nav-list') { sidebar_projects }
        end

        def breadcrumbs() [@project, 'Membership'] end

        private

        def project_owner
          h4 "Owner"
          div(class: 'profile-widget') do
            image_tag @project.owner.gravatar
            h5 { link_to @project.owner.name, user_url(@project.owner) }
            p { strong @project.owner.username }
            p "Project created on #{l @project.created_at, format: :short_date}."
          end
        end

        def project_overview
          h4 "Overview"
          dl do
            dt "Environments"
            dd number_with_delimiter(@project.environments.count)
            dt "Members"
            dd do
              text number_with_delimiter(@project.memberships.count)
              text " ("
              text pluralize_with_delimiter(@project.memberships.where(admin: true).count, 'administrator')
              text ")"
            end
          end
        end

        def email_settings
          form_for(@membership,
                   url:    {controller: 'project/membership', action: 'update', project_id: @project.to_param},
                   method: :patch,
                   html:   {class: 'labeled'}) do |f|

            fieldset do
              h5 "email me when…"
              f.label(:send_assignment_emails) do
                f.check_box :send_assignment_emails
                text "I am assigned to a bug"
              end

              f.label(:send_comment_emails) do
                f.check_box :send_comment_emails
                text "Someone comments on a bug"
              end
              p "You will only be notified for bugs you are assigned to or have commented on.", class: 'help-block'

              f.label(:send_resolution_emails) do
                f.check_box :send_resolution_emails
                text "Someone else resolves a bug I am assigned to"
              end

              div(class: 'form-actions') { f.submit class: 'default' }
            end
          end
        end

        def email_aliases
          div id: 'email-aliases'

          p do
            text <<-TEXT
              If you want to take responsibility for all exceptions caused by
              someone else’s commits to this project, add his or her email address
              above. You’ll be emailed instead. If you want to take responsibility
              for that person’s exceptions across all projects (say, s/he left the
              company), visit
            TEXT
            link_to "your account page", account_url
            text '.'
          end
        end
      end
    end
  end
end
