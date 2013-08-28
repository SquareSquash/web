# encoding: utf-8

# Copyright 2012 Cerner Corp.
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

# Adds methods to a view class that allow it to render Crash Logs in a standard
# style.

module CrashlogRendering
  protected

  # Renders a Crash Log.
  #
  # @param [String] crash_log The Crash Log to render, in the format
  #   used by {Occurrence}.

  def render_crash_log(crash_log)

    h4 "Crash Log"
      div(id:'crash_log') do
         text raw ("<pre>#{crash_log}</pre>")
    end
  end


end

