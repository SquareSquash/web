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

require 'zlib'
require 'base64'

# Symbolication information for a project. This model stores an array of address
# ranges and the file, line, and method information for each of those ranges.
# Symbolication can then be done by finding the information corresponding to a
# range that includes a particular program counter address.
#
# Symbolication objects are uniquely referenced by UUID. This is because Xcode
# generates a UUID for each new build and architecture of a project. The UUID is
# then distributed with the project, and used to look up the correct
# Symbolication to use.
#
# For projects in compiled languages that do not attach a UUID to their debug
# data, the Squash client library for that language will need to generate its
# own UUID, to be distributed with the project.
#
# For more information on symbolication generally, see the README.
#
# ### Symbol Data
#
# Symbol data is generated using the "squash_ios_symbolicator" gem. The gem
# produces data structures that can be compactly serialized. The gem is also
# included in this project to support deserializing the resulting data.
#
# Serialization is accomplished by YAML-serializing the `Symbols` or `Lines`
# object, zlib-encoding the result, and then base-64-encoding the compressed
# output. This is also how the `symbols` and `lines` properties are transmitted
# over the wire.
#
# No support is given for modifying these objects after they have been
# deserialized from YAML.
#
# Properties
# ----------
#
# |           |                                                                         |
# |:----------|:------------------------------------------------------------------------|
# | `uuid`    | A universally-unique identifier associated with the symbolication data. |
# | `symbols` | A serialized `Symbolication::Symbols` object with debug_info data.      |
# | `lines`   | A serialized `Symbolication::Lines` object with debug_lines data.       |

class Symbolication < ActiveRecord::Base
  # internal use only
  has_many :occurrences, inverse_of: :symbolication, primary_key: 'uuid', dependent: :restrict_with_exception

  self.primary_key = 'uuid'

  validates :uuid,
            presence:   true,
            uniqueness: true,
            format:     {with: /\A[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}\z/i}

  after_commit(on: :create) do |sym|
    BackgroundRunner.run SymbolicationWorker, sym.id
  end

  attr_readonly :uuid

  # @private
  def symbols
    @symbols ||= begin
      syms = YAML.load(Zlib::Inflate.inflate(Base64.decode64(read_attribute(:symbols))))
      raise TypeError, "expected Squash::Symbolicator::Symbols, got #{syms.class}" unless syms.kind_of?(Squash::Symbolicator::Symbols)
      syms
    end
  end

  # @private
  def symbols=(syms)
    raise TypeError, "expected Squash::Symbolicator::Symbols, got #{syms.class}" unless syms.kind_of?(Squash::Symbolicator::Symbols)
    write_attribute :symbols, Base64.encode64(Zlib::Deflate.deflate(syms.to_yaml))
    @symbols = syms
  end

  # @private
  def lines
    @lines ||= begin
      lns = YAML.load(Zlib::Inflate.inflate(Base64.decode64(read_attribute(:lines))))
      raise TypeError, "expected Squash::Symbolicator::Lines, got #{lns.class}" unless lns.kind_of?(Squash::Symbolicator::Lines)
      lns
    end
  end

  # @private
  def lines=(lns)
    raise TypeError, "expected Squash::Symbolicator::Lines, got #{lns.class}" unless lns.kind_of?(Squash::Symbolicator::Lines)
    write_attribute :lines, Base64.encode64(Zlib::Deflate.deflate(lns.to_yaml))
    @lines = lns
  end


  # Returns the file path, line number, and method name corresponding to a
  # program counter address. The result is formatted for use as part of an
  # {Occurrence}'s backtrace element.
  #
  # If `lines` is provided, the line number will be the specific corresponding
  # line number within the method. Otherwise it will be the line number of the
  # method declaration.
  #
  # @param [Fixnum] address A stack return address (decimal number).
  # @return [Hash, nil] The file path, line number, and method name containing
  #   that address, or `nil` if that address could not be symbolicated.

  def symbolicate(address)
    line   = lines.for(address) if lines
    symbol = symbols.for(address)

    if line && symbol
      {
          'file'   => line.file,
          'line'   => line.line,
          'symbol' => symbol.ios_method
      }
    elsif line
      {
          'file' => line.file,
          'line' => line.line
      }
    elsif symbol
      {
          'file'   => symbol.file,
          'line'   => symbol.line,
          'symbol' => symbol.ios_method
      }
    else
      nil
    end
  end
end
