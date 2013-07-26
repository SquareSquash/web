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

atom_feed(root_url: project_environment_bug_url(@project, @environment, @bug, anchor: 'occurrences')) do |feed|
  feed.title "Occurrences of Bug ##{@bug.number} in #{@project.name} #{@environment.name}"
  feed.updated @occurrences.first.occurred_at if @occurrences.any?
  feed.author do |author|
    author.name @bug.blamed_commit.author.name
    author.email @bug.blamed_commit.author.email
  end if @bug.blamed_commit

  @occurrences.each do |occurrence|
    feed.entry(occurrence,
               published: occurrence.occurred_at,
               url:       project_environment_bug_occurrence_url(@project, @environment, @bug, occurrence),
               id:        "project:#{@project.slug},environment:#{@environment.name},bug:#{@bug.number},occurrence:#{occurrence.number}") do |entry|
      entry.title "#{occurrence.hostname}: #{OccurrencesController::INDEX_FIELDS[occurrence.client].map { |f| occurrence.send f }.join('/')}"
      #entry.summary occurrence.message
      entry.content(type: 'xhtml') do |html|
        html.p occurrence.message
        html.h2 "Backtrace"

        occurrence.backtraces.each do |bt|
          html.h3 "#{bt['name']}#{' (raised)' if bt['faulted']}"
          html.ul do
            bt['backtrace'].each { |line| html.li format_backtrace_element(*line) }
          end
        end
      end
    end
  end
end
