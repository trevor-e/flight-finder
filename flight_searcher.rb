require 'net/http'
require 'uri'
require 'http-cookie'
require 'json'
require 'faraday'
require_relative 'flight_result'

class FlightSearcher
  attr_reader :conn, :cookie_jar, :session_id

  def initialize
    @cookie_jar = HTTP::CookieJar.new
    @conn = Faraday.new(
      url: "https://www.kayak.com",
      headers: {
        "User-Agent" => "KayakiPhone/232.0.1 iOS/17.3.1 iPhone16,1",
        "Accept-Language" => "en-US",
      }
    )
    @session_id = nil
  end

  def get_session
    response = conn.get("/flights/BOS-NAP/2024-04-30/2024-05-07?a=kayak")
    raise "Got invalid response: #{response.status}" unless response.status == 200
    response.headers['set-cookie']&.split(', ').each do |cookie|
      begin
        HTTP::Cookie.parse(cookie, response.env.url).each do |parsed_cookie|
          cookie_jar.add(parsed_cookie)
          puts "Cookie: #{parsed_cookie.name}=#{parsed_cookie.value}"
        end
      rescue => e
        puts "Skipped invalid cookie: #{e.message}"
        next
      end
    end

    @session_id = cookie_jar.cookies.find { |cookie| cookie.name == "p1.med.sid" }&.value
  end

  def find_flights(origin_airport:, destination_airport:, start_date:, end_date:)
    legs = [
      {
        origin: { locationType: "airports", airports: [origin_airport] },
        destination: { locationType: "airports", airports: [destination_airport] },
        date: start_date,
        flex: "exact",
      }
    ]
    poll_response = poll_until_finished(legs: legs)
    filter_data = poll_response[:filterData]
    sort_map = poll_response[:sortMap]
    best_flights = sort_map[:bestValue].map { |index| poll_response[:results][index] }
    flight_details = poll_response[:resultDetails].to_h { |r| [r[:resultId], r] }
    flight_legs = poll_response[:legs].map { |leg| leg.to_h { |l| [l[:id], l] } }
    airlines = poll_response[:airlines]
    flights = best_flights.map do |flight|
      details = flight_details[flight[:resultId]]
      legs = details[:legs].map.with_index { |leg, index| flight_legs[index][leg] }
      FlightResult.new(flight: flight, flight_details: details, legs: legs, airlines: airlines)
    end
    filtered_flights = flights
      .filter { |flight| flight.flight[:displayRating] >= 7.0 && flight.stops <= 1 }
      .first(20)
      .sort
    filtered_flights
  end

  private

  def poll_until_finished(legs:)
    search_id = nil
    search_body = {
      passengers: ["ADT"],
      cabinClass: "economy",
      carryOnBags: 0,
      refundableSearch: false,
      legs: legs,
      contextualSearch: false,
      pageType: "results",
      maxResults: 1500,
      sort: %w[price bestValue duration earliest],
      filterParams: {
        include: %w[airlines airports bookingSites cabinClass flexOption layover legLength equipment price quality stops stopsPerLeg departure arrival transportation]
      },
      inlineAdData: "v2",
      displayMessages: "v1",
      priceMode: "per-person",
      airports: "v1",
      covidBadge: "v1",
      transportationBadges: "v1",
      savingMessage: "v1",
      searchId: search_id
    }
    cookie_header = @cookie_jar.cookies
                              .map { |cookie| "#{cookie.name}=#{cookie.value}" }
                              .join('; ')
    poll_response = @conn.post("/i/api/search/v1/flights/poll") do |req|
      req.params['_pt_'] = 1
      req.params['_sid_'] = @session_id
      req.body = search_body.to_json
      req.headers['Cookie'] = cookie_header
      req.headers['Content-Type'] = "application/json"
      req.headers['origin'] = "https://www.kayak.com"
      req.headers['referer'] = "https://www.kayak.com/flights/BOS-NAP/#{legs[0][:date]}?a=kayak"
    end
    raise "Got invalid response: #{response.status}" unless poll_response.status == 200
    poll_response_body = JSON.parse(poll_response.body, symbolize_names: true)
    search_id = poll_response_body[:searchId]
    puts "Search ID: #{search_id} #{poll_response_body[:status]}"
    if poll_response_body[:status] == "complete"
      return poll_response_body
    else
      sleep 1
      poll_until_finished(legs: legs)
    end
  end
end
