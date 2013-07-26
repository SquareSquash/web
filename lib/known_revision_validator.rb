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

# An EachValidator that verifies that a Git SHA1 revision exists within the
# object's parent repository. The `:repo` option must be one of the following:
#
# * a Git::Repository instance,
# * the symbol name of a method on the model that returns a Git::Repository
#   instance, or
# * a Proc that, when called with the model instance, returns a Git::Repository
#   instance.
#
# **Important note:** If the revision is unknown, the repository is fetched to
# ensure it wasn't recently added. This is a blocking network operation. It's
# recommended you only add this validation to objects that are not
# programatically created, or created in bulk.
#
# In the event that the revision is unknown, the `:unknown_revision` error key
# is added to the attribute.
#
# The repository is updated by calling `#fetch`. If you would like to customize
# this behavior, add a `:fetch` option whose value is a Proc that is given the
# Git::Repository instance. The Proc should update the repository.
#
# Extra awesome bonus: This validator will also normalize revisions as 40-digit
# SHA1s if validation succeeds. Sure, it's a side effect, but maybe it's good??
#
# @example
#   class MyModel < ActiveRecord::Base
#     belongs_to :project
#     validates :revision,
#               known_revision: {repo: ->(obj) { obj.project.repo }}

class KnownRevisionValidator < ActiveModel::EachValidator
  # @private
  def validate_each(record, attribute, value)
    repo = case options[:repo]
             when Symbol then record.send(options[:repo])
             when Proc then options[:repo].(record)
             else options[:repo]
           end

    unless repo.respond_to?(:object) && repo.respond_to?(:fetch)
      raise ArgumentError, "Expected instance of Git::Repository, got #{repo.class}"
    end

    commit = repo.object(value)
    if commit.nil?
      repo.fetch
      commit = repo.object(value)
    end

    if commit
      record.send :"#{attribute}=", commit.sha
    else
      record.errors.add(attribute, :unknown_revision) unless commit
    end
  end
end
