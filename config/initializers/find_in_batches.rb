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

module CompositePrimaryKeys::ActiveRecord::Batches

  # Reimplementation of find_in_batches that fixes bugs and works with
  # composite_primary_keys.

  def find_in_batches(options = {})
    relation = self

    unless arel.orders.blank? && arel.taken.blank?
      ActiveRecord::Base.logger.warn("Scoped order and limit are ignored, it's forced to be #{batch_order} and batch size")
    end

    if (finder_options = options.except(:start, :batch_size)).present?
      raise "You can't specify an order, it's forced to be #{batch_order}" if options[:order].present?
      raise "You can't specify a limit, it's forced to be the batch_size" if options[:limit].present?

      relation = apply_finder_options(finder_options)
    end

    start = options.delete(:start)
    start ||= [1]*primary_key.size
    start = [start] unless start.kind_of?(Enumerable)
    start[-1] = start.last - 1

    batch_size = options.delete(:batch_size) || 1000

    relation = relation.reorder(batch_order).limit(batch_size)

    pkey                     = Array.wrap(primary_key)
    id_constraints, key_vals = build_id_constraints(pkey.dup, start.dup)
    records                  = relation.where(id_constraints, *key_vals).to_a

    while records.any?
      records_size = records.size

      yield records

      break if records_size < batch_size

      unless pkey.all? { |key| records.last.send(key) }
        raise "Primary key not included in the custom select clause"
      end

      pkey.each_with_index { |key, index| start[index] = records.last.send(key) } if records.any?
      id_constraints, key_vals = build_id_constraints(pkey.dup, start.dup)
      records                  = relation.where(id_constraints, *key_vals).to_a
    end
  end

  private

  def batch_order
    Array.wrap(primary_key).map { |pk| "#{quoted_table_name}.#{connection.quote_column_name pk} ASC" }.join(', ')
  end

  private

  def build_id_constraints(keys, values)
    return "#{quoted_table_name}.#{connection.quote_column_name keys.first.to_s} > ?", [values.first] if keys.size == 1
    key   = keys.pop
    value = values.pop

    query = keys.reverse.map { |subkey| "#{quoted_table_name}.#{connection.quote_column_name subkey.to_s} = ?" }.join(' AND ')

    subquery, subvalues = build_id_constraints(keys.dup, values.dup)

    return "(#{quoted_table_name}.#{connection.quote_column_name key.to_s} > ? AND #{query}) OR (#{subquery})", [value, *(values.reverse + subvalues)]
  end
end
