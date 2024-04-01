require_relative '../lib/flight_result'
require_relative '../lib/flight_searcher'

begin
  flight_searcher = FlightSearcher.new
  flight_searcher.get_session
  top_flights = []
  top_flights.concat(flight_searcher.find_flights(
    origin_airport: "BOS",
    destination_airport: "NAP",
    start_date: "2024-09-01",
    end_date: nil
  ))
  top_flights.concat(flight_searcher.find_flights(
    origin_airport: "BOS",
    destination_airport: "NAP",
    start_date: "2024-09-02",
    end_date: nil
  ))
  top_flights.concat(flight_searcher.find_flights(
    origin_airport: "BOS",
    destination_airport: "NAP",
    start_date: "2024-09-03",
    end_date: nil
  ))
  top_flights.sort!
  puts "Top flights: \n#{top_flights.map(&:to_s).join("\n")}"
rescue => e
  puts "An error occurred: #{e.message}"
end
