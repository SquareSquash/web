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

  # PagerDuty integration module. Opens, acknowledges, and resolves incidents.
  #
  # In order to use PagerDuty integration in your Squash installation, you must
  # configure the `pagerduty.yml` Configoro file. This file supports the
  # following keys:
  #
  # |                  |                                               |
  # |:-----------------|:----------------------------------------------|
  # | `disabled`       | Set to `false` to enable PagerDuty support.   |
  # | `authentication` | A hash of authentication options (see below). |
  # | `api_url`        | The PagerDuty event API endpoint.             |
  #
  # The `authentication` hash must have a key called `strategy`, whose value can
  # be either "token" (for token-based authentication) or "basic" for HTTP Basic
  # authentication. If the value is "token", an additional `token` key must be
  # present under this hash with the API user token. If the value is "basic",
  # the `user` and `password` keys must also be present under this hash.
  #
  # All PagerDuty API methods return {Service::PagerDuty::Response} objects with
  # information about the API response.

  class PagerDuty
    # @private
    HEADERS = {
        'Content-Type' => 'application/json'
    }

    # @return [String] The service key for the PagerDuty service being used in
    #   this session.
    attr_reader :service_key

    def initialize(service_key)
      @service_key = service_key
    end

    # Triggers a new incident in PagerDuty. See the PagerDuty API for more
    # details.
    #
    # @param [String] description A short description of the incident.
    # @param [String] incident_key A key shared by all duplicates of the same
    #   incident (used for de-duping). Its format is left to the programmer.
    # @param [Hash] details A JSON-serializable hash of user data to send along.
    # @return [Service::PagerDuty::Response] The API response.

    def trigger(description, incident_key=nil, details=nil)
      request 'service_key'  => service_key,
              'incident_key' => incident_key,
              'event_type'   => 'trigger',
              'description'  => description,
              'details'      => details
    end

    # Acknowledges an incident in PagerDuty. See the PagerDuty API for more
    # details.
    #
    # @param [String] incident_key The incident key returned by PagerDuty when
    #   the incident was created.
    # @param [String] description A short description of the acknowledgement.
    # @param [Hash] details A JSON-serializable hash of user data to send along.
    # @return [Service::PagerDuty::Response] The API response.

    def acknowledge(incident_key, description=nil, details=nil)
      request 'service_key'  => service_key,
              'event_type'   => 'acknowledge',
              'incident_key' => incident_key,
              'description'  => description,
              'details'      => details
    end

    # Resolves an incident in PagerDuty. See the PagerDuty API for more details.
    #
    # @param [String] incident_key The incident key returned by PagerDuty when
    #   the incident was created.
    # @param [String] description A short description of the resolution.
    # @param [Hash] details A JSON-serializable hash of user data to send along.
    # @return [Service::PagerDuty::Response] The API response.

    def resolve(incident_key, description=nil, details=nil)
      request 'service_key'  => service_key,
              'event_type'   => 'resolve',
              'incident_key' => incident_key,
              'description'  => description,
              'details'      => details
    end

    private

    def request(body)
      return nil if Squash::Configuration.pagerduty.disabled

      uri  = URI(Squash::Configuration.pagerduty.api_url)
      http = if Squash::Configuration.pagerduty[:http_proxy]
               Net::HTTP::Proxy(Squash::Configuration.pagerduty.http_proxy.host, Squash::Configuration.pagerduty.http_proxy.port)
             else
               Net::HTTP
             end

      http.start(uri.host, uri.port, use_ssl: Squash::Configuration.pagerduty.api_url.starts_with?('https://')) do |http|
        request = Net::HTTP::Post.new(uri.request_uri)
        HEADERS.merge(authentication_headers).each do |name, value|
          request[name] = value
        end
        request.body = body.to_json
        response     = http.request(request)
        return Response.new(response)
      end
    end

    def authentication_headers
      case Squash::Configuration.pagerduty.authentication.strategy
        when 'token'
          {'Authorization' => "Token token=#{Squash::Configuration.pagerduty.authentication.token}"}
        when 'basic'
          {'Authorization' => "Basic #{Base64.encode64 basic_credentials}"}
      end
    end

    def basic_credentials
      "#{Squash::Configuration.pagerduty.authentication.user}:#{Squash::Configuration.pagerduty.authentication.password}"
    end

    # A response from a PagerDuty API call. The parsed response JSON is
    # accessible as both a hash:
    #
    # ```` ruby
    # response.attributes['message']
    # ````
    #
    # or by method:
    #
    # ```` ruby
    # response.message
    # ````

    class Response
      # @return [Hash] The response attributes as parsed from the JSON.
      attr_reader :attributes
      # @return [Fixnum] The HTTP response status code.
      attr_reader :http_status

      # @private
      def initialize(http_response)
        @http_status = http_response.code.to_i
        @attributes  = JSON.parse(http_response.body)
      end

      # @return [true, false] Whether the `status` field is "success".

      def success?
        status == 'success'
      end

      # @private
      def method_missing(meth, *args, &block)
        if attributes.include?(meth.to_s)
          if args.empty?
            attributes[meth.to_s]
          else
            raise ArgumentError, "wrong number of arguments (#{args.size} for 0)"
          end
        else
          super
        end
      end

      # @private
      def respond_to?(meth)
        super || attributes.include?(meth)
      end
    end
  end
end
