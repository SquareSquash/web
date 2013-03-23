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

# Fixes a bug caused by `Boolean` being defined as a module in the boolean gem
# (used by has_metadata_column) but as a class in Mongoid.

module Boolean
  include Mongoid::Extensions::Object
  extend Mongoid::Extensions::Object::ClassMethods
end
