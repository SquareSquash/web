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

# A single flash message that appears at the bottom of the screen. Initialize
# the flash message with the constructor, then call {#text} to set the message
# text.
#
class root.Flash

  # Creates a new flash message with a given appearance type.
  #
  # @param [String] type The flash message appearance (alert, success, or
  #   notice.
  #
  constructor: (@type) ->
    @element = $('<div/>').addClass("flash-#{@type}").appendTo($('#flashes'))
    @text_element = $('<span/>').appendTo(@element)

    @close = $('<a/>').text('×').appendTo(@element)
    @close.click => this.remove()

    switch @type
      when 'alert'   then $('<i/>').addClass('icon-exclamation-sign').prependTo(@element)
      when 'success' then $('<i/>').addClass('icon-ok-sign').prependTo(@element)
      when 'notice'  then $('<i/>').addClass('icon-info-sign').prependTo(@element)

    @element.oneTime 500, => @element.addClass 'flash-shown'
    @element.oneTime(5000, => this.remove()) if @type == 'success'

  # Sets the message text.
  #
  # @param [String] text The message text.
  # @return [Flash] This object.
  #
  text: (text) ->
    @text_element.text text
    this

  # Fades this element out, then removes it.
  #
  remove: ->
    @close.remove()
    @element.addClass('flash-hidden')
    @element.oneTime 1000, => @element.remove()
    delete this
