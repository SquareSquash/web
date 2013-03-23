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

# Allows the fields of an associated Mongoid model class to be accessible from
# an Active Record object as if the fields were defined on that Active Record
# object directly. For example, an Active Record class called `Person` could
# have an associated Mongoid class called `PersonalInformation`. Fields on
# `PersonalInformation` (such as `home_address`) would be directly accessible on
# a Person: `person.home_address`, `person.home_address=`, etc. All methods
# provided by ActiveModel::AttributeMethods are supported.
#
# People who are metaprogramming-averse should avoid delving too deeply into
# this module.
#
# @example
#   class Person
#     include MongoAttributes
#     mongo_attributes PersonalInformation
#   end
#
#   person.home_address = ["123 Fake St.", "Faketown", "CA", "94107"]

module MongoAttributes
  extend ActiveSupport::Concern

  # Methods defined on the Active Record class.

  module ClassMethods

    # Specifies that the fields defined on the given Mongoid class should be
    # directly available from objects of this class.
    #
    # @param [Class] model The class that includes Mongoid::Document.
    # @param [Hash] options Additional options.
    # @option options [Symbol] :foreign_key The name of the field on the Mongoid
    #   document whose value is the primary key of the Active Record object. By
    #   default it is, e.g., `car_id` for a model named `Car`.
    # @option options [Symbol] :primary_key The name of the column on the Active
    #   Record document whose value is stored in the foreign key field on the
    #   Mongoid object. By default it is the model's primary key field.
    # @option options [Array<Symbol>] :skip_validations An array of Mongoid
    #   field names whose validations should not be copied to the Active Record
    #   object's validations, and whose validation should not affect the Active
    #   Record's validation. By default it contains only the foreign key.

    def mongo_attributes(model, options={})
      class_attribute :_attribute_model, :_attribute_options

      model = model.constantize unless model.kind_of?(Class)
      self._attribute_model = model

      options[:foreign_key] ||= (model_name.singular + '_id').to_sym
      options[:primary_key] ||= :id

      options[:skip_validations] ||= []
      options[:skip_validations] << options[:foreign_key]
      options[:skip_validations].uniq!

      self._attribute_options = options

      validate :_validate_attributes
      after_save :_save_attributes
      after_destroy :_destroy_attributes

      alias_method_chain :changed_attributes, :mongo
      alias_method_chain :attribute_will_change!, :mongo
      alias_method_chain :attribute_method?, :mongo
      alias_method_chain :attribute, :mongo
      alias_method_chain :attribute_before_type_cast, :mongo
      alias_method_chain :_attribute, :mongo
      alias_method_chain :attribute=, :mongo
      alias_method_chain :query_attribute, :mongo

      if !respond_to?(:define_attribute_methods_with_mongo) && !superclass.respond_to?(:define_attribute_methods_with_mongo) &&
          !respond_to?(:define_method_attribute_with_mongo) && !superclass.respond_to?(:define_method_attribute_with_mongo)
        class << self
          def define_attribute_methods_with_mongo
            define_attribute_methods_without_mongo
            _attribute_model.fields.keys.each { |field| define_attribute_method field }
          end
          alias_method_chain :define_attribute_methods, :mongo

          def define_method_attribute_with_mongo(attr_name)
            return define_method_attribute_without_mongo(attr_name) unless _attribute_model.fields.include?(attr_name)
            attribute_method_matchers.each do |matcher|
              method_name = matcher.method_name(attr_name)
              define_optimized_call generated_attribute_methods, method_name, matcher.method_missing_target, attr_name.to_s
              attribute_method_matchers_cache.clear
            end
          end
          alias_method_chain :define_method_attribute, :mongo
        end
      end
    end
  end

  # @private
  def _attribute_record
    @_attribute_record ||= OccurrenceData.find_or_initialize_by(self.class._attribute_options[:foreign_key] => send(self.class._attribute_options[:primary_key]))
  end

  # @private
  def as_json(options={})
    options  ||= Hash.new # the JSON encoder can sometimes give us nil options?
    metadata = self.class._attribute_model.fields.keys
    metadata &= Array.wrap(options[:only]) if options[:only]
    metadata          -= Array.wrap(options[:except])
    options[:methods] = Array.wrap(options[:methods]) + metadata
    super options
  end

  # @private
  def to_xml(options={})
    metadata = self.class._attribute_model.fields.keys
    metadata &= Array.wrap(options[:only]) if options[:only]
    metadata          -= Array.wrap(options[:except])
    options[:methods] = Array.wrap(options[:methods]) + metadata
    super options
  end

  # @private
  def assign_multiparameter_attributes(pairs)
    fake_attributes = pairs.select { |(field, _)| self.class._attribute_model.fields.include? field[0, field.index('(')] }

    fake_attributes.group_by { |(field, _)| field[0, field.index('(')] }.each do |field_name, parts|
      options = self.class._attribute_model.fields[field_name]
      if options[:type]
        args = parts.each_with_object([]) do |(part_name, value), ary|
          part_ann = part_name[part_name.index('(') + 1, part_name.length]
          index    = part_ann.to_i - 1
          raise "Out-of-bounds multiparameter argument index" unless index >= 0
          ary[index] = if value.blank? then
                         nil
                       elsif part_ann.ends_with?('i)') then
                         value.to_i
                       elsif part_ann.ends_with?('f)') then
                         value.to_f
                       else
                         value
                       end
        end
        send :"#{field_name}=", args.any? ? options[:type].new(*args) : nil
      else
        raise "#{field_name} has no type and cannot be used for multiparameter assignment"
      end
    end

    super(pairs - fake_attributes)
  end

  # @private
  def inspect_with_mongo
    "#<#{self.class.to_s} #{attributes.merge(_attribute_record.attributes.stringify_keys).map { |k, v| "#{k}: #{v.inspect}" }.join(', ')}>"
  end
  alias_method_chain :inspect, :mongo

  private

  def changed_attributes_with_mongo
    changed_attributes_without_mongo.merge(_attribute_record.changed_attributes)
  end

  def attribute_will_change_with_mongo!(attr)
    return attribute_will_change_without_mongo!(attr) if attribute_names.include?(attr.to_s)
    _attribute_record.send :"#{attr}_will_change!"
  end

  ## ATTRIBUTE MATCHER METHODS

  def attribute_with_mongo(attr)
    return attribute_without_mongo(attr) if attribute_names.include?(attr.to_s)
    _attribute_record.send(attr)
  end

  def attribute_before_type_cast_with_mongo(attr)
    return attribute_before_type_cast_without_mongo(attr) if attribute_names.include?(attr.to_s)
    _attribute_record.send :"#{attr}_before_type_case"
  end

  def _attribute_with_mongo(attr)
    return _attribute_without_mongo(attr) if attribute_names.include?(attr.to_s)
    _attribute_record.send :"_#{attr}"
  end

  def attribute_with_mongo=(attr, value)
    return send(:attribute_without_mongo=, attr, value) if attribute_names.include?(attr.to_s)
    _attribute_record.send :"#{attr}=", value
  end

  def query_attribute_with_mongo(attr)
    return query_attribute_without_mongo(attr) if attribute_names.include?(attr.to_s)
    _attribute_record.send :"#{attr}?"
  end

  def attribute_method_with_mongo?(attr)
    self.class._attribute_model.fields.include?(attr) || attribute_method_without_mongo?(attr)
  end

  ## VALIDATIONS

  def _validate_attributes
    _attribute_record.valid?
    _attribute_record.errors.each do |k, v|
      next if self.class._attribute_options[:skip_validations].include?(k.to_sym)
      errors[k] = v
    end
  end

  def _save_attributes
    # set the ID attribute on the associated object if it was instantiated back
    # when this object was unsaved
    unless _attribute_record.send(self.class._attribute_options[:foreign_key])
      _attribute_record.send :"#{self.class._attribute_options[:foreign_key]}=",
                             send(self.class._attribute_options[:primary_key])
    end

    _attribute_record.save!
    _attribute_record.reload
  rescue Mongoid::Errors::DocumentNotFound
    # the #reload failed because the record didn't save because one already
    # exists; load it, merge changed attributes, and try again
    changes            = _attribute_record.changes
    @_attribute_record = nil
    changes.each { |key, (_, new)| _attribute_record.send :"#{key}=", new }

    # retry only once
    unless @retried
      @retried = true
      retry
    end
  rescue Mongoid::Errors::Validations
    if _attribute_record.errors[self.class._attribute_options[:foreign_key]].present?
      # probably failed because an attribute record already exists; load it,
      # merge changed attributes, and try again
      changes            = _attribute_record.changes
      @_attribute_record = nil
      changes.each { |key, (_, new)| _attribute_record.send :"#{key}=", new }

      # retry only once
      unless @retried
        @retried = true
        retry
      end
    else
      raise
    end
  end

  def _destroy_attributes
    _attribute_record.destroy
  end
end
