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

# Adds disclosure-triangle support to DETAILS/SUMMARY tags in Firefox and
# Safari. (Chrome already has native support.)
#
jQuery.fn.details = ->
  for tag in this
    do (tag) ->
      container = $(tag)
      header = container.find('>summary')
      container.children(':not(summary)').wrapAll $('<div/>')
      content = container.find('>div')
      triangle = $('<i/>').addClass('fa fa-play').prependTo(header)
      shown = false

      if container.data('open')
        triangle.css("-#{browser}-transform", "rotate(90deg)") for browser in ['webkit', 'moz', 'o']
        shown = true
      else
        content.hide()

      triangle.click ->
        triangle.css("-#{browser}-transform", "rotate(#{if shown then 0 else 90}deg)") for browser in ['webkit', 'moz', 'o']
        shown = !shown
        content.slideToggle()
  this
