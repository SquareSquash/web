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

liveUpdates = []

# Applies live-updating behavior to a page element. This function acts in one of
# two ways depending on the type of tag it's called on:
#
# TIME tags:
#
# Given a time tag like <time datetime="[JSON-formatted time string]" />, sets
# the content of the tag to the relative representation of that time (e.g.,
# "about 5 hours ago"), and adds an on-hover tooltip displaying the absolute
# time. Spawns a timer that periodically updates the relative time.
#
# Constructor takes no parameters.
#
# Other tags:
#
# Takes an Ajax-y endpoint and a handler. Periodically calls the endpoint and
# then invokes the handler with the result. The endpoint should return new data
# to update the element value, and the handler should take that data and update
# the element content appropriately.
#
# The element will be temporarily highlighted if it is detected that the value
# changed.
#
# @param [String] endpoint The URL to the form updating endpoint.
# @param [function] handler Invoked with the response of the endpoint when the
#   field is to be updated.
# @param [Object] options Additional options:
# @option options [Boolean] showWhenLoading (true) Display an ellipsis when the
#   value is loading.
# @option options [Boolean] showWhenError (true) Display an error icon on Ajax
#   error.
#
jQuery.fn.liveUpdate = (endpoint, handler, options) ->
  return unless this[0]
  element = $(this[0])

  updater = null
  options = $.extend({}, options, { showWhenLoading: true, showWhenError: true })

  if this[0].nodeName.toLowerCase() == 'time'
    time = new Date(Date.parse(element.attr('datetime')))
    element.attr('title', time.toLocaleString()).tooltip()
    updater = ->
      time = new Date(Date.parse(element.attr('datetime')))
      element.text "#{timeAgoInWords(time)} ago"
  else
    if options.showWhenLoading then element.text("…")
    updater = ->
      $.ajax endpoint,
        type: 'GET'
        success: (response) =>
          old_body = element.html()
          element.empty()
          element.text handler(response)
          if old_body != "…" && element.html() != old_body
            element.effect('highlight')
        error: =>
          element.empty()
          if options.showWhenError then $('<i/>').addClass('fa fa-exclamation-circle').appendTo element

  liveUpdates.push updater
  $(document).stopTime 'liveUpdate'
  $(document).everyTime 10000, 'liveUpdate', -> (proc() for proc in liveUpdates)
  updater()

  return element
