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

# https://github.com/rails/rails/issues/687
# HTML-unsafe characters are escaped in plaintext email templates

module ActionView
  class Template
    module Handlers
      class ERB
        def call(template)
          if template.source.encoding_aware?
            # First, convert to BINARY, so in case the encoding is
            # wrong, we can still find an encoding tag
            # (<%# encoding %>) inside the String using a regular
            # expression
            template_source = template.source.dup.force_encoding("BINARY")

            erb      = template_source.gsub(ENCODING_TAG, '')
            encoding = $2

            erb.force_encoding valid_encoding(template.source.dup, encoding)

            # Always make sure we return a String in the default_internal
            erb.encode!
          else
            erb = template.source.dup
          end

          self.class.erb_implementation.new(
              erb,
              ### PATCH
              :escape => template.identifier !~ /\.html/,
              ### END PATCH
              :trim   => (self.class.erb_trim_mode == "-")
          ).src
        end
      end
    end
  end
end
