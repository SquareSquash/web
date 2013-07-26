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

module Service

  # JIRA integration module. Creates JIRA issues from Bug information.
  #
  # In order to use JIRA integration in your Squash installation, you must
  # configure the `jira.yml` Configoro file. This file supports the following
  # keys:
  #
  # |                  |                                                 |
  # |:-----------------|:------------------------------------------------|
  # | `disabled`       | Set to `false` to enable JIRA support.          |
  # | `authentication` | A hash of authentication options (see below).   |
  # | `api_host`       | The host of the JIRA installation, with scheme. |
  # | `api_root`       | The path of the JIRA root URL under the host.   |
  #
  # The `authentication` hash must have a key called `strategy`; currently the
  # only supported value is "basic" for HTTP Basic authentication. The `user`
  # and `password` keys must also be present under this hash.
  #
  # JIRA integration is done using the "jira-ruby" gem.

  module JIRA
    extend self

    # Returns the link to a new issue page with pre-filled values. See the JIRA
    # `CreateIssueDetails` action documentation for more information on possible
    # values.
    #
    # @param [Hash<String, String>] properties Values to pre-fill.
    # @return [String, nil] A URL to the uncreated JIRA issue, or `nil` if JIRA
    #   integration is disabled.

    def new_issue_link(properties)
      return nil if Squash::Configuration.jira.disabled?
      url "#{Squash::Configuration.jira.create_issue_details}?#{properties.to_query}"
    end

    # Locates an issue by its key.
    #
    # @param [String] key The issue key (e.g., "PROJ-123").
    # @return [JIRA::Resource::Issue, nil] The issue with that key, if found.

    def issue(key)
      return nil if Squash::Configuration.jira.disabled?

      begin
        client.Issue.find(key)
      rescue ::JIRA::HTTPError
        nil
      end
    end

    # @return [Array<JIRA::Resource::Status>] All known JIRA issue statuses.
    def statuses() client.Status.all end

    # @return [Array<JIRA::Resource::Project>] All known JIRA projects.
    def projects() client.Project.all end

    def url(path)
      "#{Squash::Configuration.jira.api_host}#{Squash::Configuration.jira.api_root}#{path}"
    end

    def client(additional_options={})
      @client ||= begin
        options = {
            site:         Squash::Configuration.jira.api_host,
            context_path: Squash::Configuration.jira.api_root,
            timeout:      2,
            open_timeout: 2,
            read_timeout: 2
        }.merge(additional_options)
        case Squash::Configuration.jira.authentication.strategy
          when 'basic'
            options[:auth_type] = :basic
            options[:username]  = Squash::Configuration.jira.authentication.user
            options[:password]  = Squash::Configuration.jira.authentication.password
          when 'oauth'
            options[:private_key_file] = Squash::Configuration.jira.authentication.private_key_file
            options[:consumer_key]     = Squash::Configuration.jira.authentication.consumer_key
        end

        cl = ::JIRA::Client.new options

        if Squash::Configuration.jira.authentication[:token] && Squash::Configuration.jira.authentication[:secret]
          cl.set_access_token Squash::Configuration.jira.authentication.token, Squash::Configuration.jira.authentication.secret
        end

        cl
      end
    end
  end
end
