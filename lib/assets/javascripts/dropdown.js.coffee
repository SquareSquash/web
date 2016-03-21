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

# Applies dropdown behavior to any link with `rel=dropdown`. The link's `href`
# attribute is a jQuery specifier for its target; clicking the link toggles the
# "shown" class on the target. You should obviously have the target CSS set to
# `display: none` without the "shown" class./
#
$(window).ready ->
  roll_everything_up = ->
    $('a[rel=dropdown]>.fa-chevron-up').removeClass('fa fa-chevron-up').addClass 'fa fa-chevron-down'
    $('nav .shown').removeClass 'shown'

  # Clicking on a dropdown link toggles the dropdown
  $('a[rel=dropdown]').click (e) ->
    link = $(e.currentTarget)
    target = $(link.attr('href'))

    roll_everything_up()
    target.toggleClass('shown')
    if target.hasClass('shown')
      link.find('.fa-chevron-down').removeClass('fa fa-chevron-down').addClass 'fa fa-chevron-up'

    e.preventDefault()
    return false

  # Clicking elsewhere hides all dropdowns
  $('body').click (e) =>
    # don't roll up dropdowns if we are clicking inside a dropdown
    return if $(e.target).closest('[rel=dropdown]').length > 0
    return if $(e.target).closest('nav .shown').length > 0

    roll_everything_up()

    return true

# Applies menu-expansion dropdown behavior to a navigation bar or tab header
# item when that bar/header is displayed in compact (stacked) view. Normally
# other tab items are not shown, but clicking this button toggles the
# "full-size-only" class on all sibling `<LI>`s.
#
# The class of the link itself ("fa-chevron-down" or "fa-chevron-up") is used to
# track the state of the menu.
#
$(window).ready ->
  $('a[rel="list-expansion"]').click (e) ->
    link = $(e.currentTarget)
    lis = link.closest('li').siblings('li')

    if link.hasClass('fa-chevron-down')
      lis.removeClass 'full-size-only'
      link.removeClass('fa fa-chevron-down').addClass 'fa fa-chevron-up'
    else
      lis.addClass 'full-size-only'
      link.removeClass('fa fa-chevron-up').addClass 'fa fa-chevron-down'
