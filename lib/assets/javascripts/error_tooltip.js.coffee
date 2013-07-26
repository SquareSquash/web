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
escape = (str) -> str.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

# Generates appropriate options to send to the Bootstrap tooltip function for a
# tooltip containing the error messages associated with a form field.
#
# @param [Array<String>] errors The error messages for a form field.
#
root.errorTooltipOptions = (errors) ->
  {
    title: (escape(error) for error in errors).join("<br/>")
    html: true
    placement: 'right'
    trigger: 'focus'
    template: '<div class="tooltip tooltip-error"><div class="tooltip-arrow"></div><div class="tooltip-inner"></div></div>'
  }
