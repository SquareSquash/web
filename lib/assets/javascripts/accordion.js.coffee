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

# Implements accordion behavior. An accordion container must have the class of
# "accordion" and consist of one or more elements of class "accordion-pair".
# Each of these elements must have an `<H5>` (header) and a `<DIV>` (body).
#
# Accordion headers must contain an `<A>` element whose `href` is the jQuery
# specifier for the `<DIV>` body and whose `rel` is "accordion".
#
$(window).ready ->
  $('a[rel=accordion]').click (e) ->
    link = $(e.currentTarget)
    target = $(link.attr('href'))

    # hide all other items
    shown = target.closest('.accordion').find('.accordion-pair.shown')
    shown.find('>div').slideUp 'fast', -> shown.removeClass('shown')

    # toggle the target item
    if target.hasClass('shown')
      target.find('>div').slideUp 'fast', -> target.removeClass('shown')
    else
      target.addClass('shown')
      target.find('>div').slideDown 'fast'

    e.preventDefault()
    e.stopPropagation()
    return false
