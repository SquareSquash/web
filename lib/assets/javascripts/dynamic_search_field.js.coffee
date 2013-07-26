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

# Adds behavior to a search or filter field. The handler is executed when the
# user stops typing for one second.
#
class root.DynamicSearchField

  # Creates a new manager for a dynamic search field.
  #
  # @param [jQuery element array] element The INPUT field to make dynamic.
  # @param [function] handler The handler to execute.
  #
  constructor: (@element, @handler) ->
    @element.keypress (e) =>
      return false if e.charCode == 13
      @element.stopTime()
      @element.oneTime 1000, 'search-update', =>
        @handler(@element.val())
    @element.submit (e) ->
      e.stopPropagation()
      e.preventDefault()
      false
