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

# This class sanitizes exception messages using the `data/message_templates.yml`
# file. This file is a hash that maps exception class names to an array of
# two-element arrays. The first element is a regex matching possible exception
# messages, and the second element is a sanitized string to be used instead of
# the exception message.
#
# This class serves two main purposes:
#
# * to reduce SQL errors to a common format free of query-specific data, so they
#   can be grouped together ({#sanitized_message}), and
# * to remove the query portion of an SQL statement, in particular sensitive
#   information ({#matched_substring}).
#
# It is not explicitly required that the error messages being matched be SQL
# errors, but those are most applicable.
#
# There are scripts in the `script` directory for updating the
# `message_templates.yml` file with updated error message text.

class MessageTemplateMatcher
  include Singleton

  # Given an error message like
  #
  # ````
  # Duplicate entry 'foo@example.com' for key 'index_users_on_email': UPDATE
  # `users` SET `name` = 'Sancho Sample', `crypted_password` = '349857346384697346',
  # `updated_at` = '2012-09-23 21:18:37', `email` = 'foo@example.com' WHERE
  # `id` = 123456 -- app/controllers/api/v1/user_controller.rb:35
  # ````
  #
  # this method returns only the error portion of the message, without replacing
  # query-specific information:
  #
  # ````
  # Duplicate entry 'foo@example.com' for key 'index_users_on_email'
  # ````
  #
  # This method is useful for removing PII that would appear in a full query but
  # not an error message.
  #
  # Returns `message` unmodified if there is no match.
  #
  # @param [String] class_name The name of the exception class.
  # @param [String] message The exception message.
  # @return [String] The exception message, error portion only, or the original
  #   message if no match was found.

  def matched_substring(class_name, message)
    format_iterator(class_name) do |rx, _|
      match = message.scan(rx).first
      return match if match
    end
    return message
  end

  # Given an error message like
  #
  # ````
  # Duplicate entry 'foo@example.com' for key 'index_users_on_email': UPDATE
  # `users` SET `name` = 'Sancho Sample', `crypted_password` = '349857346384697346',
  # `updated_at` = '2012-09-23 21:18:37', `email` = 'foo@example.com' WHERE
  # `id` = 123456 -- app/controllers/api/v1/user_controller.rb:35
  # ````
  #
  # this method returns only the error portion of the message, with all
  # query-specific information filtered:
  #
  # ````
  # Duplicate entry '[STRING]' for key '[STRING]'
  # ````
  #
  # This method is useful for removing PII and grouping similar exceptions under
  # the same filtered message.
  #
  # Returns `nil` if there is no match.
  #
  # @param [String] class_name The name of the exception class.
  # @param [String] message The exception message.
  # @return [String] The filtered exception message, or `nil` if no match was
  #   found.

  def sanitized_message(class_name, message)
    format_iterator(class_name) do |rx, replacement|
      return replacement if message =~ rx
    end
    return nil
  end

  private

  def format_iterator(class_name, &block)
    (message_templates[class_name] || []).each do |pair|
      if pair.kind_of?(String)
        format_iterator pair, &block
      elsif pair.kind_of?(Array)
        yield *pair
      end
    end
  end

  def message_templates
    @message_templates ||= @message_templates ||= YAML.load_file(Rails.root.join('data', 'message_templates.yml'))
  end
end
