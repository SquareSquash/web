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
class root.MemberPanel
  constructor: (@element, name, @project_id, @users_endpoint, @memberships_endpoint, @membership_endpoint, @project_endpoint, @role, highlight=false) ->
    highlight_container = @buildFilter()
    @buildModal name

    self = this
    new DynamicSearchField(@filter, (q) -> self.processFilterSearchResults(q))
    @processFilterSearchResults ''

    new DynamicSearchField(@find, (q) -> self.processAddMemberSearchResults(q))

    if highlight then highlight_container.effect('highlight', 3000)

  processFilterSearchResults: (query) ->
    $.ajax "#{@memberships_endpoint}?query=#{encodeURIComponent(query)}",
      type: 'GET'
      success: (results) =>
        @filter_results.find('li').remove()
        $.each results, (_, membership) =>
          li = $('<li/>').appendTo(@filter_results)
          h5 = $('<h5/>').text(" (#{membership.user.name})").appendTo(li)
          $('<strong/>').text(membership.user.username).prependTo h5

          p = $('<p/>').text(" — #{if membership.role == 'owner' then 'created' else 'joined'} #{membership.created_string}").appendTo(li)
          $('<strong/>').text(membership.human_role).prependTo p
          if @role == 'owner'
            if membership.role == 'admin'
              p.append '<br/>'
              $('<button/>').text("Demote Admin").
                  addClass('default small').attr('href', '#').
                  click(=> @changeUser(membership.user.username, 'member', query)).appendTo p
              $('<button/>').text("Make Owner").
                  addClass('default small').attr('href', '#').
                  click(=> @changeUser(membership.user.username, 'owner', query)).appendTo p
            else if membership.role == 'member'
              p.append '<br/>'
              $('<button/>').text("Make Admin").
                  addClass('default small').attr('href', '#').
                  click(=> @changeUser(membership.user.username, 'admin', query)).appendTo p
          if @role != 'member'
            if membership.role == 'member'
              $('<button/>').text("Remove").
                  addClass('warning small').attr('href', '#').
                  click(=> @changeUser(membership.user.username, 'delete', query)).appendTo p
      error: => new Flash('alert').text("Error retrieving member search results.")

  processAddMemberSearchResults: (query) ->
    $.ajax "#{@users_endpoint}?query=#{encodeURIComponent(query)}&project_id=#{@project_id}",
      type: 'GET'
      success: (results) =>
        @find_results.find('li').remove()
        $.each results, (_, user) =>
          li = $('<li/>').appendTo(@find_results)
          h5 = $('<h5/>').text(" (#{user.name})").appendTo(li)
          $('<strong/>').text(user.username).prependTo h5
          if user.is_member then $('<p/>').text("(member)").appendTo(li)
          else
            p = $('<p/>').appendTo li
            $('<button/>').text("Add member").addClass('small default').attr('href', '#').click(=>
              $.ajax @memberships_endpoint,
                type: 'POST'
                data: $.param({'membership[user_username]': user.username})
                success: =>
                  @processAddMemberSearchResults query
                  @processFilterSearchResults @filter.val()
                error: => new Flash('alert').text("Couldn’t add #{user.username} to #{@name}.")
              false
            ).appendTo p
      error: -> new Flash('alert').text("Couldn’t load search results.")

  changeUser: (username, new_role, search_query) ->
    if new_role == 'member' # patch to membership, admin=false
      $.ajax @membership_endpoint.replace('USERID', username),
        type: 'PATCH'
        data: $.param({'membership[admin]': 'false'})
        error: => Flash('alert').text("Couldn’t demote #{username} from administrator.")
        complete: => @processFilterSearchResults(search_query)

    else if new_role == 'admin' # patch to membership, admin=true
      $.ajax @membership_endpoint.replace('USERID', username),
        type: 'PATCH'
        data: $.param({'membership[admin]': 'true'})
        error: => Flash('alert').text("Couldn’t promote #{username} to administrator.")
        complete: => @processFilterSearchResults(search_query)

    else if new_role == 'owner' # patch to project, owner_id=123
      $.ajax @project_endpoint,
        type: 'PATCH'
        data: $.param({'project[owner_username]': username})
        error: => Flash('alert').text("Couldn’t assign ownership to #{username}.")
        success: -> window.location.reload()

    else if new_role == 'delete' # delete to membership
      $.ajax @membership_endpoint.replace('USERID', username),
        type: 'DELETE'
        error: => Flash('alert').text("Couldn’t remove #{username} from #{@name}.")
        complete: => @processFilterSearchResults(search_query)

    false

  buildFilter: ->
    div = $('<div/>').addClass('whitewashed').appendTo(@element)
    @filter = $('<input/>').attr({ type: 'search', placeholder: "Filter by name" }).appendTo(div)
    @filter_results = $('<ul/>').addClass('results').appendTo(div)
    p = $('<p/>').appendTo(div)
    if @role == 'admin' || @role == 'owner'
      $('<button/>').text("Add member").attr({href: '#add-member'}).leanModal({closeButton: '.close'}).appendTo p

    div

  buildModal: (name) ->
    @modal = $('<div/>').addClass('modal').attr('id', 'add-member').css('display', 'none').appendTo(@element)

    $('<a/>').text('×').addClass('close').appendTo @modal
    $('<h1/>').text("Add a member to #{name}").appendTo @modal

    body = $('<div/>').addClass('modal-body').appendTo(@modal)
    @find = $('<input/>').attr({ type: 'search', placeholder: "Enter a username" }).appendTo(body)
    @find_results = $('<ul/>').addClass('results').appendTo(body)
