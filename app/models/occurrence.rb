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

# An individual occurrence of a {Bug}, or put another way, a single instance of
# an exception occurring and being recorded. Occurrences record all relevant
# information about the exception itself and the state of the program when the
# exception occurred.
#
# Most of this data is part of the metadata column and is therefore schemaless.
# Rather than tailoring the fields to one particular class of projects (e.g.,
# Rails apps), new fields can be easily added to fit any type of project.
#
# Occurrences can also have `user_data`. This is typically added at runtime by
# the code when the exception is raised, and provides freeform contextual data
# relevant to the error.
#
# There are a number of SQL triggers and rules to ensure cached counters and
# similar fields are kept in sync between {Bug Bugs} and Occurrences; see the
# migration for further information.
#
# Like {Comment Comments}, each Occurrence is assigned a `number` in sequence
# among other occurrences of the same Bug. This number is used when referring to
# Occurrences, providing more useful information than the ID.
#
# Backtraces, concurrency, and symbolication
# ------------------------------------------
#
# Each Occurrence has multiple backtraces, one for each thread or other unit of
# execution (client specific). These backtraces can appear in one of two
# formats:
#
# ### Current format
#
# The current backtrace format is an array of hashes. Each hash has the
# following keys:
#
# | Key         | Required | Description                                                               |
# |:------------|:---------|:--------------------------------------------------------------------------|
# | `name`      | yes      | A name for the thread or fiber.                                           |
# | `faulted`   | yes      | If `true`, this is the thread or fiber in which the exception was raised. |
# | `backtrace` | yes      | The stack trace for this thread or fiber.                                 |
# | `registers` | no       | The value of the registers for this thread (hash).                        |
#
# The `backtrace` value is an array of hashes, one per line of the backtrace,
# ordered from outermost stack element to innermost. Each hash can have the
# following keys (all are required):
#
# |          |                                                     |
# |:---------|:----------------------------------------------------|
# | `file`   | The file name.                                      |
# | `line`   | The line number in the file.                        |
# | `symbol` | The name of the method containing that line number. |
#
# #### Special backtraces
#
# For certain special stack trace lines, a `type` field will be present
# indicating the type of special stack trace line this is. If the `type` field
# is present, other fields will appear alongside it.
#
# For unsymbolicated backtrace lines, the `type` field will be **address** and
# the only other field will be named "address" and will be the integer stack
# trace return address. Unsymbolicated backtrace lines can be symbolicated by
# calling {#symbolicate}, assuming an appropriate {Symbolication} is available.
#
# For un-sourcemapped JavaScript lines, the `type` field will be **minified**
# and the other fields will be:
#
# |           |                                                                    |
# |:----------|:-------------------------------------------------------------------|
# | `url`     | The URL of the minified JavaScript asset.                          |
# | `line`    | The line number in the minified file.                              |
# | `column`  | The column number in the minified file.                            |
# | `symbol`  | The minified method or function name.                              |
# | `context` | An array of strings containing the lines of code around the error. |
#
# Some elements will be `nil` depending on browser support. Un-sourcemapped
# lines can be source-mapped by calling {#sourcemap}, assuming an appropriate
# {SourceMap} is available.
#
# For obfuscated Java backtrace lines, the `type` field will be **obfuscated**
# and the other fields will be (all are required):
#
# |          |                                                         |
# |:---------|:--------------------------------------------------------|
# | `file`   | The obfuscated file name without path (e.g., "A.java"). |
# | `line`   | The line number within that file.                       |
# | `symbol` | The method name (can be obfuscated).                    |
# | `class`  | The class name (can be obfuscated).                     |
#
# Obfuscated backtrace lines can be de-obfuscated by calling {#deobfuscate},
# assuming an appropriate {ObfuscationMap} is available.
#
# ### Legacy format
#
# Older client libraries may report backtraces in this format:
#
# ```` ruby
# [
#   ["Thread 0", true, [
#      ["file/path.rb", 123, "method_name"],
#      ...
#   ]],
#   ...
# ]
# ````
#
# So, the outermost array is a list of threads. Each entry in that array has
# three elements:
#
# * the name of the thread (client-specific),
# * whether or not the thread was responsible for the exception, and
# * the backtrace array.
#
# Each element of the backtrace array is an array consisting of
#
# * the file path (relative to the project root for non-library files),
# * the line number, and
# * the method or function name (or `nil`).
#
# For certain special cases, this array will consist of other than three
# elements. These special cases are:
#
# #### Unsymbolicated backtrace lines
#
# If a line in the backtrace is not yet symbolicated, it is stored in a different
# format. Each unsymbolicated line of a backtrace becomes a _two_-element array.
# The first element is the constant "_RETURN_ADDRESS_", and the second is an
# integer stack trace return address.
#
# Unsymbolicated backtrace lines can be symbolicated by calling {#symbolicate},
# assuming an appropriate {Symbolication} is available.
#
# #### Un-sourcemapped JavaScript files
#
# If a line in a backtrace corresponds to a JavaScript asset that has not yet
# been mapped to an un-minified source file, it is stored as a six-element
# array:
#
# 0. the constant "_JS_ASSET_",
# 1. the URL of the JavaScript source file,
# 2. the line number,
# 3. the column number,
# 4. the function name, and
# 5. the context (an array of strings [lines of code around the error])
#
# Some elements will be `nil` depending on browser support. Un-sourcemapped
# lines can be source-mapped by calling {#sourcemap}, assuming an appropriate
# {SourceMap} is available.
#
# #### Obfuscated Java files
#
# Java backtraces do not contain the full file path, and the class name can be
# obfuscated using yGuard. If a line in a backtrace comes from a Java stack
# trace, it is stored as a five-element array:
#
# 0. the constant "_JAVA_",
# 1. the name of the source file (can be obfuscated; e.g., "A.java"),
# 2. the line number
# 3. the method name (can be obfuscated), and
# 4. the class name.
#
# Obfuscated backtrace lines can be de-obfuscated by calling {#deobfuscate},
# assuming an appropriate {ObfuscationMap} is available.
#
# Nesting
# -------
#
# This class can record exceptions that have been nested underneath one or more
# parent exceptions, a paradigm that can be seen occasionally in Ruby (e.g.,
# `ActionView::TemplateError`) and far too frequently in Java. It is up to the
# individual client libraries to detect and record nesting parents.
#
# If an exception was nested underneath parent(s), the `parent_exceptions`
# property should be an array of hashes, each hash representing a parent
# exception, ordered from innermost to outermost parent. Each hash takes the
# following keys:
#
# * `class_name` (the name of the exception class)
# * `message`
# * `backtraces`
# * `ivars`
# * `association` (the name of the instance variable containing the inner
#   exception, or some other identifier as to how the two exceptions are
#   associated)
#
# The values for these keys are the same as is described in _Global Fields_
# below unless otherwise specified. The `association` field is optional.
#
# Truncation
# ----------
#
# Because Occurrences store a lot of information, it may be necessary to
# truncate older records. Truncation removes all metadata, leaving only the
# revision, date, and client information. It helps free up space by discarding
# possibly redundant information.
#
# You can truncate Occurrences with the {#truncate!} and {.truncate!} methods.
#
# Redirection
# -----------
#
# It may be the case that an Occurrence needs to move from one Bug to another,
# as for example, when symbolication occurs after an Occurrence is saved, and
# the symbolication reveals that the Occurrence should belong to a different
# Bug.
#
# In this case, a new duplicate Occurrence is created under the correct Bug,
# this Occurrence is truncated, and marked as a redirect. In the front-end,
# visitors to this Occurrence will be redirected to the correct Occurrence.
#
# Unfortunately, the old, truncated Occurrence remains attached to the old
# (incorrect) Bug, negatively impacting that Bug's statistics. No solution for
# this problem has been written.
#
# Redirection should be done with the {#redirect_to!} method.
#
# Associations
# ============
#
# |                 |                                                                           |
# |:----------------|:--------------------------------------------------------------------------|
# | `bug`           | The {Bug} this is an occurrence of.                                       |
# | `symbolication` | The {Symbolication} for the backtraces (if available, and if applicable). |
#
# Properties
# ==========
#
# |               |                                                                             |
# |:--------------|:----------------------------------------------------------------------------|
# | `revision`    | The revision of the {Project} at the point this occurrence happened.        |
# | `number`      | A consecutively incrementing value among other Occurrences of the same Bug. |
# | `occurred_at` | The time at which this occurrence happened.                                 |
# | `client`      | The client library that sent the occurrence (Rails, iOS, Android, etc.).    |
# | `crashed`     | If true, the exception was not caught and resulted in a crash.              |
#
# Metadata
# ========
#
# Global Fields
# -------------
#
# |                     |                                                                                                 |
# |:--------------------|:------------------------------------------------------------------------------------------------|
# | `message`           | The error or exception message.                                                                 |
# | `backtraces`        | Each thread's backtrace (see above).                                                            |
# | `ivars`             | The exception's instance variables.                                                             |
# | `user_data`         | Any additional annotated data sent with the exception.                                          |
# | `parent_exceptions` | Information on any parent exceptions that this exception was nested under. See _Nesting_ above. |
#
# Host Platform
# -------------
#
# |             |                                                              |
# |:------------|:-------------------------------------------------------------|
# | `arguments` | The launch arguments, as a string.                           |
# | `env_vars`  | A hash of the names and values of the environment variables. |
# | `pid`       | The PID of the process that raised the exception.            |
#
# Server Applications
# -------------------
#
# |            |                               |
# |:-----------|:------------------------------|
# | `root`     | The path to the project root. |
# | `hostname` | The computer's hostname.      |
#
# Client Applications
# -------------------
#
# |                    |                                                                        |
# |:-------------------|:-----------------------------------------------------------------------|
# | `version`          | The human version number of the application.                           |
# | `build`            | The machine version number of the application.                         |
# | `device_id`        | An ID number unique to the specific device.                            |
# | `device_type`      | A string identifying the device make and model.                        |
# | `operating_system` | The name of the operating system the application was running under.    |
# | `os_version`       | The human-readable version number of the operating system.             |
# | `os_build`         | The build number of the operating system.                              |
# | `physical_memory`  | The amount of memory on the client platform, in bytes.                 |
# | `symbolication_id` | The UUID for the symbolication data.                                   |
# | `architecture`     | The processor architecture of the device (e.g., "i386").               |
# | `parent_process`   | The name of the process that launched this process.                    |
# | `process_native`   | If `false`, the process was running under an emulator (e.g., Rosetta). |
# | `process_path`     | The path to the application on disk.                                   |
#
# Geolocation Data
# ----------------
#
# |                      |                                                                                                                                                                  |
# |:---------------------|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------|
# | `lat`                | The latitude, in degrees decimal.                                                                                                                                |
# | `lon`                | The longitude, in degrees decimal.                                                                                                                               |
# | `altitude`           | The altitude, in meters above sea level.                                                                                                                         |
# | `location_precision` | A number describing the 2D precision of the location fix (device-specific).                                                                                      |
# | `heading`            | The magnetic heading of the device, in degrees decimal. For some devices, this is compass orientation; for others, vector angle of first derivative of position. |
# | `speed`              | Velocity of the device, in meters per second.                                                                                                                    |
#
# Mobile Devices
# --------------
#
# |                    |                                                                       |
# |:-------------------|:----------------------------------------------------------------------|
# | `network_operator` | The network operator (e.g., AT&T).                                    |
# | `network_type`     | The data network type (e.g., 4G-LTE).                                 |
# | `connectivity`     | Connectivity source (e.g., cellular or wi-fi).                        |
# | `power_state`      | The charging/power state (e.g., charging). Platform-specific string.  |
# | `orientation`      | The device's orientation (e.g., landscape). Platform-specific string. |
#
# HTTP
# ----
#
# |                  |                                                            |
# |:-----------------|:-----------------------------------------------------------|
# | `request_method` | The HTTP request method (e.g., "GET").                     |
# | `schema`         | The schema of the request URL (e.g., "http").              |
# | `host`           | The host portion of the request URL.                       |
# | `port`           | The port on which the request sent.                        |
# | `path`           | The path portion of the request URL, with leading "/".     |
# | `query`          | The query portion of the request URL, without leading "?". |
# | `fragment`       | The anchor portion of the URL, without leading "#".        |
# | `headers`        | A hash of header names and values for the request.         |
#
# Ruby on Rails
# -------------
#
# |              |                                            |
# |:-------------|:-------------------------------------------|
# | `controller` | The Rails controller handling the request. |
# | `action`     | The Rails action that was invoked.         |
# | `params`     | The contents of the `params` hash.         |
# | `session`    | The contents of the `session` hash.        |
# | `flash`      | The contents of the `flash` hash.          |
# | `cookies`    | The contents of the `cookies` hash.        |
#
# Android
# -------
#
# |          |                                        |
# |:---------|:---------------------------------------|
# | `rooted` | If `true`, the device has been rooted. |
#
# Web Browser
# -----------
#
# |                          |                                                         |
# |:-------------------------|:--------------------------------------------------------|
# | `browser_name`           | The name of the Web browser (e.g., "Safari").           |
# | `browser_version`        | The browser version (e.g., "5.1.5").                    |
# | `browser_engine`         | The rendering engine (e.g., "webkit").                  |
# | `browser_os`             | The client's operating system (e.g., "Mac OS X").       |
# | `browser_engine_version` | The version of the rendering engine (e.g., "534.55.3"). |
#
# Web Browser Platform
# --------------------
#
# |                 |                                                                       |
# |:----------------|:----------------------------------------------------------------------|
# | `screen_width`  | The width of the device displaying the browser window, in pixels.     |
# | `screen_height` | The height of the device displaying the browser window, in pixels.    |
# | `window_width`  | The width of the browser window at the time of exception, in pixels.  |
# | `window_height` | The height of the browser window at the time of exception, in pixels. |
# | `color_depth`   | The color bit depth of the device displaying the browser window.      |

class Occurrence < ActiveRecord::Base
  belongs_to :bug, inverse_of: :occurrences
  belongs_to :symbolication, primary_key: 'uuid', inverse_of: :occurrences
  belongs_to :redirect_target, class_name: 'Occurrence', foreign_key: 'redirect_target_id', inverse_of: :redirected_occurrence
  has_one :redirected_occurrence, class_name: 'Occurrence', foreign_key: 'redirect_target_id', inverse_of: :redirect_target, dependent: :destroy

  include HasMetadataColumn
  has_metadata_column(
      # Universal
      message:                {presence: true, length: {maximum: 1000}},
      backtraces:             {type: Array, presence: true},
      ivars:                  {type: Hash, allow_nil: true},
      user_data:              {type: Hash, allow_nil: true},
      parent_exceptions:      {type: Array, allow_nil: true},

      # Universal - Host platform
      arguments:              {allow_nil: true},
      env_vars:               {type: Hash, allow_nil: true},
      pid:                    {type: Fixnum, numericality: {only_integer: true, greater_than: 0}, allow_nil: true},
      parent_process:         {length: {maximum: 150}, allow_nil: true},
      process_native:         {type: Boolean, allow_nil: true},
      process_path:           {length: {maximum: 1024}, allow_nil: true},

      # Universal - User identification
      user_id:                {length: {maximum: 256}, allow_nil: true},

      # Server apps
      root:                   {length: {maximum: 500}, allow_nil: true},
      hostname:               {length: {maximum: 255}, allow_nil: true},

      # Client apps
      version:                {length: {maximum: 50}, allow_nil: true},
      build:                  {length: {maximum: 50}, allow_nil: true},
      device_id:              {length: {maximum: 150}, allow_nil: true},
      device_type:            {length: {maximum: 150}, allow_nil: true},
      operating_system:       {length: {maximum: 50}, allow_nil: true},
      os_build:               {length: {maximum: 50}, allow_nil: true},
      os_version:             {length: {maximum: 50}, allow_nil: true},
      physical_memory:        {type: Fixnum, numericality: {only_integer: true, greater_than: 0}, allow_nil: true},
      architecture:           {length: {maximum: 50}, allow_nil: true},

      # Geolocation
      lat:                    {type: Float, numericality: {within: -90..90}, allow_nil: true},
      lon:                    {type: Float, numericality: {within: -180..180}, allow_nil: true},
      altitude:               {type: Float, numericality: true, allow_nil: true},
      location_precision:     {type: Float, numericality: true, allow_nil: true},
      heading:                {type: Float, numericality: {within: 0..360}, allow_nil: true},
      speed:                  {type: Float, numericality: true, allow_nil: true},

      # Mobile
      network_operator:       {length: {maximum: 100}, allow_nil: true},
      network_type:           {length: {maximum: 50}, allow_nil: true},
      connectivity:           {length: {maximum: 50}, allow_nil: true},
      power_state:            {length: {maximum: 100}, allow_nil: true},
      orientation:            {length: {maximum: 100}, allow_nil: true},

      # HTTP
      request_method:         {length: {maximum: 50}, allow_nil: true},
      schema:                 {length: {maximum: 50}, allow_nil: true},
      host:                   {length: {maximum: 255}, allow_nil: true},
      port:                   {type: Fixnum, allow_nil: true},
      path:                   {length: {maximum: 500}, allow_nil: true},
      query:                  {length: {maximum: 255}, allow_nil: true},
      fragment:               {length: {maximum: 255}, allow_nil: true},
      headers:                {type: Hash, allow_nil: true},

      # Ruby on Rails
      controller:             {length: {maximum: 100}, allow_nil: true},
      action:                 {length: {maximum: 100}, allow_nil: true},
      params:                 {type: Hash, allow_nil: true},
      session:                {type: Hash, allow_nil: true},
      flash:                  {type: Hash, allow_nil: true},
      cookies:                {type: Hash, allow_nil: true},

      # Android
      rooted:                 {type: Boolean, allow_nil: true},

      # Browser
      browser_name:           {length: {maximum: 50}, allow_nil: true},
      browser_version:        {length: {maximum: 50}, allow_nil: true},
      browser_engine:         {length: {maximum: 50}, allow_nil: true},
      browser_os:             {length: {maximum: 50}, allow_nil: true},
      browser_engine_version: {length: {maximum: 50}, allow_nil: true},

      # Browser Platform
      screen_width:           {type: Integer, allow_nil: true},
      screen_height:          {type: Integer, allow_nil: true},
      window_width:           {type: Integer, allow_nil: true},
      window_height:          {type: Integer, allow_nil: true},
      color_depth:            {type: Integer, allow_nil: true}
  )

  attr_readonly :bug, :revision, :number, :occurred_at

  # Fields that cannot be used by the aggregation view. These are fields with a
  # a continuous range of possible values, or fields with unusual data types.
  NON_AGGREGATING_FIELDS = %w( number message backtraces ivars arguments env_vars
                               user_data parent_exceptions headers params fragment
                               session flash cookies id bug_id metadata lat lon
                               altitude location_precision heading speed
                               user_id occurred_at root symbolication_id
                               redirect_target_id )
  # Fields that can be used by the aggregation view.
  AGGREGATING_FIELDS = (Occurrence.columns.map(&:name) rescue []) + Occurrence.metadata_column_fields.keys.map(&:to_s) - NON_AGGREGATING_FIELDS

  validates :bug,
            presence: true
  validates :revision,
            presence: true,
            length:   {is: 40},
            format:   {with: /\A[0-9a-f]+\z/}
  #validates :number,
  #          presence:     true,
  #          numericality: {only_integer: true, greater_than: 0},
  #          uniqueness:   {scope: :bug_id}
  validates :occurred_at,
            presence:   true,
            timeliness: {type: :time}

  set_nil_if_blank :user_id, :root, :hostname, :version, :device_id,
                   :device_type, :operating_system, :network_operator,
                   :network_type, :connectivity, :schema, :host, :path, :query,
                   :controller, :action, :browser_name, :browser_version,
                   :browser_engine, :browser_os, :browser_engine_version
  before_validation(on: :create) { |obj| obj.revision = obj.revision.downcase if obj.revision }
  after_create :reload # grab the number value after the rule has been run
  before_create :symbolicate

  # @return [URI::Generic] The URL of the Web request that resulted in this
  #   Occurrence.

  def url
    @url ||= begin
      return nil unless web?
      return nil unless URI.scheme_list.include?(schema.upcase)
      URI.scheme_list[schema.upcase].build(host: host, port: port, path: path, query: query, fragment: fragment)
    end
  end

  # @return [Array<Hash>] The backtrace in `backtrace` that is at fault.

  def faulted_backtrace
    bt = backtraces.detect { |b| b['faulted'] }
    bt ? bt['backtrace'] : []
  end

  # @return [true, false] Whether or not this exception was nested under one or
  #   more parents.

  def nested?() parent_exceptions.present? end

  # @return [Array<Hash>] The `parent_exceptions` array with the innermost
  #   exception (the exception around which this Occurrence was created)
  #   prepended.

  def exception_hierarchy
    [{'class_name' => bug.class_name, 'message' => message, 'backtraces' => backtraces, 'ivars' => ivars}] + (parent_exceptions || [])
  end

  # @return [Hash<String, Object>] Any metadata fields that are not defined in
  #   the `has_metadata_column` call.

  def extra_data
    _metadata_hash.except(*self.class.metadata_column_fields.keys.map(&:to_s))
  end

  # @return [true, false] Whether or not this Occurrence has Web request
  #   information.

  def web?
    schema? && host? && path?
  end

  # @return [tue, false] Whether or not this Occurrence has server-side Web
  #   request information.

  def request?
    params? || headers?
  end

  # @return [true, false] Whether or not this Occurrence has Rails information.

  def rails?
    client == 'rails' && controller && action
  end

  # @return [true, false] Whether or not this Occurrence has user data or
  #   instance variables.

  def additional?
    user_data.present? || extra_data.present? || ivars.present?
  end

  # @return [true, false] Whether or not this exception occurred as part of an
  #   XMLHttpRequest (Ajax) request.

  def xhr?
    headers && headers['XMLHttpRequest'].present?
  end

  # @return [true, false] Whether this Occurrence contains information about the
  #   hosted server on which it occurred.

  def server?
    hostname && pid
  end

  # @return [true, false] Whether this Occurrence contains information about the
  #   client platform on which it occurred.

  def client?
    build && device_type && operating_system
  end

  # @return [true, false] Whether this Occurrence contains client geolocation
  #   information.

  def geo?
    lat && lon
  end

  # @return [true, false] Whether this Occurrence contains mobile network
  #   information.

  def mobile?
    network_operator && network_type
  end

  # @return [true, false] Whether this Occurrence contains Web browser
  #   user-agent information.

  def browser?
    browser_name && browser_version
  end

  # @return [true, false] Whether this Occurrence contains Web browser platform
  #   information.

  def screen?
    (window_width && window_height) || (screen_width && screen_height)
  end

  # @private
  def to_param() number.to_s end

  # @return [String] Localized, human-readable name. This duck-types this class
  #   for use with breadcrumbs.

  def name
    I18n.t 'models.occurrence.name', number: number
  end

  # Truncates this Occurrence and saves it. Does nothing if the occurrence has
  # already been truncated. All metadata will be erased to save space.

  def truncate!
    return if truncated?
    update_column :metadata, nil
  end

  # @return [true, false] Whether this occurrence has been truncated.

  def truncated?
    metadata.nil?
  end

  # Truncates a group of Occurrences.
  #
  # @param [ActiveRecord::Relation] scope The Occurrences to truncate.
  # @see #truncate!

  def self.truncate!(scope)
    scope.update_all metadata: nil
  end

  # Redirects this Occurrence to a given Occurrence. See the class docs for a
  # description of redirection. Also truncates the Occurrence and saves the
  # record.
  #
  # If this is the last remaining Occurrence under a Bug to be redirected, the
  # Bug is marked as irrelevant. This removes from the list Bugs with
  # unsymbolicated Occurrences once the Symbolication is uploaded.
  #
  # @param [Occurrence] occurrence The Occurrence to redirect this Occurrence
  #   to.

  def redirect_to!(occurrence)
    update_column :redirect_target_id, occurrence.id
    truncate!

    # if all occurrences for this bug redirect, mark the bug as unimportant
    if bug.occurrences.where(redirect_target_id: nil).none?
      bug.update_attribute :irrelevant, true
    end
  end

  # Symbolicates this Occurrence's backtrace. Does nothing if there is no linked
  # {Symbolication} or if there is nothing to symbolicate.
  #
  # @param [Symbolication] symb A Symbolication to use (by default, it's the
  #   linked Symbolication).
  # @see #symbolicate!

  def symbolicate(symb=nil)
    symb ||= symbolication

    return unless symb
    return if truncated?
    return if symbolicated?

    (bt = backtraces).each do |bt|
      bt['backtrace'].each do |elem|
        next unless elem['type'] == 'address'
        symbolicated = symb.symbolicate(elem['address'])
        elem.replace(symbolicated) if symbolicated
      end
    end
    self.backtraces = bt # refresh the actual JSON
  end

  # Like {#symbolicate}, but saves the record.
  #
  # @param [Symbolication] symb A Symbolication to use (by default, it's the
  #   linked Symbolication).

  def symbolicate!(symb=nil)
    symb ||= symbolication

    return unless symb
    return if truncated?
    return if symbolicated?

    symbolicate symb
    save!
  end

  # @return [true, false] Whether all lines of every stack trace have been
  #   symbolicated. (Truncated Occurrences will return `true`.)

  def symbolicated?
    return true if truncated?
    backtraces.all? do |bt|
      bt['backtrace'].none? { |elem| elem['type'] == 'address' }
    end
  end

  # @overload sourcemap(source_map, ...)
  #   Apply one or more source maps to this Occurrence's backtrace. Any matching
  #   un-sourcemapped lines will be converted. Source maps will be run in the
  #   order they are provided: If you have, e.g., a source map that converts
  #   minified JavaScript to JavaScript, and one that converts JavaScript to
  #   CoffeeScript, you should place the former source map earlier in the list
  #   than the latter.
  #
  #   Does not save the record.
  #
  #   @param [SourceMap] source_map A source map to apply.
  #   @see #sourcemap!

  def sourcemap(*sourcemaps)
    return if truncated?
    return if sourcemapped?

    sourcemaps = bug.environment.source_maps.where(revision: revision) if sourcemaps.empty?
    return if sourcemaps.empty?

    (bt = backtraces).each do |bt|
      bt['backtrace'].each do |elem|
        next unless elem['type'] == 'minified'
        symbolicated = nil
        sourcemaps.each { |map| symbolicated ||= map.resolve(elem['url'], elem['line'], elem['column']) }
        elem.replace(symbolicated) if symbolicated
      end
    end
    self.backtraces = bt # refresh the actual JSON
  end

  # Same as {#sourcemap}, but also `save!`s the record.

  def sourcemap!(*sourcemaps)
    return if truncated?
    return if sourcemapped?

    sourcemaps = bug.environment.source_maps.where(revision: revision) if sourcemaps.empty?
    return if sourcemaps.empty?

    sourcemap *sourcemaps
    save!
  end

  # @return [true, false] Whether all lines of every stack trace have been
  #   sourcemapped. (Truncated Occurrences will return `true`.)

  def sourcemapped?
    return true if truncated?
    backtraces.all? do |bt|
      bt['backtrace'].none? { |elem| elem['type'] == 'minified' }
    end
  end

  # De-obfuscates this Occurrence's backtrace. Does nothing if the linked Deploy
  # has no {ObfuscationMap} or if there are no obfuscated backtrace elements.
  #
  # @param [ObfuscationMap] map An ObfuscationMap to use (by default, it's the
  #   linked Deploy's ObfuscationMap).
  # @see #deobfuscate!

  def deobfuscate(map=nil)
    map ||= bug.deploy.obfuscation_map

    return unless map
    return if truncated?
    return if deobfuscated?

    (bt = backtraces).each do |bt|
      bt['backtrace'].each do |elem|
        next unless elem['type'] == 'obfuscated'
        klass = map.namespace.obfuscated_type(elem['class_name'])
        next unless klass && klass.path
        meth = map.namespace.obfuscated_method(klass, elem['symbol'])
        elem.replace(
            'file'   => klass.path,
            'line'   => elem['line'],
            'symbol' => meth.try!(:full_name) || elem['symbol']
        )
      end
    end
    self.backtraces = bt # refresh the actual JSON
  end

  # Like {#deobfuscate}, but saves the record.
  #
  # @param [ObfuscationMap] map An ObfuscationMap to use (by default, it's the
  #   linked Deploy's ObfuscationMap).

  def deobfuscate!(map=nil)
    map ||= bug.deploy.try!(:obfuscation_map)

    return unless map
    return if truncated?
    return if deobfuscated?

    deobfuscate map
    save!
  end

  # @return [true, false] Whether all lines of every stack trace have been
  #   deobfuscated. (Truncated Occurrences will return `true`.)

  def deobfuscated?
    return true if truncated?
    backtraces.all? do |bt|
      bt['backtrace'].none? { |elem| elem['type'] == 'obfuscated' }
    end
  end

  # Recalculates the blame for this Occurrence and re-determines which Bug it
  # should be a member of. If different from the current Bug, creates a
  # duplicate Occurrence under the new Bug and redirects this Occurrence to it.
  # Saves the record.

  def recategorize!
    blamer = bug.environment.project.blamer.new(self)
    new_bug    = blamer.find_or_create_bug!
    if new_bug.id != bug_id
      copy = new_bug.occurrences.build
      copy.assign_attributes attributes.except('number', 'id', 'bug_id')
      copy.save!
      blamer.reopen_bug_if_necessary! new_bug
      redirect_to! copy
    end
  end

  # @return [Git::Object::Commit] The Commit for this Occurrence's `revision`.
  def commit() bug.environment.project.repo.object revision end

  # @private
  def as_json(options={})
    options[:except] = Array.wrap(options[:except])
    options[:except] << :id
    options[:except] << :bug_id
    super options
  end

  # @private
  def backtraces
    self.class.convert_backtraces(attribute('backtraces'))
  end

  # Converts a backtrace list in the legacy format into the current backtrace
  # format.
  #
  # @param [Array<Array>] bts An array of backtraces in the legacy format.
  # @return [Array<Hash>] The backtraces in the current format.

  def self.convert_backtraces(bts)
    return bts if bts.first.kind_of?(Hash)
    bts.map do |(name, faulted, trace)|
      {
          'name'      => name,
          'faulted'   => faulted,
          'backtrace' => convert_legacy_backtrace_format(trace)
      }
    end
  end

  private

  def self.convert_legacy_backtrace_format(backtrace)
    backtrace.map do |bt_line|
      if bt_line.length == 3
        {
            'file'   => bt_line[0],
            'line'   => bt_line[1],
            'symbol' => bt_line[2]
        }
      else
        case bt_line.first
          when '_RETURN_ADDRESS_'
            {
                'type'    => 'address',
                'address' => bt_line[1]
            }
          when '_JS_ASSET_'
            {
                'type'    => 'minified',
                'url'     => bt_line[1],
                'line'    => bt_line[2],
                'column'  => bt_line[3],
                'symbol'  => bt_line[4],
                'context' => bt_line[5]
            }
          when '_JAVA_'
            {
                'type'   => 'obfuscated',
                'file'   => bt_line[1],
                'line'   => bt_line[2],
                'symbol' => bt_line[3],
                'class'  => bt_line[4]
            }
          else
            raise "Unknown special legacy backtrace format #{bt_line.first}"
        end
      end
    end
  end
end
