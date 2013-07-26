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

# A manager that renders and displays the Value Inspector, a modal dialog that
# allows the user to inspect objects in a language-independent way. The Value
# Inspector displays multiple representations of an object (such as YAML or
# JSON). The JSON representation appears as a hierarchical list that can be
# navigated through.
#
# Use the `$(...).valueInspector()` method rather than this object's
# constructor.
#
class root.ValueInspector

  # @private
  constructor: (@element) ->
    @object = @element.data('object')
    if typeof @object == 'string'
      @element.append(@object.slice(0, 50) + '&hellip;')
      $('<br/>').appendTo @element
      @object = { to_s: @object }
    $('<i/>').addClass('icon-search').appendTo @element
    $('<a/>').text("View in Value Inspector").appendTo(@element).click =>
      this.show()
      false

  # Displays the Value Inspector modal.
  #
  show: ->
    unless @inspector?
      @inspector = this.build()
      @inspector.find('ul.pills>li:first-child a').click()
    @inspector.showModal
      closeButton: '.close'

  # @private
  build: ->
    modal = $('<div/>').addClass('modal value-inspector').appendTo($('body'))
    $('<a/>').addClass('close').text("×").appendTo modal
    $('<h1/>').text("Value Inspector").appendTo modal

    body = $('<div/>').addClass('modal-body').appendTo(modal)
    tabs = $('<ul/>').addClass('pills').appendTo(body)
    tab_content = $('<div/>').addClass('tab-content').appendTo(body)
    if @object.json
      $('<li/>').append($('<a/>').addClass('json').text('JSON')).appendTo tabs
      json_tab = $('<div/>').addClass('json').appendTo(tab_content)
      this.buildJSON json_tab
    if @object.yaml
      $('<li/>').append($('<a/>').addClass('yaml').text('YAML')).appendTo tabs
      yaml_tab = $('<div/>').addClass('yaml').appendTo(tab_content)
      this.buildYAML yaml_tab
    if @object.keyed_archiver
      $('<li/>').append($('<a/>').addClass('keyed_archiver').text('NSKeyedArchiver')).appendTo tabs
      archive_tab = $('<div/>').addClass('keyed_archiver').appendTo(tab_content)
      this.buildKeyedArchiver archive_tab
    if @object.inspect
      $('<li/>').append($('<a/>').addClass('inspect').text('#inspect')).appendTo tabs
      inspect_tab = $('<div/>').addClass('inspect').appendTo(tab_content)
      this.buildInspect inspect_tab
    if @object.to_s
      $('<li/>').append($('<a/>').addClass('to_s').text('#to_s')).appendTo tabs
      to_s_tab = $('<div/>').addClass('to_s').appendTo(tab_content)
      this.buildToS to_s_tab
    if @object.description
      $('<li/>').append($('<a/>').addClass('description').text('[-description]')).appendTo tabs
      description_tab = $('<div/>').addClass('description').appendTo(tab_content)
      this.buildDescription description_tab

    tabs.find('a').click (e) =>
      target = $(e.currentTarget)
      this.activateTab target.parent(), tab_content.find(".#{target.attr('class')}")

    modal

  # @private
  buildWrapCheckbox: (tab, code) ->
    label = $('<label/>').text(" Soft wrapping").appendTo(tab)
    $('<input/>').attr(type: 'checkbox', name: 'wrap').prependTo(label).change (e) ->
      if e.target.checked then code.removeClass('nowrap') else code.addClass('nowrap')

  # @private
  buildJSON: (tab) ->
    try
      this.buildJSONFields(JSON.parse(@object.json), true).appendTo tab
    catch error
      tab.append "JSON parse error: #{error}."

  # @private
  buildYAML: (tab) ->
    code = $('<pre/>').addClass('brush: yaml').text(@object.yaml).appendTo(tab)
    SyntaxHighlighter.highlight {}, code[0]

  # @private
  buildKeyedArchiver: (tab) ->
    code = $('<pre/>').addClass('brush: xml').text(@object.keyed_archiver).appendTo(tab)
    SyntaxHighlighter.highlight {}, code[0]

  # @private
  buildInspect: (tab) ->
    code = $('<pre/>').addClass('nowrap scrollable').text(@object.inspect).appendTo(tab)
    this.buildWrapCheckbox tab, code

  # @private
  buildToS: (tab) ->
    code = $('<pre/>').addClass('nowrap scrollable').text(@object.to_s).appendTo(tab)
    this.buildWrapCheckbox tab, code

  # @private
  buildDescription: (tab) ->
    code = $('<pre/>').addClass('nowrap scrollable').text(@object.description).appendTo(tab)
    this.buildWrapCheckbox tab, code

  # @private
  buildJSONFields: (object, open=false) ->
    if object && typeof object == 'object'
      details = $('<details/>')
      if open then details.data('open', 'open')
      $('<summary/>').text(object.constructor.toString().match(/^function (\w+)/)[1]).appendTo details
      table = $('<table/>').appendTo(details)
      for name, value of object
        do (name, value) =>
          tr = $('<tr/>').appendTo(table)
          $('<td/>').append($('<tt />').text(name)).appendTo tr
          $('<td/>').append(this.buildJSONFields(value)).appendTo tr
      details.detailsIfNecessary()
    else
      $('<span/>').text(if typeof object == 'undefined' then 'undefined' else if typeof object == 'object' then 'null' else object.toString())

  # @private
  activateTab: (tab, pane) ->
    @inspector.find('ul.pills>li').removeClass 'active'
    tab.addClass 'active'
    @inspector.find('.tab-content>div').removeClass('active')
    pane.addClass 'active'

# Creates a Value Inspector for an object. The receiver should have a
# `data-object` attribute containing the JSON-serialized object prepared for
# the Value Inspector. (This is a JSON hash consisting of at least a `to_s` key
# plus keys for whatever other representations are available.)
#
# Along with creating the (initially hidden) modal, this method will append a
# "View in Value Inspector" link to the receiver. If the object is a string, it
# will also be appended. Long strings will be truncated with an ellipsis.
#
# @return [ValueInspector] The Value Inspector manager.
#
jQuery.fn.valueInspector = ->
  for tag in this
    do (tag) ->
      new ValueInspector($(tag))
