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

root = exports ? this

# Loads and renders a Bug's Event feed. Events are rendered into a UL element
# with LI elements for each event. Styling is done in events.css.scss.
#
class root.Feed

  # Creates a new Feed manager. Calls {#load}.
  #
  # @param [String] url The Ajax endpoint to load feed items from.
  # @param [jQuery element array] element The jQuery element to render the feed
  #   into.
  # @param [Object] options Additional options.
  # @option options [Boolean] bugHeader If `true`, renders a header above each
  #   Event indicating which Bug it applies to.
  #
  constructor: (@url, @element, @options) ->
    @options ||= {}
    this.load()

  # Loads Events and renders them into the element. If an error occurs, creates
  # and displays a flash message.
  #
  load: ->
    @element.empty()
    $.ajax @url,
      type: 'GET'
      success: (events) =>
        if events.length == 0
          p = $('<p/>').addClass('no-results').text(" bugs to populate your feed.").appendTo(@element)
          $('<i/>').addClass('icon-star').prependTo p
          return

        last_bug_url = null
        last_group_ul = @element
        for event in events
          do (event) =>
            if @options.bugHeader && last_bug_url != event.bug.url
              parent_li = $('<li/>').addClass('event-group').appendTo(@element)
              h6 = $('<h5/>').text(" #{event.bug.class_name} in #{formatBugFile event.bug}").appendTo(parent_li)
              a = $('<a/>').text("#{event.project.name} (#{event.environment.name}) ##{event.bug.number}: ").attr('href', event.bug.url).prependTo(h6)
              last_group_ul = $('<ul/>').appendTo(parent_li)
            last_bug_url = event.bug.url if @options.bugHeader

            li = $('<li/>').addClass('event').appendTo(last_group_ul)
            $('<i/>').addClass("icon-#{event.icon}").appendTo li
            p = $('<div/>').addClass('event-content').appendTo(li)
            if event.kind == 'open'
              this.renderOpenEvent event, p
            else if event.kind == 'comment'
              this.renderCommentEvent event, p
            else if event.kind == 'assign'
              this.renderAssignEvent event, p
            else if event.kind == 'close'
              this.renderCloseEvent event, p
            else if event.kind == 'reopen'
              this.renderReopenEvent event, p
            else if event.kind == 'deploy'
              this.renderDeployEvent event, p
            else if event.kind == 'email'
              this.renderEmailEvent event, p
            else if event.kind == 'dupe'
              this.renderDupeEvent event, p
            $('<time/>').attr('datetime', event.created_at).appendTo(li).liveUpdate()
      error: => new Flash('alert').text("Couldn’t load the event timeline.")

  # @private
  renderOpenEvent: (event, p) ->
    p.append "This bug first occurred."

  # @private
  renderCommentEvent: (event, p) ->
    if event.user
      $('<a/>').text(if event.user_you then "You" else event.user.name).attr('href', event.user_url).appendTo p
    else
      p.append "Someone"
    p.append " commented on this bug:"
    if event.comment then $('<blockquote/>').html(event.comment_body).appendTo(p)

  # @private
  renderAssignEvent: (event, p) ->
    if event.assigner? && event.assignee? # someone assigned this bug to someone
      $('<a/>').text(if event.user_you then "You" else event.assigner.name).attr('href', event.user_url).appendTo p
      p.append " assigned this bug to "
      if event.user_you && event.assignee_you
        p.append "yourself"
      else if event.assignee_you
        p.append "you"
      else if event.assigner.username == event.assignee.username
        p.append "him/herself"
      else
        $('<a/>').text(event.assignee.name).attr('href', event.assignee_url).appendTo p
    else if event.assigner? # someone unassigned this bug
      $('<a/>').text(if event.user_you then "You" else event.assigner.name).attr('href', event.user_url).appendTo p
      p.append " unassigned this bug"
    else if event.assignee? # unknown person assigned this bug
      p.append "Someone assigned this bug to "
      $('<a/>').text(if event.user_you then "you" else event.assigner.name).attr('href', event.user_url).appendTo p
    else # unknown person unassigned this bug
      p.append "Someone unassigned this bug"
    p.append "."

  # @private
  renderCloseEvent: (event, p) ->
    if event.revision
      span = $('<span/>').addClass('aux').text " ("
      if event.revision_url
        $('<a/>').attr('href', event.revision_url).text(event.revision.slice(0, 6)).appendTo span
      else
        span.append event.revision.slice(0, 6)
      span.append ")"
    if event.issue
      p.append "This bug was automatically marked as fixed by "
      $('<a/>').text(event.issue).attr('href', url).appendTo p
      if span then span.appendTo(p)
      p.append "."
    else if event.user
      $('<a/>').text(if event.user_you then "You" else event.user.name).attr('href', event.user_url).appendTo p
      if event.status == 'irrelevant'
        p.append " marked this bug as irrelevant"
      else
        p.append " fixed this bug"
        if span then span.appendTo(p)
      p.append "."
    else
      if event.status == 'irrelevant'
        p.append "This bug was marked as irrelevant."
      else
        p.append "This bug was marked as fixed"
        if span then span.appendTo(p)
        p.append "."

  # @private
  renderReopenEvent: (event, p) ->
    if event.user
      $('<a/>').text(if event.user_you then "You" else event.user.name).attr('href', event.user_url).appendTo p
      if event.from == 'irrelevant'
        p.append " marked this bug as relevant."
      else
        p.append " reopened this bug."
    else
      if event.from == 'relevant'
        p.append "This bug was marked as relevant."
      else
        p.append "This bug was reopened"
        if event.occurrence
          p.append " by "
          $('<a/>').attr('href', event.occurrence_url).text("occurrence ##{event.occurrence.number}").appendTo p
        p.append "."

  # @private
  renderDeployEvent: (event, p) ->
    if event.build
      p.append "The fix was released as part of build "
      $('<strong/>').text(event.build).appendTo p
      if event.revision
        p.append " (revision "
        if event.revision_url
          $('<a/>').attr('href', event.revision_url).text(event.revision.slice(0, 6)).appendTo p
        else
          p.append event.revision.slice(0, 6)
        p.append ")"
    else
      p.append "The fix was deployed"
      if event.revision
        p.append " with revision "
        if event.revision_url
          $('<a/>').attr('href', event.revision_url).text(event.revision.slice(0, 6)).appendTo p
        else
          p.append event.revision.slice(0, 6)
    p.append "."

  # @private
  renderEmailEvent: (event, p) ->
    p.append "An email alert about this bug was sent to "
    p.append toSentence("<strong>#{em}</strong>" for em in event.recipients)
    p.append "."

  # @private
  renderDupeEvent: (event, p) ->
    if event.user
      $('<a/>').text(if event.user_you then "You" else event.user.name).attr('href', event.user_url).appendTo p
      p.append " flagged this bug as a duplicate of "
    else
      p.append "This bug was flagged as a duplicate of "
    $('<a/>').attr('href', event.original_url).text("##{event.original.number}").appendTo p
    p.append "."
