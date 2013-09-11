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
  module Bugs
    # @private
    class Show < Views::Layouts::Application
      include Accordion

      needs :project, :environment, :bug, :aggregation_dimensions,
            :new_issue_url

      protected

      def page_title() "Bug ##{number_with_delimiter @bug.number} (#{@project.name} #{@environment.name.capitalize})" end

      def body_content
        full_width_section do
          bug_title
          notice_bars
          bug_info
        end

        tabbed_section -> { tab_header }, -> { tab_content }
      end

      def breadcrumbs() [@project, @environment, @bug] end

      private

      def bug_title
        h1 do
          text @bug.class_name
          a id: 'watch', href: '#', class: "icon-star#{'-empty' unless current_user.watches?(@bug)}", alt: "Watch/unwatch this bug"
        end
      end

      def notice_bars
        fixed_bar if @bug.fixed?
        duplicate_bar if @bug.duplicate?
        uneditable_bar unless current_user.role(@bug)
      end

      def fixed_bar
        div(class: 'alert success') do
          text "This bug has been marked as resolved."
          if @bug.resolution_revision
            text " ("
            text! commit_link(@project, @bug.resolution_revision)
            text ")"
          end
          text " The fix has been deployed." if @bug.fix_deployed?
        end
      end

      def duplicate_bar
        div(class: 'alert warning') do
          text "This bug is a duplicate of "
          link_to "##{number_with_delimiter @bug.duplicate_of.number}", project_environment_bug_url(@project, @environment, @bug.duplicate_of)
          text "."
        end
      end

      def uneditable_bar
        p(class: 'alert info') do
          text "You will need to "
          a "join this project", href: join_project_my_membership_url(@project), :'data-sqmethod' => 'POST', id: 'join-link'
          text " to edit this bug. "
        end
      end

      def bug_info
        h5 "Message"
        pre @bug.message_template, class: 'scrollable'

        h5 "Location"
        bug_location

        if @bug.special_file?
          case @bug.file #TODO don't guess, record this information
            when /^0x/
              p "This bug has not been symbolicated. If you would like meaningful backtraces, please upload a symbolication file using your language’s client library.", class: 'alert info'
            when /^https?:\/\//
              p "No JavaScript source map was found for this bug. If you would like meaningful backtraces, please upload a source map using the Squash JavaScript client library.", class: 'alert info'
            when /\.java$/
              p "No Java renamelog was found for this bug. If you would like more meaningful backtraces, please upload a renamelog.xml file using the Squash Java deobfuscator.", class: 'alert info'
            else
              p "The backtraces for this bug cannot be displayed because they are in an unknown format.", class: 'alert error'
          end
        end
      end

      def bug_location
        p(id: 'location') do
          if @bug.special_file?
            case @bug.file # TODO don't guess, record this information
              when /^\[S\] / then text("<simple blamer> ")
              else text("#{@bug.file} ")
            end
          else
            text "#{@bug.file}, line #{number_with_delimiter @bug.line} "
          end
          span(class: 'aux') do
            text "(revision "
            text! commit_link(@project, @bug.revision)
            text ")"
          end
        end

        unless @bug.library_file?
          p(id: 'editor-links') do
            text! editor_link 'textmate', @project, @bug.file, @bug.line; br
            text! editor_link 'sublime', @project, @bug.file, @bug.line; br
            text! editor_link 'vim', @project, @bug.file, @bug.line; br
            text! editor_link 'emacs', @project, @bug.file, @bug.line
          end
          pre class: 'context', :'data-project' => @project.to_param, :'data-revision' => @bug.revision, :'data-file' => @bug.file, :'data-line' => @bug.line
        end
      end

      def tab_header
        ul(class: 'tab-header') do
          li(class: 'active') { a "History", href: '#history', rel: 'tab' }
          li { a "Git Blame", href: '#blame', rel: 'tab' } if @bug.blamed_revision
          li { a "The Fix", href: '#fix', rel: 'tab' } if @bug.resolution_revision
          li { a "Management", href: '#management', rel: 'tab' } if current_user.role(@project)
          li { a "Notifications", href: '#notifications', rel: 'tab' }
          li do
            a(href: '#comments', rel: 'tab') do
              text  "Comments"
              text " (#{number_with_delimiter @bug.comments_count})" if @bug.comments_count > 0
            end
          end
          li { a "Aggregation", href: '#aggregation', rel: 'tab' }
          li(class: 'with-table') do
            a(href: '#occurrences', rel: 'tab') do
              text "Occurrences"
              text " (#{number_with_delimiter @bug.occurrences_count})" if @bug.occurrences_count > 0
            end
          end
        end
      end

      def tab_content
        div(class: 'tab-content tab-primary') do
          div(class: 'active', id: 'history') { history_tab }
          div(id: 'blame') { blame_tab } if @bug.blamed_revision
          div(id: 'fix') { fix_tab } if @bug.resolution_revision
          div(id: 'management') { management_tab } if current_user.role(@project)
          div(id: 'notifications') { notifications_tab }
          div(id: 'comments') { comments_tab }
          div(id: 'aggregation') { aggregation_tab }
          div(class: 'with-table', id: 'occurrences') { occurrences_tab }
        end
      end

      def history_tab
        dl do
          dt "First occurrence"
          dd { time id: 'first-occurrence', datetime: @bug.first_occurrence.xmlschema }
          dt "Latest occurrence"
          dd { time id: 'latest-occurrence', datetime: @bug.latest_occurrence.xmlschema }
        end

        h4 "Occurrence Histogram"
        div id: 'histogram'

        h4 "Recent Events"
        ul id: 'events'
      end

      def blame_tab
        if @bug.blamed_commit
          victims = @bug.blamed_users
          p do
            text "According to the VCS blame function, fault seems to lie with "
            text! victims.map { |v| capture { mail_to v.email, (v.user.try!(:name) || v.email) } }.to_sentence
            text ".*"
          end if victims.any?

          commit_summary @bug.blamed_commit

          p("*The mailto link is not provided for purposes of sending hate mail.", class: 'small') if victims.any?

          diff 'blame', @bug.blamed_commit
        else
          p do
            text "According to the VCS blame function, commit "
            text! commit_link(@project, @bug.blamed_revision)
            text " seems to be at fault. This revision does not appear in the Git repository. (You might be able to fix this by refreshing the page.)"
          end
        end
      end

      def fix_tab
        if !@bug.fixed?
          div "This bug was automatically reopened. Perhaps the fix below didn’t work?", class: 'alert important'
        end
        if @bug.resolution_commit
          commit_summary @bug.resolution_commit
          diff 'fix', @bug.resolution_commit
        else
          p do
            text "This bug was fixed by commit "
            text! commit_link(@project, @bug.resolution_revision)
            text ". This revision does not appear in the Git repository. (You might be able to fix this by refreshing the page.)"
          end
        end
      end

      def management_tab
        p { em "How are things going with this bug?" }
        form_for [@project, @environment, @bug], format: 'json', html: {class: 'labeled whitewashed', id: 'management-form'} do |f|
          fieldset do
            h5 "We’re working on it."

            f.label :assigned_user_id
            f.select :assigned_user_id, @project.members.order('username ASC').map { |u| ["#{u.username} (#{u.name})", u.id] }, include_blank: true

            div do
              f.label :jira_issue
              div(class: 'field-group') do
                span(class: 'input-append') do
                  f.text_field :jira_issue, placeholder: "PROJECT-123", size: 14
                  span " ", class: 'add-on', id: 'jira-status'
                end
                label " or create new JIRA issue in ", for: 'jira-projects'
                select id: 'jira-projects', name: 'jira-projects', disabled: 'disabled'
              end
              p class: 'help-block', id: 'jira-name'


              f.label :jira_status_id, "mark this bug as fixed once the issue is"
              f.select :jira_status_id, [["Loading…", nil]], disabled: true
              p "With this option, you can automatically close one or more bugs when a JIRA issue is resolved.", class: 'help-block'
            end unless Squash::Configuration.jira.disabled?
          end

          fieldset do
            h5 "We fixed it."

            f.label(:fixed) do
              f.check_box :fixed
              text "This bug has been fixed", class: 'checkbox-label'
            end

            f.label :resolution_revision
            f.text_field :resolution_revision, maxlength: 40

            f.label(:fix_deployed) do
              f.check_box :fix_deployed
              text "The fix for this bug has been deployed", class: 'checkbox-label'
            end
          end

          fieldset do
            h5 "It’s not really a bug; no one’s going to fix it."

            f.label(:irrelevant) do
              f.check_box :irrelevant
              text "Keep this bug, but don’t notify anyone about it", class: 'checkbox-label'
            end

            p "… or …"

            button "Delete this bug",
                   href:            project_environment_bug_url(@project, @environment, @bug),
                   'data-sqmethod'  => 'DELETE',
                   class:           'warning',
                   'data-sqconfirm' => "Are you sure you want to delete this bug and all its occurrences?"
            p(class: 'help-block') do
              text "This will remove all occurrences, comments, etc. Use for (e.g.) sensitive data or false notifications."
              text " All bugs marked as duplicate of this bug will be deleted as well." if @bug.duplicate?
            end
          end

          fieldset do
            h5 "It’s a duplicate of another bug."

            f.label :duplicate_of_number
            div(class: 'input-prepend') do
              span '#', class: 'add-on'
              f.number_field :duplicate_of_number, disabled: @bug.duplicate?, class: 'input-small'
            end
            unless @bug.duplicate?
              p "Make sure you enter the number correctly! This cannot be undone. All occurrences of this bug (past, present, and future) will be moved over to the bug you specify here.", class: 'help-block'
            end
          end

          fieldset do
            h5 "… and I’d like to add a comment."

            div(class: 'comment') do
              h6(class: 'comment-author') do
                image_tag current_user.gravatar
                link_to current_user.name, account_url
              end
              image_tag 'comment-arrow.png'
              div(class: 'comment-body') do
                fields_for @bug.comments.build do |nc|
                  nc.text_area :body, rows: 4, cols: '', id: nil
                end
              end
            end
          end

          div(class: 'form-actions') { f.submit class: 'default' }
        end
      end

      def notifications_tab
        form(class: 'labeled whitewashed') do
          label do
            input type: 'checkbox', checked: @bug.notify_on_occurrence.include?(current_user.id), name: 'bug[notify_on_occurrence]', id: 'notify_on_occurrence'
            text "Email me whenever a new occurrence of this bug is recorded"
          end

          label do
            input type: 'checkbox', checked: @bug.notify_on_deploy.include?(current_user.id), name: 'bug[notify_on_deploy]', id: 'notify_on_deploy'
            text "Email me when the fix for this bug is deployed"
          end
        end

        nt = current_user.notification_thresholds.find_by_bug_id(@bug.id) || NotificationThreshold.new
        form_for(nt, url: project_environment_bug_notification_threshold_url(@project, @environment, @bug, format: 'json'), html: {class: 'labeled whitewashed', id: 'notification-form'}) do |f|
          fieldset do
            h5 "Notify me when this bug occurs a lot"

            f.label :threshold, "this many exceptions occur"
            f.number_field :threshold, class: 'input-small'

            f.label :period, "in this period of time"
            div(class: 'field-group') do
              f.number_field :period, class: 'input-small'
              text " seconds"
            end

            div(class: 'form-actions') do
              f.submit class: 'default'
              button_to 'Remove', project_environment_bug_notification_threshold_url(@project, @environment, @bug), :'data-sqmethod' => 'DELETE'
            end
          end
        end
      end

      def comments_tab
        div(class: 'comment') do
          h5(class: 'comment-author') do
            image_tag current_user.gravatar
            link_to current_user.name, account_url
          end
          image_tag 'comment-arrow.png'
          div(class: 'comment-body') do
            form_for [@project, @environment, @bug, @bug.comments.build] do |f|
              f.text_area :body, rows: 4, cols: ''
              p { f.submit class: 'default' }
            end
          end
        end

        div(id: 'comments-list')
      end

      def aggregation_tab
        div(class: 'inset-content') do
          aggregation_options
          div id: 'aggregation-charts'
        end
      end

      def occurrences_tab
        table id: 'occurrences-table'
      end

      def commit_summary(commit)
        pre <<-COMMIT, class: 'brush: git; light: true'
commit #{commit.sha}
Author: #{commit.author.name} <#{commit.author.email}>
Date:   #{l commit.author.date, format: :git}

        #{word_wrap commit.message}
        COMMIT
      end

      def diff(id, commit)
        return unless commit.parents.size == 1
        diffs = @project.repo.diff(commit.parent, commit)
        return if diffs.size > 30 || diffs.size == 0

        details(class: 'diff') do
          summary "Diff"
          accordion('diffs') do |acc|
            diffs.each_with_index do |diff, index|
              render_diff diff, id, index, acc
            end
          end
        end
      end

      def render_diff(diff, id, index, acc)
        deletions = diff.patch.split("\n").select { |l| l.start_with?('-') }.size - 1
        additions = diff.patch.split("\n").select { |l| l.start_with?('+') }.size - 1

        icon = if diff.type == 'new' then 'plus-sign'
               elsif diff.type == 'deleted' then 'minus-sign'
               elsif diff.type == 'renamed' then 'share-alt'
               else 'edit' end
        title = <<-HTML.html_safe
          <i class="icon-#{icon}"></i>
          <strong>#{diff.path}</strong>
          <code class=short>#{diff.type}</code>
          <span class="additions-deletions">
        HTML
        title << <<-HTML.html_safe if additions > 0
          <span class="additions">+#{number_with_delimiter additions}</span>
        HTML
        title << <<-HTML.html_safe if deletions > 0
          <span class="deletions">-#{number_with_delimiter deletions}</span>
        HTML
        title << <<-HTML.html_safe
          </span>
        HTML

        acc.accordion_item("#{id}-diff-#{index}", title, diff.path == @bug.file) do
          if diff.binary?
            p "(binary)"
          else
            pre diff.patch.encode('UTF-8'), class: 'brush: diff, light: true'
          end
        end
      end

      def aggregation_options
        form(id: 'aggregation-filter') do
          p "Select up to four dimensions to analyze:"
          div(id: 'aggregation-options') do
            4.times do
              div { select_tag "dimensions[]", options_for_select(@aggregation_dimensions), id: nil }
            end
            div(id: 'agg-submit') { submit_tag "Go", class: 'default small' }
          end
        end
      end
    end
  end
end
