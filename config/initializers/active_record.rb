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

# Reopen the Active Record base class to add a few very non-intrusive changes.
# Yes, mixins are the correct way of doing this, but this is a really small
# change and it's much more convenient this way. Also includes fixes for
# composite primary keys.

class ActiveRecord::Base

  # Before-hook that sets string fields to nil if they're empty.
  def self.set_nil_if_blank(*fields)
    fields.each do |field|
      before_validation { |obj| obj.send :"#{field}=", nil if obj.send(field).blank? }
    end
  end

  # Apparently CPK forgot to override this method
  def touch(name = nil)
    attributes = timestamp_attributes_for_update_in_model
    attributes << name if name

    unless attributes.empty?
      current_time = current_time_from_proper_timezone
      changes      = {}

      attributes.each do |column|
        changes[column.to_s] = write_attribute(column.to_s, current_time)
      end

      changes[self.class.locking_column] = increment_lock if locking_enabled?

      @changed_attributes.except!(*changes.keys)
      primary_key = self.class.primary_key

      #CPK
      #self.class.unscoped.update_all(changes, {primary_key => self[primary_key]}) == 1
      where_clause = Array.wrap(self.class.primary_key).inject({}) { |hsh, key| hsh[key] = self[key]; hsh }
      self.class.unscoped.where(where_clause).update_all(changes) == 1
    end
  end

  # Edge rails renames this field so that models can have a column named "field"
  # without it conflicting with the magic dirty methods. Composite Primary Keys
  # has not been updated in turn, so until it is, we'll revert to the old
  # behavior and just not have any attributes named "field".
  alias field_changed? _field_changed?
end

class ActiveRecord::Associations::HasManyAssociation

  # holy shit Rails, really? No way to disable this behavior?
  def has_cached_counter?(*args) false end
end

class ActiveRecord::Relation

  # Returns the first record if count is 1, nil otherwise.
  def only() count == 1 ? first : nil end

  # In the event that we're not using cursors, define #cursor to proxy to
  # #find_each.
  def cursor
    CursorProxy.new(self)
  end

  # @private
  class CursorProxy
    delegate :each, to: :relation
    attr_reader :relation
    def initialize(relation)
      @relation = relation
    end
  end
end
