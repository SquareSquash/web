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

# Manages the Occurrence aggregation view.
#
class root.Aggregation

  # Creates a new manager.
  #
  # @param [jQuery object] element The element where aggregation results will be
  #   rendered into.
  # @param [jQuery object] filter The form containing filter options.
  # @param [String] url The URL to load aggregation results from.
  #
  constructor: (@element, @filter, @url) ->

  # Loads and renders aggregation results.
  load: ->
    @element.empty()
    $('<p/>').addClass('no-results').text("Loading…").appendTo @element

    $.ajax @url,
      data: @filter.serialize()
      success: (data) =>
        @element.empty()
        for own dimension, values of data
          do (dimension, values) =>
            return if values.length == 0
            chart = $('<div/>').addClass('aggregation-dim').appendTo(@element)
            $.plot chart, values,
              series:
                stack: true
                bars: {show: true, lineWidth: 0}
              xaxis:
                mode: 'time'
                timeformat: '%Y/%m/%d %H:%M'
                tickLength: 5
              yaxis:
                min: 0
                max: 100
                tickDecimals: 0
                tickFormatter: (num) -> "#{num}%"
              grid:
                borderWidth: 1
                borderColor: 'gray'
              legend:
                sorted: 'ascending'
      error: =>
        @element.empty()
        new Flash('alert').text "Couldn’t load aggregation results."
