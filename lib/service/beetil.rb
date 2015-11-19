module Service::Beetil
  Incident = Struct.new(:number, :name, :closed_at)
  Project  = Struct.new(:id, :name, :path)

  extend self

  VERSION = "v1"

  def projects
    send "#{VERSION}_projects"
  end

  def find_incident(beetil_number)
    send "#{VERSION}_find_incident", beetil_number
  end

  def create_incident(*args)
    send "#{VERSION}_create_incident", *args
  end

  def v1_projects
    response = v1_client.services
    things   = []

    v1_result(response, "services") do |o|
      things << Project.new(o["id"], o["name"], o["service_link"])
    end

    things
  end

  def v2_projects
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

  def v1_find_incident(beetil_number)
    response = v1_client.incident(beetil_number)
    if r = response["result"]
      i = r["incident"]
      Incident.new(i["reference_num"], i["title"], i["closed_at"])
    else
      puts response.inspect
      nil
    end
  end

  def v2_find_incident(beetil_number)
    result = client.get "/v2/incidents/#{beetil_number}?incident_properties=reference_num,title,resolved_at,closed_at"
    if r = result["object"]
      Incident.new(r["reference_num"], r["title"], r["closed_at"])
    else
      puts result.inspect
      nil
    end
  end

  def v1_create_incident(service_key, title, symptom)
    incident_data = {
      title: title,
      service_id: service_key,
      symptom: symptom,
    }
    response = v1_client.create_incident(incident_data)

    if r = response["result"]
      i = r["incident"]
      Incident.new(i["reference_num"], i["title"], i["closed_at"])
    else
      puts response.inspect
      nil
    end
  end

  def v2_create_incident(service_key, title, symptom)
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

  def v1_client
    @v1_client ||= BeetilApi::V1Client.new(api_host: ENV['BEETIL_API_HOST'], api_token: ENV['BEETIL_V1_TOKEN'])
  end

  protected
  def v1_result(response, thing)
    if oo = response["result"]
      oo[thing].each do |o|
        yield o
      end
    else
      puts response.inspect
    end
  end
end
