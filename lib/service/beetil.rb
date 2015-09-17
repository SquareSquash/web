module Service::Beetil
  Incident = Struct.new(:number, :name, :closed_at)
  Project  = Struct.new(:id, :name, :path)

  extend self

  def projects
    results = client.get "/v2/services?service_properties=id,name,path"
    if oo = results["objects"]
      oo.map do |o|
        Project.new(o["id"], o["name"], o["path"])
      end
    else
      puts results.inspect
      []
    end
  end

  def find_incident(beetil_number)
    result = client.get "/v2/incidents/#{beetil_number}?incident_properties=reference_num,title,resolved_at,closed_at"
    if r = result["object"]
      Incident.new(r["reference_num"], r["title"], r["closed_at"])
    else
      puts result.inspect
      nil
    end
  end

  def create_incident(service_key, title, symptom)
    result = client.post "/v2#{service_key}/incidents", object: {title: title, symptom: {note: symptom}}
    if r = result["object"]
      Incident.new(r["reference_num"], r["title"], r["closed_at"])
    else
      puts result.inspect
      nil
    end
  end

  def beetil_api_client
    BeetilApi::Client.new(client_id: ENV['BEETIL_CLIENT_ID'], client_secret: ENV['BEETIL_CLIENT_SECRET'], redirect_uri: ENV['BEETIL_REDIRECT_URI'], api_host: ENV['BEETIL_API_HOST'], authenticate_path: ENV['BEETIL_AUTHENTICATE_PATH'])
  end

  def client
    @client ||= beetil_api_client.token_from_refresh_token(ENV['BEETIL_REFRESH_TOKEN'])
    @client.renew_if_expired!
  end
end
