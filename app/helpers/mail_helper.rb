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

# Helper methods for email content.

module MailHelper
  # The typical maximum line width for plaintext emails (per RFC 2822).
  EMAIL_WRAP_WIDTH = 78

  # Quotes a text block for email use. Adds chevron(s) and a space before each
  # line. Rewraps the content only as necessary to keep total width at 78
  # characters: Other line breaks are preserved.
  #
  # @param [String] text The text to quote.
  # @param [Fixnum] level The quote level.
  # @return [String] The quoted text.

  def email_quote(text, level=1)
    width = EMAIL_WRAP_WIDTH - level - 1

    lines = word_wrap(text, line_width: width).split("\n")
    lines.map!(&:lstrip)
    lines.map! { |line| '>'*level + ' ' + line }
    lines.join("\n")
  end

  # Rewraps content for email use. Double line breaks are considered to be new
  # paragraphs. Single line breaks are considered to be wraps and are replaced
  # with spaces. New line breaks are added as necessary.
  #
  # @param [String] text The text to rewrap.
  # @param [Fixnum] width The new width to wrap to.
  # @return [String] The rewrapped text.

  def email_rewrap(text, width=EMAIL_WRAP_WIDTH)
    paragraphs = text.split("\n\n")
    paragraphs.each { |para| para.gsub("\n", ' ') }
    paragraphs.map! { |para| email_wrap para, width }
    paragraphs.join("\n\n")
  end

  # Wraps content for email use. Similar to {#email_rewrap}, but existing line
  # breaks are preserved. New line breaks are added as necessary to keep total
  # line width under `width`.
  #
  # @param [String] text The text to wrap.
  # @param [Fixnum] width The new width to wrap to.
  # @return [String] The wrapped text.

  def email_wrap(text, width=EMAIL_WRAP_WIDTH)
    lines = word_wrap(text, line_width: width).split("\n")
    lines.map!(&:lstrip)
    lines.join("\n")
  end
end
