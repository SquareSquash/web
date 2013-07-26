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
  module Projects
    # @private
    class Show < Views::Layouts::Application
      needs :project

      protected

      def page_title() @project.name end
      def breadcrumbs() [@project] end

      def body_content
        full_width_section { environments_grid }
        full_width_section(true) { project_info }
      end

      private

      def project_info
        div(class: 'row') do
          div(class: 'four columns') do
            project_owner
            project_overview
          end

          div(class: 'twelve columns') do
            h5 "Members"
            div id: 'members'

            if current_user.role(@project) == :owner
              delete_project
            elsif !current_user.role(@project).nil?
              p { button_to "Leave Project", project_my_membership_url(@project), :'data-sqmethod' => 'DELETE', class: 'warning' }
            end
          end
        end
      end

      def project_owner
        h5 "Owner"
        div(class: 'profile-widget') do
          image_tag @project.owner.gravatar
          h5 { link_to @project.owner.name, user_url(@project.owner) }
          div { strong @project.owner.username }
          div "Created #{l @project.created_at, format: :short_date}", class: 'small'
          div style: 'clear: left'
        end
      end

      def project_overview
        h5 "Overview"
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

        h5 "Settings"
        p { link_to "Configure and install Squash", edit_project_url(@project) } if action_name == 'show'
        if current_user.role(@project)
          p { link_to "Change membership settings", edit_project_my_membership_url(@project) }
        else
          p { button_to "Join this team", join_project_my_membership_url(@project), :'data-sqmethod' => 'POST' }
        end
      end

      def delete_project
        h5 "Delete"
        p do
          strong "Beware!"
          text " Deleting this project will delete all environments, all bugs, all occurrences, all comments, and all other data."
        end
        p do
          button_to "Delete",
                    project_url(@project),
                    :'data-sqmethod'  => :delete,
                    :'data-sqconfirm' => "Are you SURE you want to delete the project #{@project.name}?",
                    class:            'warning'
        end
      end

      def environments_grid
        if @project.environments.empty?
          p "No bugs have been received yet.", class: 'no-results'
          p(id: 'install-squash') do
            link_to "Install Squash into your project", edit_project_url(@project)
            text " to get started."
          end
          return
        end

        @project.environments.order('name ASC').limit(20).in_groups_of(2, nil) do |environments|
          div(class: 'row') do
            environments.each_with_index do |environment, idx|
              div(class: 'six columns') do
                div(class: (environment ? 'environment' : nil)) do
                  if environment
                    h3 { link_to environment.name, project_environment_bugs_url(@project, environment) }
                    p(class: 'info') do
                      text pluralize_with_delimiter(environment.bugs_count, 'bug')
                      if [:admin, :owner].include?(current_user.role(@project))
                        text " — "
                        span do
                          if @project.default_environment_id == environment.id
                            strong "Default", id: 'default-indicator', :'data-id' => environment.id
                          else
                            a "Make default", href: '#', class: 'make-default', :'data-id' => environment.id
                          end
                        end
                      end
                    end
                    form_for([@project, environment], format: 'json', namespace: "env_#{environment.name}") do |f|
                      p do
                        f.check_box :sends_emails
                        text ' '
                        f.label :sends_emails
                        unless Squash::Configuration.pagerduty.disabled
                          text ' '
                          f.check_box :notifies_pagerduty
                          text ' '
                          f.label :notifies_pagerduty
                        end
                      end
                    end if [:admin, :owner].include?(current_user.role(@project))
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
