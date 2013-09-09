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

# This observer on the {Bug} model...
#
# 1. creates the "open", "assign", "close", "deploy", and "reopen"
#    {Event Events} as necessary.
# 2. sends a notification and blame email when a Bug first occurs.

class BugObserver < ActiveRecord::Observer
  # @private
  def after_create(bug)
    create_open_event bug
  end

  # @private
  def after_commit_on_create(bug)
    send_create_emails bug.reload # load triggered changes
  end

  # @private
  def after_update(bug)
    create_assign_event bug
    create_close_event bug
    create_deploy_event bug
    create_reopen_event bug
    create_dupe_event bug
    watch_if_reassigned bug
  end

  # @private
  def after_commit_on_update(bug)
    send_update_emails bug
    notify_pagerduty bug
  end

  private

  def create_open_event(bug)
    Event.create! bug: bug, kind: 'open'
  end

  def create_assign_event(bug)
    if bug.assigned_user_id_changed?
      Event.create! bug: bug, kind: 'assign', user: (bug.modifier if bug.modifier.kind_of?(User)), data: {'assignee_id' => bug.assigned_user_id}
    end
  end

  def create_dupe_event(bug)
    if bug.duplicate_of_id_changed? && bug.duplicate_of_id
      Event.create! bug: bug, kind: 'dupe', user: (bug.modifier if bug.modifier.kind_of?(User))
    end
  end

  def create_close_event(bug)
    modifier_data = if bug.modifier.kind_of?(User)
                      {user: bug.modifier}
                    elsif defined?(JIRA::Resource::Issue) && bug.modifier.kind_of?(JIRA::Resource::Issue)
                      {data: {'issue' => bug.modifier.key}}
                    else
                      {}
                    end

    if bug.fixed? && !bug.fixed_was
      Event.create! modifier_data.deep_merge(bug: bug, kind: 'close', data: {'status' => 'fixed', 'revision' => bug.resolution_revision})
    elsif bug.irrelevant? && !bug.irrelevant_was && !bug.fixed?
      Event.create! modifier_data.deep_merge(bug: bug, kind: 'close', data: {'status' => 'irrelevant', 'revision' => bug.resolution_revision})
    end
  end

  def create_deploy_event(bug)
    if bug.fixed? && bug.fix_deployed? && !bug.fix_deployed_was
      Event.create! bug: bug, kind: 'deploy', data: {'revision' => bug.fixing_deploy.try!(:revision)}
    end
  end

  def create_reopen_event(bug)
    attrs = {bug: bug, kind: 'reopen', data: {}}
    attrs[:user] = bug.modifier if bug.modifier.kind_of?(User)
    attrs[:data]['occurrence_id'] = bug.modifier.id if bug.modifier.kind_of?(Occurrence)

    if !bug.fixed? && bug.fixed_was && !bug.irrelevant?
      attrs[:data]['from'] = 'fixed'
      Event.create! attrs
      Squash::Ruby.fail_silently do
        NotificationMailer.reopened(bug).deliver unless bug.modifier.kind_of?(User)
      end
    elsif !bug.fixed? && !bug.irrelevant? && bug.irrelevant_was
      attrs[:data]['from'] = 'irrelevant'
      Event.create! attrs
    end
  end

  def send_create_emails(bug)
    Squash::Ruby.fail_silently do
      NotificationMailer.initial(bug).deliver
      NotificationMailer.blame(bug).deliver if bug.blamed_commit
    end
  end

  def send_update_emails(bug)
    if bug.previous_changes['fix_deployed'] == [false, true]
      BackgroundRunner.run DeployNotificationMailer, bug.id
    end
  end

  def watch_if_reassigned(bug)
    if bug.assigned_user_id_changed? && bug.assigned_user
      bug.assigned_user.watches.where(bug_id: bug.id).find_or_create
    end
  end

  def notify_pagerduty(bug)
    return unless bug.environment.notifies_pagerduty?
    return unless bug.environment.project.pagerduty

    au  = bug.previous_changes['assigned_user_id'] || []
    ir  = bug.previous_changes['irrelevant'] || []
    res = bug.previous_changes['fixed'] || []
    if (!au.first && au.last) || (!ir.first && ir.last) || (!res.first && res.last)
      BackgroundRunner.run PagerDutyAcknowledger, bug.id
    end

    res = bug.previous_changes['fix_deployed'] || []
    if !res.first && res.last
      BackgroundRunner.run PagerDutyResolver, bug.id
    end
  end
end
