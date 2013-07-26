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
  module Bugs
    # @private
    class Index < Views::Layouts::Application
      needs :project, :environment, :filter_users

      protected

      def page_title() "#{@project.name} #{@environment.name.capitalize} Bugs" end

      def body_content
        full_width_section { filter }
        table id: 'bugs'
        syntax_help_modal
      end

      def breadcrumbs() [@project, @environment] end

      def breadcrumbs_stats()
        return super unless @project.uses_releases?
        [
            [@environment.bugs_count,
             "unresolved, unassigned bug"],
            [@environment.bugs.where(fixed: false, irrelevant: false, any_occurrence_crashed: true).count,
             "bug with at least one occurrence that resulted in a crash",
             "bugs with at least one occurrence that resulted in a crash"],
            [Occurrence.joins(:bug).where(bugs: {fixed: false, irrelevant: false}, crashed: true).count,
             "crash associated with an unresolved bug",
             "crashes associated with an unresolved bug"],
            [DeviceBug.joins(:bug).where(bugs: {fixed: false, irrelevant: false, environment_id: @environment.id}).count,
             "device that crashed because of an unresolved bug",
             "devices that crashed because of an unresolved bug"]
        ]
      end

      private

      def filter
        form(id: 'filter') do
          p do
            text "Show me "

            select_tag 'filter[fixed]', options_for_select([%w(unresolved false), %w(resolved true)]), class: 'input-small'
            text " "
            select_tag 'filter[irrelevant]', options_for_select([%w(critical false), %w(irrelevant true)]), class: 'input-small'

            if @project.uses_releases?
              text " exceptions that "
              select_tag 'filter[any_occurrence_crashed]', options_for_select([['did or did not', nil], ['did', 'true'], ['did not', 'false']]), class: 'input-small'
              text " result in a crash, "
            else
              text " exceptions"
            end

            text "assigned to "
            options = {'Sets' => [%w(nobody nobody), %w(somebody somebody), ['all bugs', 'anybody']]}
            options['Individuals'] = @filter_users.map { |fu| [fu.username, fu.id] } unless @filter_users.empty?
            select_tag 'filter[assigned_user_id]',
                       grouped_options_for_select(options, 'nobody'),
                       class: 'input-small'

            if @environment.deploys.builds.any?
              text " that occurred in build "
              select_tag 'filter[deploy_id]',
                         options_for_select(@environment.deploys.builds.by_time.map do |d|
                           ["#{d.build} (#{d.version})", d.id]
                         end.unshift(['any', nil])), class: 'input-small'
            end
          end
          p do
            text "Search exception classes, exception messages, and comments: "
            text_field_tag 'filter[search]', '', class: 'input-medium', id: 'filter_search'
            span(class: 'aux') do
              text " (this field uses "
              a(href: '#syntax-help', rel: 'modal') do
                text "PostgreSQL "
                tt "tsquery"
                text " syntax"
              end
              text ")"
            end
          end
        end
      end

      def syntax_help_modal
        div(class: 'modal', id: 'syntax-help') do
          a "×", class: 'close'
          h1 "Search query syntax"

          div(class: 'modal-body') do
            p "Class names, messages, and comments are searched."

            pre "(windows | linux) & !osx & bsod"
            p "Find exceptions relating to “windows” or “linux” and “bsod” that don’t contain “osx”."

            pre "'microsoft windows'"
            p "Search for the phrase “microsoft windows”."

            pre "ArgumentError:A & my_method:B & 'fixed for now':C"
            p "Search for bugs with the class name “ArgumentError”, the word “my_method” in the message, and a comment containing “fixed for now”."

            pre "ArgumentError:AC"
            p "Search for bugs with the class name “ArgumentError” or with comments containing “ArgumentError”."

            pre "Invalid:*"
            p "Search for words starting with “Invalid”."

            pre "ActiveRecord:*A"
            p "Search for bugs with class names beginning with “ActiveRecord”."
          end
        end
      end
    end
  end
end
