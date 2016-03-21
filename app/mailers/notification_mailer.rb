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

# Sends notifications of {Bug} events, such as new Bugs and critical Bugs. See
# the `mailer.yml` Configoro file for mail-related configuration options.

class NotificationMailer < ActionMailer::Base
  helper :mail, :application

  default from: Squash::Configuration.mailer.from
  default_url_options.merge! Squash::Configuration.mailer.default_url_options.symbolize_keys

  # Creates a message addressed to the {Project}'s `all_mailing_list` informing
  # of a new Bug.
  #
  # @param [Bug] bug The Bug that was just added.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def initial(bug)
    @bug = bug

    recipient = bug.environment.project.all_mailing_list
    return nil unless should_send?(bug, recipient)

    mail to:      recipient,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.initial.subject',
                         locale:      bug.environment.project.locale,
                         class:       bug.class_name,
                         filename:    File.basename(bug.file),
                         project:     bug.environment.project.name,
                         environment: bug.environment.name)
  end

  # Creates a message addressed to the engineer at fault for a bug informing him
  # of the new Bug.
  #
  # @param [Bug] bug The Bug that was just added.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def blame(bug)
    @bug = bug

    emails = bug.blamed_email
    return nil unless should_send?(bug, emails)

    mail to:      emails,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.blame.subject',
                         locale:      bug.environment.project.locale,
                         class:       bug.class_name,
                         filename:    File.basename(bug.file),
                         project:     bug.environment.project.name,
                         environment: bug.environment.name)

    #TODO should be in an observer of some kind
    bug.events.create!(kind: 'email', data: {recipients: Array.wrap(emails)})
  end

  # Creates a message addressed to the assigned engineer (or the at-fault
  # engineer if no one is assigned) for a Bug informing him that the Bug has
  # been reopened.
  #
  # @param [Bug] bug The Bug that was reopened.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def reopened(bug)
    @bug = bug

    emails = bug.assigned_user.try!(:email) || bug.blamed_email
    return nil unless should_send?(bug, emails)

    mail to:      emails,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.reopened.subject',
                         locale:      bug.environment.project.locale,
                         class:       bug.class_name,
                         filename:    File.basename(bug.file),
                         project:     bug.environment.project.name,
                         environment: bug.environment.name)
  end

  # Creates a message addressed to the {Project}'s `critical_mailing_list`
  # informing of a Bug that has reached a critical number of
  # {Occurrence Occurrences}.
  #
  # @param [Bug] bug The Bug that has "gone critical."
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def critical(bug)
    @bug = bug

    recipient = bug.environment.project.critical_mailing_list
    return nil unless should_send?(bug, recipient)

    mail to:      recipient,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.critical.subject',
                         locale:      bug.environment.project.locale,
                         class:       bug.class_name,
                         filename:    File.basename(bug.file),
                         project:     bug.environment.project.name,
                         environment: bug.environment.name)

    #TODO should be in an observer of some kind
    bug.events.create!(kind: 'email', data: {recipients: [recipient]})
  end

  # Creates a message addressed to the Bug's assigned User, informing them that
  # the Bug has been assigned to them.
  #
  # @param [Bug] bug The Bug that was assigned.
  # @param [User] assigner The User that assigned the Bug.
  # @param [User] assignee The User to whom the Bug was assigned.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def assign(bug, assigner, assignee)
    @bug      = bug
    @assigner = assigner

    return nil unless should_send?(bug, assignee)
    return nil unless Membership.for(assignee, bug.environment.project_id).first.send_assignment_emails?

    mail to:      assignee.email,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.assign.subject',
                         locale:  bug.environment.project.locale,
                         number:  bug.number,
                         project: bug.environment.project.name)
  end

  # Creates a message addressed to the Bug's assigned User, informing them that
  # someone else has resolved or marked as irrelevant the Bug that they were
  # assigned to.
  #
  # @param [Bug] bug The Bug that was resolved or marked irrelevant.
  # @param [User] resolver The User that modified the Bug (who wasn't assigned
  #   to it).
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def resolved(bug, resolver)
    return nil unless should_send?(bug, bug.assigned_user)
    return nil unless Membership.for(bug.assigned_user_id, bug.environment.project_id).first.send_resolution_emails?

    @bug      = bug
    @resolver = resolver

    subject = if bug.fixed?
                I18n.t('mailers.notifier.resolved.subject.fixed',
                       locale:  bug.environment.project.locale,
                       number:  bug.number,
                       project: bug.environment.project.name)
              else
                I18n.t('mailers.notifier.resolved.subject.irrelevant',
                       locale:  bug.environment.project.locale,
                       number:  bug.number,
                       project: bug.environment.project.name)
              end

    mail to:      bug.assigned_user.email,
         from:    project_sender(bug),
         subject: subject
  end

  # Creates a message notifying a User of a new Comment on a Bug.
  #
  # @param [Comment] comment The Comment that was added.
  # @param [User] recipient The User to notify.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def comment(comment, recipient)
    return nil unless should_send?(comment.bug, recipient)
    return nil unless Membership.for(recipient, comment.bug.environment.project_id).first.send_comment_emails?

    @comment = comment
    @bug     = comment.bug

    mail to:      recipient.email,
         from:    project_sender(comment.bug),
         subject: t('mailers.notifier.comment.subject',
                    locale:  comment.bug.environment.project.locale,
                    number:  comment.bug.number,
                    project: comment.bug.environment.project.name)
  end

  # Creates a message notifying a User of a new Occurrence of a Bug.
  #
  # @param [Occurrence] occ The new Occurrence.
  # @param [User] recipient The User to notify.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def occurrence(occ, recipient)
    return nil unless should_send?(occ.bug, recipient)

    @occurrence = occ
    @bug        = occ.bug

    mail to:      recipient.email,
         from:    project_sender(occ.bug),
         subject: I18n.t('mailers.notifier.occurrence.subject',
                         locale:  occ.bug.environment.project.locale,
                         number:  occ.bug.number,
                         project: occ.bug.environment.project.name)
  end

  # Creates a message notifying a User that a NotificationThreshold they set has
  # been tripped.
  #
  # @param [Bug] bug The Bug being monitored.
  # @param [User] recipient The User to notify.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def threshold(bug, recipient)
    return nil unless should_send?(bug, recipient)

    @bug = bug

    mail to:      recipient.email,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.threshold.subject',
                         locale:  bug.environment.project.locale,
                         number:  bug.number,
                         project: bug.environment.project.name)
  end

  # Creates a message notifying a User that a Bug's resolution commit was
  # deployed.
  #
  # @param [Bug] bug The Bug whose fix was deployed.
  # @param [User] recipient The User to notify.
  # @return [Mail::Message, nil] The email to deliver, or `nil` if no email
  #   should be delivered.

  def deploy(bug, recipient)
    return nil unless should_send?(bug, recipient)

    @bug = bug

    mail to:      recipient.email,
         from:    project_sender(bug),
         subject: I18n.t('mailers.notifier.deploy.subject',
                         locale:  bug.environment.project.locale,
                         number:  bug.number,
                         project: bug.environment.project.name)
  end

  private

  def project_sender(bug)
    bug.environment.project.sender || self.class.default[:from]
  end

  def should_send?(bug, recipient)
    return false if recipient.blank?
    return false if !bug.environment.sends_emails?
    return true
  end
end
