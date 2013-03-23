# Copyright 2012 Square Inc.
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

# Stores schemaless metadata associated with an {Occurrence}. See that class's
# documentation for more information.
#
# OccurrenceData records can be safely destroyed to preserve disk space. Calling
# {#truncated?} on the associated Occurrences of such records will return
# `true`.
#
# Properties
# ==========
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
# | `crashed`          | If true, the exception was not caught and resulted in a crash.         |
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

class OccurrenceData
  include Mongoid::Document

  # Associations
  field :occurrence_id, type: Integer
  field :bug_id, type: Integer
  field :deploy_id, type: Integer
  field :environment_id, type: Integer
  field :project_id, type: Integer

  # Denormalization
  field :occurred_at, type: Time

  # Universal
  field :message, type: String
  field :backtraces, type: Array
  field :ivars, type: Hash
  field :parent_exceptions, type: Array

  # Universal - Host platform
  field :arguments, type: String
  field :env_vars, type: Hash
  field :pid, type: Integer
  field :parent_process, type: String
  field :process_native, type: Boolean
  field :process_path, type: String

  # Universal - User identification
  field :user_id, type: String

  # Server apps
  field :root, type: String
  field :hostname, type: String

  # Client apps
  field :version, type: String
  field :build, type: String
  field :device_id, type: String
  field :device_type, type: String
  field :operating_system, type: String
  field :os_build, type: String
  field :os_version, type: String
  field :physical_memory, type: Integer
  field :architecture, type: String
  field :crashed, type: Boolean

  # Geolocation
  field :lat, type: Float
  field :lon, type: Float
  field :altitude, type: Float
  field :location_precision, type: Float
  field :heading, type: Float
  field :speed, type: Float

  # Mobile
  field :network_operator, type: String
  field :network_type, type: String
  field :connectivity, type: String
  field :power_state, type: String
  field :orientation, type: String

  # HTTP
  field :request_method, type: String
  field :schema, type: String
  field :host, type: String
  field :port, type: Integer
  field :path, type: String
  field :query, type: String
  field :fragment, type: String
  field :headers, type: Hash

  # Ruby on Rails
  field :controller, type: String
  field :action, type: String
  field :params, type: Hash
  field :session, type: Hash
  field :flash, type: Hash
  field :cookies, type: Hash

  # Android
  field :rooted, type: Boolean

  # Browser
  field :browser_name, type: String
  field :browser_version, type: String
  field :browser_engine, type: String
  field :browser_os, type: String
  field :browser_engine_version, type: String

  field :screen_width, type: Integer
  field :screen_height, type: Integer
  field :window_width, type: Integer
  field :window_height, type: Integer
  field :color_depth, type: Integer

  # Fields that cannot be used by the aggregation view. These are fields with a
  # a continuous range of possible values, or fields with unusual data types.
  NON_AGGREGATING_FIELDS = %w(_id occurrence_id bug_id environment_id project_id
                              message backtraces ivars parent_exceptions
                              arguments env_vars lat lon altitude
                              location_precision heading speed headers params
                              session flash cookies screen_width screen_height
                              window_width window_height)
  # Fields that can be used by the aggregation view.
  AGGREGATING_FIELDS = fields.keys - NON_AGGREGATING_FIELDS

  index({occurrence_id: 1}, unique: true)
  index bug_id: 1, device_id: 1
  index bug_id: 1, occurred_at: 1
  index deploy_id: 1, device_id: 1
  index environment_id: 1
  index project_id: 1
  AGGREGATING_FIELDS.each { |field| index({bug_id: 1, field => 1}, sparse: true) }

  validates :occurrence_id,
            uniqueness: true
  validates :occurrence_id, :bug_id, :environment_id, :project_id,
            numericality: {only_integer: true, greater_than: 0},
            presence:     true

  validates :message,
            presence: true,
            length:   {maximum: 1000}
  validates :backtraces,
            presence: true

  validates :pid,
            numericality: {only_integer: true, greater_than: 0},
            allow_nil:    true
  validates :parent_process,
            length:    {maximum: 150},
            allow_nil: true
  validates :process_path,
            length:    {maximum: 1024},
            allow_nil: true

  validates :user_id,
            length:    {maximum: 256},
            allow_nil: true

  validates :root,
            length:    {maximum: 500},
            allow_nil: true
  validates :hostname,
            length:    {maximum: 255},
            allow_nil: true

  validates :version, :build, :operating_system, :os_build, :os_version, :architecture,
            length:    {maximum: 50},
            allow_nil: true
  validates :device_id, :device_type,
            length:    {maximum: 150},
            allow_nil: true
  validates :physical_memory,
            numericality: {only_integer: true, greater_than: 0},
            allow_nil:    true

  validates :lat,
            numericality: {within: -90..90},
            allow_nil:    true
  validates :lon,
            numericality: {within: -180..180},
            allow_nil:    true
  validates :altitude, :location_precision, :speed,
            numericality: true,
            allow_nil:    true
  validates :heading,
            numericality: {within: 0..360},
            allow_nil:    true

  validates :network_operator, :power_state, :orientation,
            length:    {maximum: 100},
            allow_nil: true
  validates :network_type, :connectivity,
            length:    {maximum: 50},
            allow_nil: true

  validates :request_method,
            inclusion: {in: %w(GET POST PUT PATCH DELETE HEAD TRACE OPTIONS CONNECT)},
            allow_nil: true
  validates :schema,
            length:    {maximum: 50},
            allow_nil: true
  validates :host, :query, :fragment,
            length:    {maximum: 255},
            allow_nil: true
  validates :port,
            numericality: true,
            allow_nil:    true

  validates :controller, :action,
            length:    {maximum: 100},
            allow_nil: true

  validates :browser_name, :browser_version, :browser_engine, :browser_os, :browser_engine_version,
            length:    {maximum: 50},
            allow_nil: true

  validates :screen_width, :screen_height, :window_width, :window_height, :color_depth,
            numericality: {only_integer: true, greater_than_or_equal_to: 0},
            allow_nil:    true

  before_validation :set_associations, on: :create

  extend SetNilIfBlank
  set_nil_if_blank :user_id, :root, :hostname, :version, :device_id,
                   :device_type, :operating_system, :network_operator,
                   :network_type, :connectivity, :schema, :host, :path, :query,
                   :controller, :action, :browser_name, :browser_version,
                   :browser_engine, :browser_os, :browser_engine_version

  attr_protected nil

  private

  def set_associations
    return unless occurrence_id
    occ = Occurrence.find_by_id(occurrence_id)
    return unless occ

    self.occurred_at    = occ.occurred_at
    self.bug_id         = occ.bug_id
    self.deploy_id      = occ.bug.deploy_id
    self.environment_id = occ.bug.environment_id
    self.project_id     = occ.bug.environment.project_id

    true
  end
end
