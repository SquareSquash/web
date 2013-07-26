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

# Where by "sortable," I mean "sortable, filterable, Ajax-backed,
# infinitely-scrolling, and generally awesome."
#
# Prerequisites: You need a table, and an Ajaxy endpoint that returns a JSON or
# XML array of records. It should respect the values of the "sort" and "dir"
# query parameters, as well as the "last" query parameter for infinite scrolling
# (see the scroll_with option).
#
# All HTTP errors are handled gracefully with table messages.
#
class root.SortableTable

  # Creates a sortable table manager.
  #
  # The column definition is an array of columns (in order). Each column is an
  # object with the following keys:
  #
  # | Hash key        | Value type | Description                                                                                                                                                |
  # |:----------------|:-----------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------|
  # | `key`           | `String`   | Unique identifier for the column, and sort parameter.                                                                                                      |
  # | `title`         | `String`   | Column title (human-readable).                                                                                                                             |
  # | `sortable`      | `String`   | If `null`, the column is not sortable. If "asc" or "desc", the column is sortable, and defaults to that sort direction.                                    |
  # | `textGenerator` | `function` | A function that, given a record, generates the column's contents. Defaults to pulling out whatever value is associated with the column key (HTML-escaped). |
  # | `htmlGenerator` | `function` | Like `textGenerator`, but does not HTML-escape the result.                                                                                                 |
  #
  # @param [jQuery element array] element The TABLE element.
  # @param [String] endpoint The URL to your endpoint. Don't include any query
  #   parameters; see `options` if you need those.
  # @param [Array] columns Your column definition. See above.
  # @param [Object] options Additional options.
  # @option options [String] sort_key The column that is initially sorted by default.
  # @option options [Object, function] Additional query parameters. Can be an
  #   object or a function that returns an object (to be serialized).
  # @option options [String] scroll_with The record key to send to the server
  #   when infinitely scrolling, to indicate the last-loaded record.
  #
  constructor: (@element, @endpoint, @columns, options) ->
    @additional_params = options.params
    @scroll_identifier = options.scroll_with || 'id'
    @element.addClass 'sortable'

    thead = $('<thead/>').appendTo @element
    $('<tbody/>').appendTo @element
    header_row = $('<tr/>').appendTo(thead)
    for column in @columns
      do (column) =>
        th = $('<th/>').text(column.title).attr('id', "header-#{column.key}").appendTo(header_row)
        if column.sortable
          i = $('<i/>').appendTo(th)
          if @sort_key == column.key
            if @sort_dir == 'asc' then i.addClass('icon-sort-up') else i.addClass('icon-sort-down')
          else
            i.addClass('icon-sort')
          th.addClass 'sortable'
          th.click =>
            this.sort column.key

    $(window).scroll (e) =>
      if $(window).scrollTop() >= $(document).height() - $(window).height() && !@loading_more && @last && !@end_of_scroll
        @loading_more ||= $('<div/>').addClass('alert info').text(" Loading more…").insertAfter(@element)
        $('<i/>').addClass('icon-refresh').prependTo(@loading_more)
        $.ajax @endpoint,
          data: $.param($.extend({}, this.additionalParams(), this.sortParameters(), { last: @last }))
          type: 'GET',
          success: (records) =>
            if records.length > 0 then this.addRecords(records) else @end_of_scroll = true
            if @loading_more
              @loading_more.remove()
              @loading_more = null
          error: =>
            this.setNote "Couldn’t load results ☹", false
            if @loading_more
              @loading_more.remove()
              @loading_more = null
            @end_of_scroll = true

    this.setNote "Loading…"
    this.sort options.sort_key

  # Forces a refresh of the table data.
  #
  # @param [function, null] after_complete A callback to invoke once the refresh
  #   completes successfully.
  # @param [Boolean] after_error_too if `true`, runs `after_complete` if there's
  #   an error.
  #
  refreshData: (after_complete, after_error_too=false) ->
    $.ajax @endpoint,
      data: $.param($.extend({}, this.additionalParams(), this.sortParameters()))
      type: 'GET'
      complete: =>
        this.updateHead() # remove refresh icon
      success: (records) =>
        this.clearData()
        @end_of_scroll = false
        if records.length > 0 then this.addRecords(records) else this.setNote("No results")
        if records.length < 50 then @end_of_scroll = true
        if after_complete then after_complete()
      error: =>
        this.setNote "Couldn’t load results ☹"
        if after_complete && after_error_too then after_complete()
    this

  # Removes all data rows from the table.
  #
  clearData: ->
    @element.find('tbody').empty()

  # Invoked when a column header is clicked. Resorts the table by the new key.
  # A call to `sort` with the sort key already in use reverses the sort.
  #
  # @param [String] key The key to sort on, as an element in the columns array.
  #
  sort: (key) ->
    for column in @columns
      do (column) ->
        if column.key == key
          if column.sorted == 'asc'
            column.sorted = 'desc'
          else if column.sorted == 'desc'
            column.sorted = 'asc'
          else
            column.sorted = column.sortable
        else
          column.sorted = false
    this.updateHead()
    @element.find("#header-#{this.sortKey()}>i").removeClass().addClass('icon-refresh')
    this.refreshData()

  # @private
  updateHead: ->
    @element.find('thead>tr>th').removeClass('sorted')
    @element.find('thead>tr>th>i').remove()
    @element.find("#header-#{this.sortKey()}").addClass 'sorted'
    $('<i/>').addClass("icon-sort-#{if this.sortDir() == 'asc' then 'up' else 'down'}").appendTo @element.find("#header-#{this.sortKey()}")
    $('<i/>').addClass("icon-sort").appendTo @element.find("thead>tr>th.sortable[id!=header-#{this.sortKey()}]")

  # @private
  sortKey: ->
    for column in @columns when column.sorted
      return column.key
    null

  # @private
  sortDir: ->
    for column in @columns when column.sorted
      return column.sorted
    null

  # @private
  sortParameters: ->
    { sort: this.sortKey(), dir: this.sortDir() }

  # @private
  additionalParams: ->
    if typeof @additional_params == 'function'
      @additional_params()
    else
      @additional_params

  # Replaces the contents of this table with a note indicating, e.g., an error.
  #
  # @param [String] note The note to display.
  # @param [Boolean] clear If `true`, all body rows will be removed before the
  #   note is rendered.
  #
  setNote: (note, clear=true) ->
    if clear then this.clearData()
    tr = $('<tr/>').addClass('no-highlight').appendTo(@element)
    $('<td/>').attr('colspan', @columns.length).addClass('table-notice').html(note).appendTo(tr)

  # @private
  addRecords: (records) ->
    if records.length == 0 then return
    @last = records[records.length - 1][@scroll_identifier]
    for record in records
      do (record) =>
        tr = $('<tr/>').attr('id', "#{@element.attr('id')}-row#{record[@scroll_identifier]}").appendTo(@element.find('tbody'))
        for column in @columns
          do (column) ->
            td = $('<td/>').addClass("column-#{column.key}").appendTo(tr)
            td_inner = if record.href then $('<a/>').addClass('rowlink').attr('href', record.href).appendTo(td) else td
            if column.htmlGenerator
              html = column.htmlGenerator(record)
              # don't clobber cell-specific links with the row-wide link
              column.htmlGenerator(record).appendTo(if html.is('a') then td else td_inner)
            else if column.textGenerator
              td_inner.text column.textGenerator(record)
            else
              if record[column.key]? then td_inner.text(record[column.key]) else td_inner.html('<span class="aux">N/A</span>')
    @element.trigger 'append', [records]
