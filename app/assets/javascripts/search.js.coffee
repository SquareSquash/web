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

# Manages the search field in the navigation bar. Sends Ajax requests to fulfill
# suggestion prompting and searching.
#
class root.SearchBar

  # Creates a new manager that handles a given search field.
  #
  # @param [jQuery object] element The search field.
  #
  constructor: (@element) ->
    @suggestions = $('<ul/>').attr('id', 'search-suggestions').insertAfter(@element)
    this.hideSuggestions()

    @element.keypress (event) =>
      if event.charCode == 13
        this.search()
        event.preventDefault(); event.stopPropagation(); return false
      return true

    @element.keyup (event) =>
      this.change()
      return true

    @element.submit => this.search()

    @element.blur =>
      @element.val ''
      this.hideSuggestions()

  # Called when the search field value changes. Retrieves suggestions and
  # renders the results.
  #
  change: ->
    @element.stopTime 'suggestions'
    @element.oneTime 500, 'suggestions', =>
      $.ajax '/search/suggestions.json',
        type: 'GET'
        data: $.param({query: @element.val()})
        success: (suggestions) =>
          this.clearSuggestions()
          if suggestions.length > 0
            this.renderSuggestions suggestions
            if suggestions.length == 1
              switch suggestions[0].type
                when 'project'
                  this.hintEnvironment(suggestions[0].project)
                  this.hintBug(suggestions[0].project)
                  this.hintOccurrence(suggestions[0].project)
                when 'environment'
                  this.hintBug(suggestions[0].project, suggestions[0].environment)
                  this.hintOccurrence(suggestions[0].project, suggestions[0].environment)
                when 'bug'
                  this.hintOccurrence(suggestions[0].project, suggestions[0].environment, suggestions[0].bug)
          else
            this.hintProject()
            this.hintEnvironment()
            this.hintBug()
            this.hintOccurrence()
            this.hintUser()
          this.showSuggestions()
        error: (xhr) =>
          this.clearSuggestions()
          if xhr.status != 404 && xhr.status != 422
            new Flash('alert').text "Couldn’t load search suggestions."

  # Called when the search field is submitted using the enter key. Performs a
  # search. Redirects to the result if given.
  #
  search: ->
    $.ajax "/search",
      type: 'GET'
      data: $.param({query: @element.val()})
      success: (url) -> window.location = url unless url.match(/^\s*$/)
      error: -> new Flash('alert').text "Couldn’t perform search."

  # @private
  hintUser: ->
    li = $('<li/>').addClass('hint').appendTo(@suggestions)
    li.append "@"
    $('<em/>').text('username').appendTo li
    return li

  # @private
  hintProject: ->
    li = $('<li/>').addClass('hint').appendTo(@suggestions)
    $('<em/>').text('project').appendTo li

  # @private
  hintEnvironment: (project=null) ->
    li = $('<li/>').addClass('hint').appendTo(@suggestions)
    if project
      li.text project.slug
    else
      $('<em/>').text('project').appendTo li
    li.append ' '
    $('<em/>').text('environment').appendTo li

  # @private
  hintBug: (project=null, environment=null) ->
    li = $('<li/>').addClass('hint').appendTo(@suggestions)
    if project
      li.text project.slug
    else
      $('<em/>').text('project').appendTo li
    li.append ' '
    if environment
      li.append $('<span/>').text(environment.name).html()
    else
      $('<em/>').text('environment').appendTo li
    li.append ' '
    $('<em/>').text('bug#').appendTo li

  # @private
  hintOccurrence: (project=null, environment=null , bug=null) ->
    li = $('<li/>').addClass('hint').appendTo(@suggestions)
    if project
      li.text project.slug
    else
      $('<em/>').text('project').appendTo li
    li.append ' '
    if environment
      li.append $('<span/>').text(environment.name).html()
    else
      $('<em/>').text('environment').appendTo li
    li.append ' '
    if bug
      li.append bug.number
    else
      $('<em/>').text('bug#').appendTo li
    li.append ' '
    $('<em/>').text('occurrence#').appendTo li

  # @private
  clearSuggestions: ->
    this.hideSuggestions()
    @suggestions.empty()

  # @private
  renderSuggestions: (suggestions) ->
    for suggestion in suggestions
      do (suggestion) =>
        li = $('<li/>').appendTo(@suggestions)
        switch suggestion.type
          when 'user'
            li.text "@#{suggestion.user.username} — #{suggestion.user.name}"
          when 'project'
            li.text "#{suggestion.project.slug} — #{suggestion.project.name}"
          when 'environment'
            li.text "#{suggestion.project.name} #{suggestion.environment.name}"
          when 'bug'
            li.text "#{suggestion.project.name} #{suggestion.environment.name} bug ##{numberWithDelimiter suggestion.bug.number}"
          when 'occurrence'
            li.text "#{suggestion.project.name} #{suggestion.environment.name} bug ##{numberWithDelimiter suggestion.bug.number} occurrence ##{numberWithDelimiter suggestion.occurrence.number}"

        if suggestions.length == 1
          $('<span/>').addClass('newline').text("⏎").appendTo li

  # Shows the suggestions list.
  showSuggestions: -> @suggestions.show()

  # Hides the suggestions list.
  hideSuggestions: -> @suggestions.hide()

# Creates the manager for the search bar.
#
$(window).ready -> new SearchBar($('#quicknav'))
