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

# Simple worker class that emails all relevant Users, informing them of a new
# {Comment} on a {Bug}.

class CommentNotificationMailer
  include BackgroundRunner::Job

  # Creates a new instance and sends notification emails.
  #
  # @param [Fixnum] comment_id The ID of a Comment that was just posted.

  def self.perform(comment_id)
    new(Comment.find(comment_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [Comment] comment A Comment that was just posted.

  def initialize(comment)
    @comment = comment
  end

  # Emails all relevant Users about the new Comment.

  def perform
    recipients = @comment.bug.comments.select('user_id').uniq.pluck(:user_id)
    recipients << @comment.bug.assigned_user_id
    recipients.delete @comment.user_id
    recipients.uniq!

    User.where(id: recipients).each { |user| NotificationMailer.comment(@comment, user).deliver }
  end
end
