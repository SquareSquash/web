# encoding: utf-8

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

# Adds methods to a view class that allow it to render backtraces in a standard
# textual style.

module TextBacktraceRendering

  # Renders a backtrace.
  #
  # @param [Array] backtrace The backtrace to render, in the format used by
  #   {Occurrence}.
  # @return [String] The rendered backtrace.

  def render_backtrace(backtrace)
    backtrace.map { |e| render_backtrace_element(e) }.join("\n")
  end

  private

  def render_backtrace_element(element)
    if element['type'].nil?
      render_normal_backtrace_element element
    else
      render_special_backtrace_element element
    end
  end

  def render_special_backtrace_element(element)
    case element['type']
      when 'address'
        "0x#{element['address'].to_s(16).rjust(8, '0').upcase}"
      when /^js:/
        render_js_backtrace_element element
      when 'obfuscated'
        format_backtrace_element element['file'], element['line'], element['symbol']
      when 'java_native'
        "#{element['class']}.#{element['symbol']} (native method)"
      when 'jruby_noline'
        format_backtrace_element element['file'], '(no line number)', element['symbol']
      when 'jruby_block'
        "(block in #{element['class']}##{element['symbol']})"
      when 'asm_invoker'
        "(ASM invoker class in #{element['file']})"
      else
        "(unknown backtrace format #{element['type']})"
    end
  end

  def render_js_backtrace_element(element)
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
    return li_text
  end

  def render_normal_backtrace_element(element)
    format_backtrace_element element['file'], element['line'], element['method']
  end
end
