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

# Change the behavior of fields with bad data. This wraps them in a span with
# data-errors attributes listing the errors. JavaScript then creates the
# appropriate visual error display.

ActionView::Base.field_error_proc = Proc.new do |html, object|
  errors = Array.wrap(object.error_message).map { |error| %(data-error="#{error}") }.join(' ')
  %(<span class="field-with-errors" #{errors}>#{html}</span>).html_safe
end
