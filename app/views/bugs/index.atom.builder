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

atom_feed(root_url: project_environment_bugs_url(@project, @environment)) do |feed|
  feed.title "Bugs in #{@project.name}"
  feed.updated @bugs.first.first_occurrence if @bugs.any?

  @bugs.each do |bug|
    feed.entry(@bug,
               published: bug.first_occurrence,
               url:       project_environment_bug_url(@project, @environment, bug),
               id:        "project:#{@project.slug},environment:#{@environment.name},bug:#{bug.number}") do |entry|
      entry.title(
          if @bug.special_file?
            "#{bug.class_name} in #{bug.file}"
          else
            "#{bug.class_name} in #{bug.file}:#{bug.line}"
          end
      )
      #entry.summary bug.message_template
      entry.content(type: 'xhtml') do |html|
        html.p do
          html.strong "#{bug.class_name}: "
          html.span bug.message_template
        end
        html.p do
          if bug.special_file?
            html.span "#{bug.file}"
          else
            html.span "#{bug.file}, line #{bug.line}"
          end
          html.em "(revision #{bug.revision})"
        end
      end

      entry.author do |author|
        author.name bug.blamed_commit.author.name
        author.email bug.blamed_commit.author.email
      end if bug.blamed_commit
    end
  end
end
