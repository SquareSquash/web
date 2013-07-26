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

root = exports ? this

# Converts a number like 1234 (or a string) into a string like "1,234". Works
# with decimals.
#
# @param [Integer] number A number like 1234.
# @return [String] A string like "1,234".
#
root.numberWithDelimiter = (number) ->
  parts = ("#{number}").split('.')
  parts[0] = parts[0].replace(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1,")
  parts.join('.')

# Given a count of things, determines whether to use the singular or plural
# form. Returns a string consisting of the count and the correct noun form.
#
# @example
#   pluralize(2, 'duck', 'ducks') #=> "2 ducks"
#
# @param [Integer] count The number of things.
# @param [String] singular The name of one such thing.
# @param [String] plural The name of two or more such things.
# @return [String] A string describing the thing(s) and its/their quantity.
#
root.pluralize = (count, singular, plural) ->
  "#{count || 0} " + (if count == 1 || count.match(/^1(\.0+)?$/) then singular else plural)

# Converts a Date (or integer timestamp) into a rough human-readable
# approximation.  BYO "ago" or other suffix.
#
# @example
#   timeAgoInWords(1331697706) #=> "about 5 minutes"
#
# @param [Date, Integer] from_time The start of the time interval.
# @param [Boolean] include_seconds Whether to specify sub-minute intervals.
# @return [String] A description of the time interval.
# @see #distanceOfTimeInWords
#
root.timeAgoInWords = (from_time, include_seconds=false) ->
  distanceOfTimeInWords from_time, new Date(), include_seconds

# Converts a time interval between two Dates (or integer timestamps) into a
# rough approximation.
#
# @example
#   distanceOfTimeInWords(1331697706, 1331659274) #=> "about 1 minute"
#
# @param [Date, Integer] from_time The start of the time interval.
# @param [Date, Integer] to_time The end of the time interval.
# @param [Boolean] include_seconds Whether to specify sub-minute intervals.
# @return [String] A description of the time interval.
#
root.distanceOfTimeInWords = (from_time, to_time, include_seconds=false) ->
  from_time = new Date(from_time) if typeof from_time == 'number'
  to_time = new Date(to_time) if typeof to_time == 'number'
  distance_in_minutes = Math.round(Math.abs(to_time.getTime() - from_time.getTime()) / 60000)
  distance_in_seconds = Math.round(Math.abs(to_time.getTime() - from_time.getTime()) / 1000)

  if distance_in_minutes >= 0 && distance_in_minutes <= 1
    (return if distance_in_minutes == 0 then "less than 1 minute" else "about 1 minute") unless include_seconds
    if distance_in_seconds >= 0 && distance_in_seconds <= 4 then return "less than 5 seconds"
    else if distance_in_seconds >= 5 && distance_in_seconds <= 9 then return "less than 10 seconds"
    else if distance_in_seconds >= 10 && distance_in_seconds <= 19 then return "less than 20 seconds"
    else if distance_in_seconds >= 20 && distance_in_seconds <= 39 then return "half a minute"
    else if distance_in_seconds >= 40 && distance_in_seconds <= 59 then return "less than 1 minute"
    else "about 1 minute"
  else if distance_in_minutes >= 2 && distance_in_minutes <= 44 then return "about #{distance_in_minutes} minutes"
  else if distance_in_minutes >= 45 && distance_in_minutes <= 89 then return "about 1 hour"
  else if distance_in_minutes >= 90 && distance_in_minutes <= 1439 then return "about #{Math.round(distance_in_minutes / 60.0)} hours"
  else if distance_in_minutes >= 1440 && distance_in_minutes <= 2519 then return "about 1 day"
  else if distance_in_minutes >= 2520 && distance_in_minutes <= 43199 then return "about #{Math.round(distance_in_minutes / 1440.0)} days"
  else if distance_in_minutes >= 43200 && distance_in_minutes <= 86399 then return "about 1 month"
  else if distance_in_minutes >= 86400 && distance_in_minutes <= 525599 then return "about #{Math.round(distance_in_minutes / 43200.0)} months"
  else
    fyear = from_time.getYear()
    if from_time.getMonth() >= 3 then fyear += 1
    tyear = to_time.getYear()
    if to_time.getMonth() < 3 then tyear -= 1
    leap_years = if fyear <= tyear then 0 else (y for y in [fyear..tyear] when isLeapYear(y)).length
    minute_offset_for_leap_year = leap_years * 1440
    minutes_with_offset = distance_in_minutes - minute_offset_for_leap_year
    remainder = minutes_with_offset % 525600
    distance_in_years = Math.round(minutes_with_offset / 525600)
    if remainder < 131400
      "about #{distance_in_years} years"
    else if remainder < 394200
      "over #{distance_in_years} years"
    else
      "almost #{distance_in_years + 1} years"

# Returns whether or not the given year is a leap year.
#
# @example
#   isLeapYear(2013) #=> true
#
# @param [Integer] year The year.
# @return [true, false] Whether it was a leap year.
#
root.isLeapYear = (year) ->
  year % 4 == 0 && year % 100 != 0 || year % 400 == 0

# Sanitizes a string for use in Bourne-style shells.
#
# @param [String] str A string.
# @return [String] The sanitized and escaped string.
#
root.shellEscape = (str) ->
  if str == '' then return "''"
  str.replace(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\$1").replace(/\n/, "'\n'")

# Converts an array of strings into a sentence with an Oxford comma.
#
# @param [Array] ary An array of strings.
# @return [String] The sentence form.
#
root.toSentence = (ary) ->
  if ary.length == 0
    ""
  else if ary.length == 1
    ary[0]
  else if ary.length == 2
    "#{ary[0]} and #{ary[1]}"
  else
    "#{ary[0...-1].join(', ')}, and #{ary[-1]}"

# Truncates a string with options for omission and breaking.
#
# @param [String] str A string to truncate.
# @param [Object] options Truncation options.
# @option options [Integer] length (30) The length to truncate the string to.
# @option options [String] omission ("…") The string to append to a truncated
#   string.
# @option options [String] separator If provided, breaks the string only on this
#   separator.
root.truncate = (str, options) ->
  options = $.extend(options, {length: 30, omission: "…"})
  length_with_room_for_omission = str.length - options.omission.length
  stop = if options.separator
      str.lastIndexOf(options.separator, length_with_room_for_omission) || length_with_room_for_omission
    else
      length_with_room_for_omission
  if str.length > options.length then str[0...stop] + options.omission else str

# Serializes a form into a Hash object.
jQuery.fn.serializeObject = ->
  object = {}
  pairs = $(this[0]).serializeArray()
  for pair in pairs
    do (pair) ->
      if object[pair.name]
        if !object[pair.name].push
          object[pair.name] = [object[pair.name]]
        object[pair.name].push(pair.value || '')
      else
        object[pair.name] = (pair.value || '')
  object
