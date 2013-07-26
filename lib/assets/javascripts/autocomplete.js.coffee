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

# @private
class AutocompleteItem
  constructor: (@element, @object, @value) ->

# Adds autocomplete capability to a field. When the field becomes focus, the
# autocomplete panel opens with all suggestions. Suggestions filter as the user
# types. The user can use the mouse or keyboard to choose a suggestion.
#
class root.Autocomplete

  # Builds a new autocomplete handler for a field.
  #
  # @param [jQuery element] element The field to autocomplete-ize.
  # @param [Object] options Autocomplete behavior.
  # @option options [Array<Object>] suggestions An array of arbitrary objects
  #   that represent autocomplete suggestions.
  # @option options [function] elementBuilder Function that takes a
  #   jQuery-generated element to add to the suggestion list, and a suggestion
  #   from `suggestions`. It should modify the element to display the
  #   suggestion.
  # @option options [function] filterSuggestions Function that takes two
  #   arguments: 1) a query string, and 2) the value of `suggestions`, and
  #   returns a filtered subset of the second argument given the value of the
  #   first.
  # @option options [function] fieldValue Function that takes an element of
  #   `suggestions` and returns a value that should be placed into the text
  #   field if that selection is chosen.
  #
  constructor: (@element, @options) ->
    @element.wrap $('<div/>').css('position', 'relative')
    @element.attr 'autocomplete', 'off'
    @dropdown = $('<ul/>').addClass('autocomplete').appendTo(@element.parent())

    @itemList = this.renderItems(@options.suggestions)
    this.resetSelection()

    @element.focus( =>
      @dropdown.css 'top', '' + @element.outerHeight() + 'px'
      @dropdown.css 'width', '' + @element.outerWidth() + 'px'
      @dropdown.addClass('shown')
    ).blur =>
      @dropdown.oneTime 100, => @dropdown.removeClass('shown')
      # we add the delay to allow a click event to fire on an LI if we clicked
      # on it, before hiding the menu
      this.resetSelection()
    @element.keyup (e) =>
      switch e.keyCode
        when 38 # up arrow
          @selection--
          @selection = -1 if @selection < -1
          e.preventDefault(); e.stopPropagation(); return false
        when 40 # down arrow
          @selection++
          @selection = @itemList.length - 1 if @selection >= @itemList.length
          this.refreshSelection()
          e.preventDefault(); e.stopPropagation(); return false
        else
          this.filter()
          return true
    @element.keydown (e) =>
      switch e.keyCode
        when 13 # enter
          this.applySelection()
          @element.blur()
          e.preventDefault(); e.stopPropagation(); return false
        when 9 # tab
          this.applySelection()
          return true
        else
          return true

  # @private
  renderItems: (items) ->
    @dropdown.empty()
    items = $.map(items, (suggestion, idx) =>
      val = @options.fieldValue(suggestion)
      li = $('<li/>').data('id', val)
      @options.elementBuilder li, suggestion
      @dropdown.append li
      # have the selection follow the mouse cursor
      li.hover (=> this.refreshSelection(idx)), (=> this.refreshSelection())
      li.click => this.applySelection(idx); false

      new AutocompleteItem(li, suggestion, val))
    items

  # Applies the selected suggestion to the field, overwriting its contents.
  #
  # @param [Integer] sel The selection to apply. If omitted, the current
  #   selection is used.
  #
  applySelection: (sel=null) ->
    sel ?= @selection
    return if sel < 0 || sel >= @itemList.length
    @element.val @itemList[sel].value

  # Filters the suggestion list based on the given string.
  #
  # @param [String] string The string to filter on. If omitted, the contents of
  #   the text field are used.
  #
  filter: (string=null) ->
    string ?= @element.val()
    filtered = @options.filterSuggestions(string, @options.suggestions)
    @itemList = this.renderItems(filtered)
    this.resetSelection()

  # @private
  refreshSelection: (sel=null) ->
    sel ?= @selection
    @dropdown.find('>li').removeClass 'selected'
    return unless @itemList && @itemList[sel]
    @dropdown.find(">li[data-id=#{@itemList[sel].value}]").addClass 'selected'

  # Clears the selection state of the dropdown.
  #
  resetSelection: ->
    @selection = -1
    this.refreshSelection()

# Adds a jQuery helper method to autocomplete-ize fields.
jQuery.fn.autocomplete = (options) ->
  new Autocomplete($(this), options)
  return $(this)
