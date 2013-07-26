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

# Simple worker class that emails everyone on a {Bug}'s `notify_on_deploy` list
# of a new Deploy.

class DeployNotificationMailer
  include BackgroundRunner::Job

  # Creates a new instance and sends notification emails.
  #
  # @param [Fixnum] bug_id The ID of a Bug that a Deploy just fixed.

  def self.perform(bug_id)
    new(Bug.find(bug_id)).perform
  end

  # Creates a new worker instance.
  #
  # @param [Bug] bug A Bug that a Deploy just fixed.

  def initialize(bug)
    @bug = bug
  end

  # Emails all Users who enabled fix-deployed notifications.

  def perform
    User.where(id: @bug.notify_on_deploy).each do |user|
      NotificationMailer.deploy(@bug, user).deliver
    end
  end
end
