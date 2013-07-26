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

# Finds PRE tags of class "context" and asynchronously loads context data from
# the Git repository. Displays a selected line of code from the repo with 3
# lines of context above and below.
#
jQuery.fn.applyContext = ->
  for tag in this
    do (tag) ->
      element = $(tag)
      $.ajax "/projects/#{element.attr 'data-project'}/context.json",
        type: 'GET'
        data: $.param
          revision: element.data('revision')
          file: element.data('file')
          line: element.data('line')
          context: (element.data('context') || 3)
        success: (snippet) ->
          element.text(snippet.code).removeClass().addClass("brush: #{snippet.brush}; ruler: true; first-line: #{snippet.first_line}; highlight: #{element.data('line')}; toolbar: false; unindent: false")
          SyntaxHighlighter.highlight()
        error: (xhr) ->
          if xhr && xhr.responseText
            element.text JSON.parse(xhr.responseText).error
          else
            element.text "Couldn’t load context."
  this

# Loads context data for any appropriate PRE tags already on the page at load
# time.
#
$(document).ready -> $('pre.context').applyContext()
