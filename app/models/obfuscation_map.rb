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

require 'zlib'
require 'base64'

# Obfuscation information for a Java project. This model stores a representation
# of a Java project's namespace, along with the obfuscated aliases to the
# classes, packages, and methods of that namespace. See the Squash Java
# Deobfuscation library documentation for more information.
#
# ### Namespace Data
#
# Namespace and name mapping data is generated using the "squash_java" gem. The
# gem produces a memory representation of the project namespace. The gem is also
# included in this project to support deserializing the resulting data.
#
# Serialization is accomplished by YAML-serializing the `Namespace` object,
# zlib-encoding the result, and then base-64-encoding the compressed output.
# This is also how the `namespace` property is transmitted over the wire.
#
# No support is given for modifying these objects after they have been
# deserialized from YAML.
#
# Associations
# ------------
#
# |          |                                          |
# |:---------|:-----------------------------------------|
# | `deploy` | The {Deploy} using this obfuscation map. |
#
# Properties
# ----------
#
# |             |                                                                      |
# |:------------|:---------------------------------------------------------------------|
# | `namespace` | A serialized `Squash::Java::Namespace` object with obfuscation data. |

class ObfuscationMap < ActiveRecord::Base
  belongs_to :deploy, inverse_of: :obfuscation_map

  validates :deploy,
            presence: true

  after_commit(on: :create) do |map|
    BackgroundRunner.run ObfuscationMapWorker, map.id
  end

  attr_readonly :namespace

  # @private
  def namespace
    @namespace ||= begin
      ns = YAML.load(Zlib::Inflate.inflate(Base64.decode64(read_attribute(:namespace))))
      raise TypeError, "expected Squash::Java::Namespace, got #{ns.class}" unless ns.kind_of?(Squash::Java::Namespace)
      ns
    end
  end

  # @private
  def namespace=(ns)
    raise TypeError, "expected Squash::Java::Namespace, got #{ns.class}" unless ns.kind_of?(Squash::Java::Namespace)
    write_attribute :namespace, Base64.encode64(Zlib::Deflate.deflate(ns.to_yaml))
  end
end
