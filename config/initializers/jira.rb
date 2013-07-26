# encoding: utf-8

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

# @private
module JIRA

  # @private
  #
  # Adds timeout capability to the JIRA HTTP client.

  class HttpClient
    def http_conn_with_timeout(*args)
      http_conn              = http_conn_without_timeout(*args)
      http_conn.open_timeout = @options[:open_timeout]
      http_conn.read_timeout = @options[:read_timeout]
      http_conn
    end
    alias_method_chain :http_conn, :timeout
  end
end unless Squash::Configuration.jira.disabled?
