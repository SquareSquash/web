require 'net/http'

module BeetilApi
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
