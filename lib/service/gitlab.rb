module Service
  module Gitlab 

    class ApiKeyAuthentication < Faraday::Middleware
      def call(env)
        # do something with the request
        token_parameter = { private_token: Squash::Configuration.gitlab.authentication[:key]}
        
        #add your api key to every request as a parameter
        env[:url].query = Rack::Utils.parse_nested_query(env[:url].query).merge(token_parameter).to_param  

        @app.call(env).on_complete do |env|
          # do something with the response
          # env[:response] is now filled in
        end
      end

    end

    Her::API.setup :url => Squash::Configuration.gitlab.api_host do |connection|
      connection.use ApiKeyAuthentication 
      connection.use Faraday::Request::UrlEncoded
      connection.use Her::Middleware::DefaultParseJSON
      connection.use Faraday::Adapter::NetHttp
    end

    class Issue
      include Her::Model
    end
  end
end
