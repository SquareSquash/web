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

# A myriad of JDBC fixes.

class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter

  # AR::JDBC overwrites CPK's patched sql_for_insert method; over-overwrite it.

  def sql_for_insert(sql, pk, id_value, sequence_name, binds)
    unless pk
      # Extract the table from the insert sql. Yuck.
      table_ref = extract_table_ref_from_insert_sql(sql)
      pk        = primary_key(table_ref) if table_ref
    end

    # CPK
    #sql = "#{sql} RETURNING #{quote_column_name(pk)}" if pk
    sql = "#{sql} RETURNING #{quote_column_names(pk)}" if pk

    [sql, binds]
  end

  # JDBC connections seem to go away (in production only) after about an hour or
  # so. No idea why, but this fixes it. This also fixes broken connections after
  # a failover.

  [:columns, :begin_db_transaction, :commit_db_transaction,
   :rollback_db_transaction, :begin_isolated_db_transaction, :create_savepoint,
   :rollback_to_savepoint, :release_savepoint, :exec_query, :exec_insert,
   :exec_delete, :exec_update, :exec_query_raw, :_execute, :tables, :indexes,
   :primary_keys, :write_large_object, :update_lob_value].each do |meth|
    define_method :"#{meth}_with_retry" do |*args, &block|
      begin
        send :"#{meth}_without_retry", *args, &block
      rescue ActiveRecord::StatementInvalid, ActiveRecord::JDBCError => err
        if err.to_s =~ /This connection has been closed/ # If the connection was somehow pulled out from underneath us...
          reconnect! # reconnect...
          if @_retried_connection
            raise
          else
            @_retried_connection = true
            retry # ... and try again
          end
        elsif err.to_s =~ /Connection reset/ # if, because of that, we bork up any other threads using the same connection...
          # try again; the connection should be fine now
          if @_retried_connection
            raise
          else
            @_retried_connection = true
            retry
          end
        else
          raise
        end
      end
    end
    alias_method_chain meth, :retry
  end
end if RUBY_PLATFORM == 'java'
