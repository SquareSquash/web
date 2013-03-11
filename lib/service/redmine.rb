module Service
  module Redmine 

    class ApiKeyAuthentication < Faraday::Middleware
      def call(env)
        # do something with the request
        token_parameter = { key: Squash::Configuration.redmine.authentication[:key] }

        env[:url].query = Rack::Utils.parse_nested_query(env[:url].query).merge(token_parameter).to_param  

        @app.call(env).on_complete do |env|
          # do something with the response
          # env[:response] is now filled in
        end
      end

    end

    Her::API.setup :url => Squash::Configuration.redmine.api_host do |connection|
      #connection.response :logger  # uncomment this if you need to debug your response
      connection.use ApiKeyAuthentication if Squash::Configuration.redmine.authentication.strategy == "api_key"
      connection.use Faraday::Request::UrlEncoded
      connection.use Her::Middleware::DefaultParseJSON
      connection.use Faraday::Adapter::NetHttp
    end

    class Issue
      include Her::Model
      collection_path "/issues.json"
      resource_path "/issues/:id.json"
      include_root_in_json true
      parse_root_in_json true
    end
  end
end
