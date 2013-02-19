# Copyright 2012 Square Inc.
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

# This observer on the {Comment} class creates the "comment" {Event} (on {Bug})
# as necessary.

class CommentObserver < ActiveRecord::Observer
  # @private
  def after_create(comment)
    create_event comment
    watch_bug comment
  end

  # @private
  def after_commit_on_create(comment)
    if Squash::Application.config.resque
      Resque.enqueue(CommentNotificationMailer, comment.id)
    else
      Multithread.spinoff("CommentNotificationMailer:#{comment.id}", 80) { CommentNotificationMailer.perform(comment.id) }
    end
    # force reload the comment in order to load triggered changes
  end

  private

  def create_event(comment)
    Event.create! bug_id: comment.bug_id, kind: 'comment', data: {'comment_id' => comment.id}, user_id: comment.user_id
  end

  def watch_bug(comment)
    comment.user.watches.where(bug_id: comment.bug_id).find_or_create
  end
end
