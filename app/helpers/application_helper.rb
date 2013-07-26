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

# Helper methods mixed in to every view.

module ApplicationHelper

  # Composition of `pluralize` and `number_with_delimiter`.
  #
  # @param [Numeric] count The number of things.
  # @param [String] singular The name of the thing.
  # @param [String] plural The name of two of those things.
  # @return [String] Localized string describing the number and identity of the
  #   things.

  def pluralize_with_delimiter(count, singular, plural=nil)
    count ||= 0
    "#{number_with_delimiter count} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
  end

  # Returns a link to a Project's commit (assuming the Project has a commit link
  # format specified). The title of the link will be the commit ID (abbreviated
  # if appropriate).
  #
  # If the commit URL cannot be determined, the full SHA1 is wrapped in a `CODE`
  # tag.
  #
  # @param [Project] project The project that the commit is to.
  # @param [String] commit The full ID of the commit.
  # @return [String] A link to the commit.

  def commit_link(project, commit)
    if url = project.commit_url(commit)
      link_to commit[0, 6], url
    else
      content_tag :tt, commit[0, 6]
    end
  end

  # Creates a link to open a project file in the user's editor. See the
  # editor_link.js.coffee file for more information.
  #
  # @param [String] editor The editor ("textmate", "sublime", "vim", or
  #   "emacs").
  # @param [Project] project The project containing the file.
  # @param [String] file The file path relative to the project root.
  # @param [String] line The line number within the file.

  def editor_link(editor, project, file, line)
    content_tag :a, '', :'data-editor' => editor, :'data-file' => file, :'data-line' => line, :'data-project' => project.to_param
  end

  # Converts a number in degrees decimal (DD) to degrees-minutes-seconds (DMS).
  #
  # @param [Float] coord The longitude or latitude, in degrees.
  # @param [:lat, :lon] axis The axis of the coordinate value.
  # @param [Hash] options Additional options.
  # @option options [Fixnum] :precision (2) The precision of the seconds value.
  # @return [String] Localized display of the DMS value.
  # @raise [ArgumentError] If an axis other than `:lat` or `:lon` is given.

  def number_to_dms(coord, axis, options={})
    positive = coord >= 0
    coord = coord.abs

    degrees = coord.floor
    remainder = coord - degrees
    minutes = (remainder*60).floor
    remainder -= minutes/60.0
    seconds = (remainder*60).round(options[:precision] || 2)

    hemisphere = case axis
                   when :lat
                     t("helpers.application.number_to_dms.#{positive ? 'north' : 'south'}")
                   when :lon
                     t("helpers.application.number_to_dms.#{positive ? 'east' : 'west'}")
                   else
                     raise ArgumentError, "axis must be :lat or :lon"
                 end

    t('helpers.application.number_to_dms.coordinate', degrees: degrees, minutes: minutes, seconds: seconds, hemisphere: hemisphere)
  end

  # Given the parts of a backtrace element, creates a single string displaying
  # them together in a typical backtrace format.
  #
  # @param [String] file The file path.
  # @param [Fixnum] line The line number in the file.
  # @param [String] method The method name.

  def format_backtrace_element(file, line, method=nil)
    str = "#{file}:#{line}"
    str << " (in `#{method}`)" if method
    str
  end
end
