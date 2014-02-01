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

# Source mapping information for a JavaScript project. This model stores a
# mapping of generated JavaScript code location and symbol names to
# corresponding location and names in the original code. See the Squash
# JavaScript client library documentation for more information.
#
# Even if your project is not using minified code, this class is also useful for
# mapping the URLs of deployed JavaScript assets to their original source files.
#
# ### Serialization
#
# Mapping data is generated using the "squash_javascript" gem. The gem produces
# a memory representation of the source map. The gem is also included in this
# project to support deserializing the resulting data.
#
# Serialization is accomplished by zlib-encoding the JSON source map, and then
# base-64-encoding the compressed output. This is also how the `map` property is
# transmitted over the wire.
#
# No support is given for modifying these objects after they have been
# deserialized.
#
# ### Source maps in stages
#
# Oftentimes a project's JavaScript code moves through different transformations
# before reaching a final deployed state. For example, the development code
# could be in CoffeeScript, which is then compiled to JavaScript, then
# concatenated, then minified (a three-stage process). The client may generate
# source maps for each of those stages.
#
# In order to convert a stack trace from its original format into one useful in
# the development code, these source maps must be applied in the correct order.
# To facilitate this, SourceMap records have a `from` and `to` field. Stack
# traces are annotated with their production format ("hosted"), and Squash
# searches for source maps that it can apply to that format. It continues to
# search for applicable source maps until the stack trace's format is not
# convertible any further.
#
# Stack traces are searched in a simple linear order and applied as they are
# found applicable. No fancy dependency trees are built.
#
# For example, say the following stack trace was provided:
#
# ````
# 1: foo/bar.js:123 (concatenated)
# 2. foo/baz.js:234 (hosted)
# ````
#
# Squash would first note that line 1 is concatenated, and attempt to locate a
# sourcemap whose `from` field is "concatenated" that has an entry for that file
# and line. It would perhaps find one whose `to` field is "compiled", so it
# would apply that source map, resulting in a different stack trace element
# whose type is "compiled". It would then search again for another source map,
# this time one whose `from` field was "compiled", and finding one, apply it,
# resulting in a new stack trace of type "coffee". Finding no source maps whose
# `from` field is "coffee", Squash would be finished with that line.
#
# Line two would proceed similarly, except Squash might find a source map with
# a `from` of "hosted" and a `to` of "concatenated". From there, the logic would
# proceed as described previously.
#
# The Squash JavaScript client library always adds the type of "hosted" to
# each line of the original backtrace, so your source-mapping journey should
# begin there.
#
# Associations
# ------------
#
# |               |                                               |
# |:--------------|:----------------------------------------------|
# | `environment` | The {Environment} this source map pertain to. |
#
# Properties
# ----------
#
# |        |                                                                                  |
# |:-------|:---------------------------------------------------------------------------------|
# | `map`  | A serialized source map.                                                         |
# | `from` | An identifier indicating what kind of JavaScript code this source map maps from. |
# | `to`   | An identifier indicating what kind of JavaScript code this source map maps to.   |

class SourceMap < ActiveRecord::Base
  belongs_to :environment, inverse_of: :source_maps

  validates :environment,
            presence: true
  validates :revision,
            presence:       true,
            known_revision: {repo: ->(map) { RepoProxy.new(map, :environment, :project) }}
  validates :from, :to,
            presence: true,
            length:   {maximum: 24}

  after_commit(on: :create) do |map|
    BackgroundRunner.run SourceMapWorker, map.id
  end

  attr_readonly :revision

  # @private
  def map
    @map ||= GemSourceMap::Map.from_json(
        Zlib::Inflate.inflate(
            Base64.decode64(read_attribute(:map))))
  end

  # @private
  def map=(m)
    raise TypeError, "expected GemSourceMap::Map, got #{m.class}" unless m.kind_of?(GemSourceMap::Map)
    write_attribute :map, Base64.encode64(Zlib::Deflate.deflate(m.as_json.to_json))
  end

  # @private
  def raw_map=(m)
    write_attribute :map, m
  end

  # Given a line of code within a file in the `from` format, attempts to resolve
  # it to a line of code within a file in the `to` format.
  #
  # @param [String] route The URL of the generated JavaScript file.
  # @param [Fixnum] line The line of code
  # @param [Fixnum] column The character number within the line.
  # @return [Hash, nil] If found, a hash consisting of the source file path,
  #   line number, and method name.

  def resolve(route, line, column)
    return nil unless column # firefox doesn't support column numbers
    return nil unless map.filename == route || begin
      uri = URI.parse(route) rescue nil
      if uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS)
        uri.path == map.filename
      else
        false
      end
    end
    mapping = map.bsearch(GemSourceMap::Offset.new(line, column))
    return nil unless mapping
    {
        'file'   => mapping.source,
        'line'   => mapping.original.line,
        'column' => mapping.original.column
    }
  end
end
