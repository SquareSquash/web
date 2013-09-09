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

# Events mark important changes in a {Bug}. They are displayed in a
# newsfeed-style list when viewing a bug. Events consist of a `kind` and a
# freeform, JSON-serialized `data` field. The value of `kind` indicates what
# keys to expect in `data`. `data` can consist of cached values from associated
# objects (such as a {User}'s username), or the IDs of associated records (such
# as a {Comment}).
#
# Associations
# ============
#
# |               |                                                                              |
# |:--------------|:-----------------------------------------------------------------------------|
# | `bug`         | The {Bug} this event relates to.                                             |
# | `user`        | The {User} that caused this event to occur (where relevant).                 |
# | `user_events` | The denormalized {UserEvent UserEvents} for Users watching this Event's Bug. |
#
# There may be other pseudo-associations on specific types of events, where the
# foreign key field is stored in `data`.
#
# Properties
# ==========
#
# |        |                                              |
# |:-------|:---------------------------------------------|
# | `kind` | The type of event that occurred.             |
# | `data` | Freeform, JSON-encoded data about the event. |

class Event < ActiveRecord::Base
  belongs_to :bug, inverse_of: :events
  belongs_to :user, inverse_of: :events
  has_many :user_events, dependent: :delete_all, inverse_of: :event

  attr_readonly :bug, :user, :kind, :data

  include JsonSerialize
  json_serialize data: {}

  validates :bug,
            presence: true

  # @private
  def as_json(options=nil)
    case kind
      when 'open'
        {kind: kind.to_s, created_at: created_at}
      when 'comment'
        {kind: kind.to_s, comment: comment.as_json, user: user.as_json, created_at: created_at}
      when 'assign'
        {kind: kind.to_s, assigner: user.as_json, assignee: assignee.as_json, created_at: created_at}
      when 'close'
        {kind: kind.to_s, user: user.as_json, status: data['status'], revision: data['revision'], created_at: created_at, issue: data['issue']}
      when 'dupe'
        {kind: kind.to_s, user: user.as_json, original: bug.duplicate_of.as_json, created_at: created_at}
      when 'reopen'
        {kind: kind.to_s, user: user.as_json, occurrence: occurrence.as_json, from: data['from'], created_at: created_at}
      when 'deploy'
        {kind: kind.to_s, revision: data['revision'], build: data['build'], created_at: created_at}
      when 'email'
        {kind: kind.to_s, recipients: data['recipients'], created_at: created_at}
      else
        raise "Unknown event kind #{kind.inspect}"
    end
  end

  # Eager-loads the pseudo-associations of a group of events. The
  # pseudo-associations are `comment`, `occurrence`, and `assignee`.
  #
  # @param [Array<Event>] events The events to preload associations for.
  # @return [Array<Event>] The events.

  def self.preload(events)
    comments = Comment.where(id: events.map { |e| e.data['comment_id'] }.compact )
    comments.each do |comment|
      events.select { |e| e.data['comment_id'] == comment.id }.each { |e| e.instance_variable_set :@comment, [comment] }
    end
    events.select { |e| e.data['comment_id'].nil? }.each { |e| e.instance_variable_set :@comment, [nil] }

    occurrences = Occurrence.where(id: events.map { |e| e.data['occurrence_id'] }.compact)
    occurrences.each do |occurrence|
      events.select { |e| e.data['occurrence_id'] == occurrence.id }.each { |e| e.instance_variable_set :@occurrence, [occurrence] }
    end
    events.select { |e| e.data['occurrence_id'].nil? }.each { |e| e.instance_variable_set :@occurrence, [nil] }

    assignees = User.where(id: (events.map { |e| e.data['assignee_id'] } + events.map { |e| e.comment.try!(:user_id)}).uniq.compact).includes(:emails)
    assignees.each do |user|
      events.select { |e| e.data['assignee_id'] == user.id }.each { |e| e.instance_variable_set :@assignee, [user] }
    end
    events.select { |e| e.data['assignee_id'].nil? }.each { |e| e.instance_variable_set :@assignee, [nil] }

    return events
  end

  # @return [Comment, nil] The associated comment for `:comment` events, `nil`
  #   otherwise.
  def comment() (@comment ||= [bug.comments.find_by_id(data['comment_id'])]).first end
  # @return [Occurrence, nil] The occurrence that reopened a bug for `:reopen`
  #   events, `nil` otherwise.
  def occurrence() (@occurrence ||= [bug.occurrences.find_by_id(data['occurrence_id'])]).first end
  # @return [User, nil] The assignee for `:assign` events, `nil` otherwise.
  def assignee() (@assignee ||= [User.find_by_id(data['assignee_id'])]).first end
end
