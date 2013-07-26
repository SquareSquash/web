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

# A comment made by a {User} on a {Bug}. Successive comments on the same bug are
# given incrementing `number` values, which are used instead of the less
# meaningful ID value when referencing comments.
#
# The `user` association can be `nil`. This is typically because the user who
# made the comment was since deleted.
#
# When comments are displayed, they are formatted using the Kramdown Markdown
# formatter. Twitter-style username references (e.g. "@riscfuture") are linked
# to the relevant user profile.
#
# Associations
# ============
#
# |        |                                  |
# |:-------|:---------------------------------|
# | `user` | The {User} who made the comment. |
# | `bug`  | The {Bug} that was commented on. |
#
# Properties
# ==========
#
# |          |                                                                           |
# |:---------|:--------------------------------------------------------------------------|
# | `number` | This comment's number in sequence among all the comments on the same bug. |
#
# Metadata
# ========
#
# |        |                                                |
# |:-------|:-----------------------------------------------|
# | `body` | The Markdown-formatted content of the comment. |

class Comment < ActiveRecord::Base
  belongs_to :user, inverse_of: :comments
  belongs_to :bug, inverse_of: :comments

  attr_accessible :body, as: [:creator, :owner, :admin]
  attr_readonly :user, :bug, :number

  include HasMetadataColumn
  has_metadata_column(
    body: {presence: true, length: {maximum: 2000}}
  )

  validates :bug,
            presence: true
  #validates :number,
  #          presence:     true,
  #          numericality: {only_integer: true, greater_than: 0},
                       #          uniqueness: {scope: :bug_id}
  validate :user_must_have_permission_to_comment

  after_create :reload # grab the number value after the rule has been run
  after_destroy :remove_events
  after_save { |comment| comment.bug.index_for_search! }

  # @private
  def to_param() number end

  # @private
  def as_json(options=nil)
    options ||= {}
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :user_id
    options[:except] << :bug_id

    options[:include] = Array.wrap(options[:include])
    options[:include] << :user

    super options
  end

  # @private
  def to_json(options={})
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :user_id
    options[:except] << :bug_id

    options[:include] = Array.wrap(options[:include])
    options[:include] << :user

    super options
  end

  private

  def user_must_have_permission_to_comment
    errors.add(:bug_id, :not_allowed) unless [:member, :admin, :owner].include? user.role(bug)
  end

  def remove_events
    bug.events.find_each { |event| event.destroy if event.kind == 'comment' && event.data['comment_id'] == id }
  end
end
