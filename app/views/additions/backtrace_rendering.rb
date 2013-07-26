# encoding: utf-8

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

# Adds methods to a view class that allow it to render backtraces in a standard
# style.

module BacktraceRendering
  protected

  # Renders a list of backtraces.
  #
  # @param [Array<Hash>] backtraces The backtraces to render, in the format
  #   used by {Occurrence}.
  # @param [String] identifier A unique string to use to build the DOM IDs of
  #   the rendered elements.

  def render_backtraces(backtraces, identifier)
    p(style: 'text-align: right') do
      input type: 'checkbox', class: 'show-library-files', id: 'show-library-files', checked: 'checked'
      label "Show library files in backtrace", for: 'show-library-files', style: 'display: inline'
    end

    if !@occurrence.symbolicated? && !@occurrence.symbolication
      p "Portions of the backtrace have not yet been symbolicated. If you would like a meaningful backtrace, please upload a symbolication file using your language’s client library.", class: 'alert info'
    end
    if !@occurrence.sourcemapped? #&& !@occurrence.source_map
      p "Portions of the backtrace have not yet been source-mapped. If you would like a meaningful backtrace, please upload a JavaScript source map using the Squash JavaScript client library.", class: 'alert info'
    end
    unless @occurrence.deobfuscated?
      p "Portions of the backtrace contain obfuscated Java code. If you would like a more meaningful backtrace, please upload a renamelog file using the Squash Java Ruby gem.", class: 'alert info'
    end

    ul(class: 'pills backtrace-tabs') do
      backtraces.each_with_index do |bt, index|
        li(class: (bt['faulted'] ? 'active' : nil)) { a bt['name'], href: "#backtrace-#{identifier}-#{index}", rel: 'tab', class: (bt['faulted'] ? 'faulted' : nil) }
      end
    end

    div(class: 'tab-content') do
      backtraces.each_with_index do |bt, index|
        render_backtrace bt, identifier, index
      end
    end
  end

  private

  def render_backtrace(bt, identifier, index)
    div(id: "backtrace-#{identifier}-#{index}", class: (bt['faulted'] ? 'active' : nil)) do
      p("This thread raised or crashed.", class: 'alert info') if bt['faulted']

      ul(class: 'backtrace') do
        bt['backtrace'].each_with_index do |element, lindex|
          render_backtrace_element element, identifier, index, lindex
        end
      end

      if bt['registers']
        h4 "Registers"
        render_registers bt['registers']
      end
    end
  end

  def render_backtrace_element(element, identifier, index, lindex)
    if element['type'].nil?
      render_normal_backtrace_element element, identifier, index, lindex
    else
      render_special_backtrace_element element, identifier, index, lindex
    end
  end

  def render_special_backtrace_element(element, identifier, index, lindex)
    case element['type']
      when 'address'
        li "0x#{element['address'].to_s(16).rjust(8, '0').upcase}", class: 'lib long-words'
      when 'minified'
        render_minified_backtrace_element element, identifier, index, lindex
      when 'obfuscated'
        li format_backtrace_element(element['file'], element['line'], element['symbol']), class: 'lib long-words'
      when 'java_native'
        li "#{element['class']}.#{element['symbol']} (native method)", class: 'lib long-words'
      when 'jruby_noline'
        li format_backtrace_element(element['file'], '(no line number)', element['symbol']), class: 'lib long-words'
      when 'jruby_block'
        li "(block in #{element['class']}##{element['symbol']})", class: 'lib long-words'
      when 'asm_invoker'
        li "(ASM invoker class in #{element['file']})", class: 'lib long-words'
      else
        li "(unknown backtrace format #{element['type']})", class: 'lib long-words'
    end
  end

  def render_minified_backtrace_element(element, identifier, index, lindex)
    line_portion = if element['line'] && element['column'] then
                     "#{element['line']}:#{element['column']}"
                   elsif element['line'] then
                     element['line'].to_s
                   else
                     nil
                   end
    li_text      = element['url']
    li_text << " : " << line_portion if line_portion
    li_text << " (in #{element['symbol']})" if element['symbol']
    if element['context']
      li do
        p { a li_text, href: "#backtrace-#{identifier}-#{index}-info-#{lindex}", class: 'backtrace-link long-words' }
        div(id: "backtrace-#{identifier}-#{index}-info-#{lindex}", style: 'display: none') do
          pre_class  = "brush: js; toolbar: false; unindent: false"
          line_count = element['context'].size
          if element['line']
            first_line = element['line'] - line_count/2
            pre_class << "; ruler: true; first-line: " << first_line.to_s << "; highlight: " << (first_line + line_count/2).to_s
          else
            pre_class << "; ruler: false; highlight: " << line_count/2 + 1
          end
          pre element['context'].join("\n"), class: pre_class
        end
      end
    else
      li li_text, class: 'long-words'
    end
  end

  def render_normal_backtrace_element(element, identifier, index, lindex)
    if @project.path_type(element['file']) == :library
      li format_backtrace_element(element['file'], element['line'], element['method']), class: 'lib long-words'
    else
      li(class: (@project.path_type(element['file']) == :filtered ? 'filtered' : nil)) do
        p { a format_backtrace_element(element['file'], element['line'], element['method']), href: "#backtrace-#{identifier}-#{index}-info-#{lindex}", class: 'backtrace-link long-words' }
        div(id: "backtrace-#{identifier}-#{index}-info-#{lindex}", style: 'display: none') do
          blockquote do
            text! editor_link 'textmate', @project, element['file'], element['line']; br
            text! editor_link 'sublime', @project, element['file'], element['line']; br
            text! editor_link 'vim', @project, element['file'], element['line']; br
            text! editor_link 'emacs', @project, element['file'], element['line']
          end
          pre class: 'context', :'data-project' => @project.to_param, :'data-revision' => @occurrence.revision, :'data-file' => element['file'], :'data-line' => element['line']
        end
      end
    end
  end

  def render_registers(registers)
    table(class: 'sortable') do
      registers.each do |(name, value)|
        tr do
          td name
          td { samp "0x#{value.to_s(16).rjust(8, '0').upcase}" }
        end
      end
    end
  end
end
