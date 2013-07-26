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
  module Projects
    # @private
    class Index < Views::Layouts::Application
      protected

      def tabbed?() true end

      def body_content
        full_width_section do
          h1 "Welcome, #{current_user.first_name}"
        end

        tabbed_section -> { tab_header }, -> { tab_content }
      end

      private

      def tab_header
        ul(class: 'tab-header') do
          li(class: 'active') { a "My Feed", href: '#feed', rel: 'tab' }
          li(class: 'with-table') { a "Watched Bugs", href: '#watched', rel: 'tab' }
          li(class: 'with-table') { a "Assigned Bugs", href: '#assigned', rel: 'tab' }
          li { a "All Projects", href: '#find', rel: 'tab' }
        end
      end

      def tab_content
        div(class: 'tab-content tab-primary') do
          div(class: 'active', id: 'feed') { my_feed }
          div(id: 'watched', class: 'with-table') { watched_bugs }
          div(id: 'assigned', class: 'with-table') { assigned_bugs }
          div(id: 'find') { find_project }
        end
      end

      def my_feed
        h3 "Recent Activity"
        ul id: 'events'
      end

      def watched_bugs
        table id: 'watched-bugs'
      end

      def assigned_bugs
        table id: 'assigned-bugs'
      end

      def find_project
        div(class: 'inset-content') do
          p do
            text "To change your project membership or leave a project, use the "
            link_to "My Account", account_url
            text " page."
          end

          form(class: 'whitewashed') do
            input type: 'search', id: 'find-project', placeholder: 'Find a project'
          end
          ul id: 'find-project-search-results', class: 'project-search-results'
        end
      end
    end
  end
end
