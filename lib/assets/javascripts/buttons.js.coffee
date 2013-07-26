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

# Any buttons with HREF attributes automatically act as links. These buttons can
# also have DATA-SQMETHOD and DATA-SQCONFIRM attributes similar to Rails magic
# links.
#
jQuery.fn.autoButton =  ->
  for element in this
    do (element) ->
      $(element).click (e) ->
        button = $(e.currentTarget)

        perform = true
        if button.data('sqconfirm')
          perform = confirm(button.data('sqconfirm'))
        unless perform then return false

        if button.data('sqmethod')
          form = $('<form/>').attr(action: button.attr('href'), method: 'POST')
          $('<input/>').attr(type: 'hidden', name: '_method', value: button.data('sqmethod')).appendTo form
          $('<input/>').attr(type: 'hidden', name: $('meta[name=csrf-param]').attr('content'), value: $('meta[name=csrf-token]').attr('content')).appendTo form
          form.submit()
        else
          window.location = button.attr('href')
  return $(this)

# Applies button behavior to any BUTTON tags already on the page at load time.
$(document).ready -> $('button[href]').autoButton()
