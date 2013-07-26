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

describe ApplicationController do
  describe "#infinite_scroll_clause" do
    before :each do
      @record = double('Record', created_at: Time.at(12345890), id: 12345)
    end

    it "should return a proper WHERE clause for an ascending infinite scroll" do
      ApplicationController.new.send(:infinite_scroll_clause, 'table.created_at', 'ASC', @record, 'table.id').
        should eql(['table.created_at > ? OR (table.created_at = ? AND table.id > ?)', @record.created_at, @record.created_at, 12345])
    end

    it "should return a proper WHERE clause for a descending infinite scroll" do
      ApplicationController.new.send(:infinite_scroll_clause, 'table.created_at', 'DESC', @record, 'table.id').
        should eql(['table.created_at < ? OR (table.created_at = ? AND table.id < ?)', @record.created_at, @record.created_at, 12345])
    end

    it "should return a proper WHERE clause for an ascending infinite scroll with no fallback key" do
      ApplicationController.new.send(:infinite_scroll_clause, 'table.id', 'ASC', @record).
        should eql(['table.id > ?', @record.id])
    end

    it "should return a proper WHERE clause for a descending infinite scroll with no fallback key" do
      ApplicationController.new.send(:infinite_scroll_clause, 'table.id', 'DESC', @record).
        should eql(['table.id < ?', @record.id])
    end

    it "should return TRUE given bogus sort direction" do
      ApplicationController.new.send(:infinite_scroll_clause, 'table.created_at', 'SIDEWAYS', @record, 'table.id').
        should eql('TRUE')
    end
  end
end
