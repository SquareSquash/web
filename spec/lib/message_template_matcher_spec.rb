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

require 'spec_helper'

describe MessageTemplateMatcher do
  before :all do
    @mysql_error = <<-ERR.strip
      Duplicate entry 'foo@example.com' for key 'index_users_on_email': UPDATE `users` SET `name` = 'Sancho Sample', `crypted_password` = '349857346384697346', `updated_at` = '2012-09-23 21:18:37', `email` = 'foo@example.com' WHERE `id` = 123456 -- app/controllers/api/v1/user_controller.rb:35
    ERR
    @pg_error = <<-ERR.strip
relation "users" does not exist
  Position: 312:             SELECT a.attname as column_name, format_type(a.atttypid, a.atttypmod) as column_type, d.adsrc as column_default, a.attnotnull as column_not_null
              FROM pg_attribute a LEFT JOIN pg_attrdef d
                ON a.attrelid = d.adrelid AND a.attnum = d.adnum
             WHERE a.attrelid = '"users"'::regclass
               AND a.attnum > 0 AND NOT a.attisdropped
             ORDER BY a.attnum
    ERR
  end

  describe "#matched_substring" do
    it "should remove the query from an error message" do
      MessageTemplateMatcher.instance.matched_substring('Mysql::Error', @mysql_error).should eql("Duplicate entry 'foo@example.com' for key 'index_users_on_email'")
    end

    it "should return the original message if no match was found" do
      MessageTemplateMatcher.instance.matched_substring('SomeError', @mysql_error).should eql(@mysql_error)
      MessageTemplateMatcher.instance.matched_substring('Mysql::Error', 'foobar').should eql('foobar')
    end

    it "should use references to other error types" do
      MessageTemplateMatcher.instance.matched_substring('ActiveRecord::JDBCError', 'ERROR: ' + @mysql_error).should eql("Duplicate entry 'foo@example.com' for key 'index_users_on_email'")
      MessageTemplateMatcher.instance.matched_substring('ActiveRecord::JDBCError', 'ERROR: ' + @pg_error).should eql('ERROR: relation "users" does not exist')
    end
  end

  describe "#sanitized_message" do
    it "should filter the error message" do
      MessageTemplateMatcher.instance.sanitized_message('Mysql::Error', @mysql_error).should eql("Duplicate entry '[STRING]' for key '[STRING]'")
    end

    it "should return nil if no match was found" do
      MessageTemplateMatcher.instance.sanitized_message('SomeError', @mysql_error).should be_nil
      MessageTemplateMatcher.instance.sanitized_message('Mysql::Error', 'foobar').should be_nil
    end

    it "should use references to other error types" do
      MessageTemplateMatcher.instance.sanitized_message('ActiveRecord::JDBCError', 'ERROR: ' + @mysql_error).should eql("Duplicate entry '[STRING]' for key '[STRING]'")
      MessageTemplateMatcher.instance.sanitized_message('ActiveRecord::JDBCError', 'ERROR: ' + @pg_error).should eql('[STRING] [STRING] does not exist')
    end
  end
end
