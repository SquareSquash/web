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

# Source mapping information for a JavaScript project. This model stores a
# mapping of minified JavaScript code location and symbol names to
# corresponding location and names in the unminified code. It also maps asset
# URLs to the project files those URLs are generated from. See the Squash
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
# Serialization is accomplished by YAML-serializing the
# `Squash::Javascript::SourceMap` object, zlib-encoding the result, and then
# base-64-encoding the compressed output. This is also how the `map` property is
# transmitted over the wire.
#
# No support is given for modifying these objects after they have been
# deserialized from YAML.
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
# |       |                                                                           |
# |:------|:--------------------------------------------------------------------------|
# | `map` | A serialized `Squash::Javascript::SourceMap` object with source map data. |

class SourceMap < ActiveRecord::Base
  belongs_to :environment, inverse_of: :source_maps

  validates :environment,
            presence: true
  validates :revision,
            presence:       true,
            known_revision: {repo: ->(map) { RepoProxy.new(map, :environment, :project) }}

  after_commit(on: :create) do |map|
    BackgroundRunner.run SourceMapWorker, map.id
  end

  attr_accessible :revision, :map, as: :api
  attr_readonly :revision

  # @private
  def map
    @map ||= begin
      m = YAML.load(Zlib::Inflate.inflate(Base64.decode64(read_attribute(:map))))
      raise TypeError, "expected Squash::Javascript::SourceMap, got #{m.class}" unless m.kind_of?(Squash::Javascript::SourceMap)
      m
    end
  end

  # @private
  def map=(m)
    raise TypeError, "expected Squash::Javascript::SourceMap, got #{m.class}" unless m.kind_of?(Squash::Javascript::SourceMap)
    write_attribute :map, Base64.encode64(Zlib::Deflate.deflate(m.to_yaml))
  end

  # Given a line of code within a minified file, attempts to resolve it to a
  # line of code within the original source.
  #
  # @param [String] route The URL of the minified JavaScript file.
  # @param [Fixnum] line The line of code.
  # @param [Fixnum] column The character number within the line.
  # @return [Hash, nil] If found, a hash consisting of the source file path,
  #   line number, and method name.

  def resolve(route, line, column)
    if (mapping = map.resolve(route, line, column))
      {
          'file'   => mapping.source_file,
          'line'   => mapping.source_line,
          'symbol' => mapping.symbol
      }
    else
      nil
    end
  end
end
