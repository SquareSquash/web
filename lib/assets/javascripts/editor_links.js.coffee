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

# Finds links to open files in one's editor and alters their behavior. Now, when
# clicked for the first time, the link will prompt the the user for the project
# root on their computer. It will prepend the project root to the file path and
# then open the file. If a project root has already been stored in the cookie
# store, does not prompt the user.
#
# Editor links require a data-editor attribute ("textmate", "emacs", or "vim"),
# a data-file attribute with the relative path, a data-line attribute with the
# line number, and a data-project attribute with the project identifier.
#
# See https://github.com/typester/emacs-handler.
#
jQuery.fn.editorLink = ->
  for tag in this
    do (tag) ->
      element = $(tag)
      url = null
      command = null
      file = element.data('file')
      line = element.data('line')
      project = element.data('project')
      editor = element.data('editor')

      if editor == 'textmate'
        url = (file) -> "txmt://open?" + $.param({url: file, line: line})
        command = "mate -l #{line} #{shellEscape(file)}"
      else if editor == 'sublime'
        url = (file) -> "subl://open?" + $.param({url: "file://#{file}", line: line})
        command = "subl #{shellEscape(file)}:#{line}"
        element.attr('title', "This link requires asuth/subl-handler to work.").tooltip()
      else if editor == 'vim'
        url = (file) -> "mvim://open?url=file://#{file}&line=#{line}"
        # MacVim doesn't support URL escapes
        command = "vim #{shellEscape(file)} +#{line}"
        element.attr('title', "This link requires MacVim to work.").tooltip()
      else if editor == 'emacs'
        url = (file) -> "emacs://open?" + $.param({url: "file://#{file}", line: line})
        command = "emacs +#{line} #{shellEscape(file)}"
        element.attr('title', "This link requires EmacsURLHandler to work.").tooltip()
      else
        return

      $('<code/>').addClass('short').text(command).appendTo(element)
      element.attr('href', url(file)).click ->
        fullpath = file
        if file.slice(0, 1) != '/'
          root = $.cookie("root:#{project}")
          unless root
            root = prompt("Enter the path to the project root:")
            if !root then return false
            $.cookie "root:#{project}", root.replace(/\/$/, '')
          fullpath = "#{root}/#{fullpath}"
        window.location = url(fullpath)
        false

$(document).ready ->
  $('a[data-editor]').editorLink()
