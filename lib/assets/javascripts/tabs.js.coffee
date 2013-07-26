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

# @private
switchToTab = (link, target) ->
  link.parent().siblings().removeClass 'active'
  link.parent().addClass 'active'

  target.siblings().removeClass 'active'
  target.addClass 'active'

defaultTab = null
defaultLink = null

# Enables tab-switching functionality on all links with their `rel` attribute
# set to "tab" and their `href` attribute set to the jQuery specifier of a tab
# item. Tab items must be grouped under a parent with the class "tab-content".
#
# If you add the "tab-primary" class to your "tab-content" div, the selected tab
# will also be set in the URL hash and pushed to the browser history. Only one
# tab group should be marked as primary.
#
$(window).ready ->
  defaultTab = $('.tab-content.tab-primary>.active')
  defaultLink = $("a[rel=tab][href=\"##{defaultTab.attr('id')}\"]")

  $('a[rel=tab]').click (e) ->
    link = $(e.currentTarget)
    target = $(link.attr('href'))
    return true unless target.parent().hasClass('tab-content')

    switchToTab link, target
    if target.parent().hasClass('tab-primary')
      history.pushState '', document.title, window.location.pathname + link.attr('href')

    e.stopPropagation()
    e.preventDefault()
    return false

# @private
preselectTab = ->
  if document.location.hash.length == 0
    switchToTab defaultLink, defaultTab

  target = $(document.location.hash)
  return true unless target.parent().hasClass('tab-content') && target.parent().hasClass('tab-primary')
  link = $("li>a[href=\"#{document.location.hash}\"]")

  switchToTab link, target

  return false

# When a history state is popped that includes a tab HREF, activate that tab.
window.onpopstate = preselectTab

# When a page is loaded with a tab HREF, activate that tab.
$(window).ready preselectTab
