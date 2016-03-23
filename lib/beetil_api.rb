require 'net/http'

module BeetilApi
  class V1Client
    attr_reader :api_host, :api_token
    def initialize(api_host: nil, api_token: nil)
      @api_host = api_host
      @api_token = api_token
    end

    def current_user
      get '/v1/users/current_user.json'
    end

    def services
      get '/v1/services.json'
    end

    def incident(number)
      get "/v1/incidents/#{number}.json?incident_properties=id,title,resolved_at,closed_at"
    end

    def create_incident(incident_data)
      post "/v1/incidents.json", "incident", incident_data
    end


    protected
    def basic_auth
      Base64.encode64 "x:#{api_token}"
    end

    def get(url)
      do_request url, Net::HTTP::Get, "Authorization" => "Basic #{basic_auth}"
    end

    def post(url, thing, data)
      nested_form_data = data.each_with_object({}) do |(k,v), hash|
        hash["#{thing}[#{k}]"] = v
      end

      do_request url, Net::HTTP::Post, "Authorization" => "Basic #{basic_auth}" do |request|
        puts nested_form_data.inspect
        request.set_form_data nested_form_data
      end
    end

    def do_request(url, request_class, headers = {})
      uri = URI.parse("#{api_host}#{url}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = request_class.new(uri.request_uri, headers.merge("Accept" => "application/json"))
      yield request if block_given?
      response = http.request(request)
      # TODO : handle error response
      JSON.parse(response.body)
    end
  end


  class Client
    def initialize(client_id: nil, client_secret: nil, redirect_uri: nil, api_host: nil, authenticate_path: nil)
      @client_id = client_id
      @client_secret = client_secret
      @redirect_uri = redirect_uri
      @api_host = api_host
      @authenticate_path = authenticate_path
    end

    def token_from_code(code, state)
      hash = authentication_request(grant_type: "authorization_code", code: code, redirect_uri: @redirect_uri, state: state)
      Token.new(self).load_from_hash(hash)
    end

    def token_from_refresh_token(refresh_token)
      Token.new(self, refresh_token: refresh_token).renew!
    end

    def authorize_url(state)
      "#{@api_host}#{@authenticate_path}?client_id=#{CGI.escape @client_id}&redirect_uri=#{CGI.escape @redirect_uri}&response_type=code&state=#{CGI.escape state}"
    end

    def authentication_request(data)
      do_request @authenticate_path, Net::HTTP::Post do |request|
        request.basic_auth(@client_id, @client_secret)
        request.set_form_data(data)
      end
    end

    def do_request(url, request_class, headers = {})
      uri = URI.parse("#{@api_host}#{url}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'

      request = request_class.new(uri.request_uri, headers)
      yield request if block_given?
      response = http.request(request)
      # TODO : handle error response
      JSON.parse(response.body)
    end
  end

  class Token
    attr_reader :access_token, :refresh_token, :expires_at

    def initialize(client, refresh_token: nil)
      @client = client
      @refresh_token = refresh_token
    end

    def load_from_hash(hash)
      raise "No access token specified" unless hash["access_token"]

      @access_token = hash["access_token"]
      @refresh_token = hash["refresh_token"]
      @expires_at = Time.now + hash["expires_in"]
      self
    end

    def get(url)
      @client.do_request url, Net::HTTP::Get, "Authorization" => "Bearer #{access_token}", "Accept" => "application/json"
    end

    def post(url, data)
      @client.do_request url, Net::HTTP::Post, "Authorization" => "Bearer #{access_token}", "Accept" => "application/json" do |request|
        puts data.inspect
        #TODO, there's a bug here with nested form params
        request.set_form_data data
      end
    end

    def renew!
      load_from_hash @client.authentication_request(grant_type: "refresh_token", refresh_token: refresh_token)
    end

    def expired?
      expires_at.nil? || expires_at < 15.seconds.from_now
    end

    def renew_if_expired!
      renew! if expired?
      self
    end
  end
end
