# Copyright 2014 Square Inc.
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

module Blamer

  # A write-through LRU cache of `git-blame` results, backed by the PostgreSQL
  # `blames` table by means of the {Blame} model.

  class Cache
    include Singleton

    # The maximum number of cached blame entries to store.
    MAX_ENTRIES = 500_000

    # Returns the cached result of a blame operation, or performs the blame on a
    # cache miss. `nil` blame results are never cached.
    #
    # @param [Project] project The project whose repository will be used for the
    #   blame operation.
    # @param [String] revision The SHA1 revision at which point to run the
    #   blame.
    # @param [String] file The file to run the blame on.
    # @param [Integer] line The line number in the file to run the blame at.
    # @return [String, nil] The SHA of the blamed revision, or `nil` if blame
    #   could not be determined for some reason.

    def blame(project, revision, file, line)
      cached_blame(project, revision, file, line) ||
          write_blame(project, revision, file, line, git_blame(project, revision, file, line))
    end

    private

    def cached_blame(project, revision, file, line)
      blame = Blame.for_project(project).where(revision: revision, file: file, line: line).first
      if blame
        blame.touch
        return project.repo.object(blame.blamed_revision)
      else
        return nil
      end
    end

    def git_blame(project, revision, file, line)
      rev = project.repo.blame(file,
                               revision:               revision,
                               detect_interfile_moves: true,
                               detect_intrafile_moves: true,
                               start:                  line,
                               end:                    line)[line]
      rev ? project.repo.object(rev) : nil
    rescue Git::GitExecuteError
      Rails.logger.tagged('Blamer') { Rails.logger.error "Couldn't git-blame #{project.slug}:#{revision}: #{$!}" }
      nil
    end

    def write_blame(project, revision, file, line, blamed_commit)
      if blamed_commit
        purge_entry_if_necessary
        Blame.for_project(project).
            where(revision: revision, file: file, line: line).
            create_or_update! do |blame|
          blame.blamed_revision = blamed_commit.sha
        end
      end
      return blamed_commit
    end

    def purge_entry_if_necessary
      Blame.transaction do
        if (count = Blame.count) >= MAX_ENTRIES
          query = Blame.select(:id).order('updated_at ASC').limit((count + 1) - MAX_ENTRIES).to_sql
          Blame.where("id = ANY(ARRAY(#{query}))").delete_all
        end
      end
    end
  end
end
