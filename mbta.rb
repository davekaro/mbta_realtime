require 'sinatra'
require 'rest_client'
require 'sinatra/reloader' if development?

class Mbta < Sinatra::Application
  get '/' do
    route_params    = api_params.merge(route: "CR-Newburyport")
    begin
      response        = RestClient.get("#{api_url}/vehiclesbyroute", params: route_params)
      vehiclesbyroute = JSON.parse(response.body)
      inbound         = vehiclesbyroute["direction"].select { |d| d["direction_name"] == "Inbound" }
      outbound        = vehiclesbyroute["direction"].select { |d| d["direction_name"] == "Outbound" }
      @inbound_trips  = parse_trips(inbound)
      @outbound_trips = parse_trips(outbound)

      erb :status
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      e.message
    rescue JSON::ParserError => e
      e.message
    end
  end

  def parse_trips(directions)
    directions.flat_map do |direction|
      direction["trip"].map do |trip|
        id  = trip["trip_id"]
        lat = trip["vehicle"]["vehicle_lat"]
        lon = trip["vehicle"]["vehicle_lon"]
        schedule = parse_schedule(id)
        {
          id:       id,
          name:     trip["trip_name"],
          map_url:  map_url(lat, lon),
          lat:      lat,
          lon:      lon,
          speed:    trip["vehicle"]["speed"] || 0,
          schedule: schedule
        }
      end
    end
  end

  def parse_schedule(trip_id)
    response = RestClient.get("#{api_url}/schedulebytrip", params: api_params.merge(trip: trip_id))
    schedule = JSON.parse(response.body)
    schedule["stop"].map do |stop|
      {
        name:    stop["stop_name"],
        arrival: Time.at(stop["sch_arr_dt"].to_i).strftime("%l:%M %P")
      }
    end
  end

  def api_url
    "http://realtime.mbta.com/developer/api/v2"
  end

  def api_params
    { api_key: ENV["MBTA_API_KEY"], format: "json" }
  end

  def map_url(lat, lon)
    "https://www.google.com/maps/place/#{lat},#{lon}"
  end
end
