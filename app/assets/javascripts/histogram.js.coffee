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

# Manages the histogram view on the Bug page.
#
class root.Histogram
  # Creates a new manager.
  #
  # @param [jQuery object] element The element to render the histogram into.
  # @param [String] url The URL to fetch histogram results from.
  constructor: (@element, @url) ->
    this.load()

  # Loads and renders histogram results.
  #
  load: ->
    this.setNote "Loading…"

    $.ajax @url,
      type: 'GET',
      success: (data) =>
        this.setNote()

        if data.occurrences.length == 0
          this.setNote("No recent occurrences")
          return

        plot = $.plot @element, [data.occurrences],
          series:
            bars: {show: true}
          xaxis:
            mode: 'time'
            timeformat: '%Y/%m/%d %H:%M'
            tickLength: 5
          yaxis:
            tickDecimals: 0
          grid:
            markings: ({color: '#00b', lineWidth: 1, xaxis: {from: deploy.deployed_at, to: deploy.deployed_at}} for deploy in data.deploys)
            borderWidth: 1
            borderColor: 'gray'

        for deploy in data.deploys
          do (deploy) =>
            offset = plot.pointOffset(x: deploy.deployed_at, y: 0)
            $('<div/>').
              addClass('deploy-tooltip').
              css('left', "#{offset.left - 1}px").
              attr('title', deploy.revision[0..6]).
              click(-> window.open(deploy.url)).
              appendTo(@element).
              tooltip()

      error: => this.setNote("Couldn’t load occurrence history ☹")

  # Sets or removes a note that appears in lieu of the histogram.
  #
  # @param [String, null] note The note to set. If `null`, removes the note.
  setNote: (note=null) ->
    @element.empty()
    $('<p/>').text(note).addClass('note').appendTo @element if note
