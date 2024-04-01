class FlightResult
  attr_accessor :flight, :flight_details, :legs, :airlines

  def initialize(flight:, flight_details:, legs:, airlines:)
    @flight = flight
    @flight_details = flight_details
    @legs = legs
    @airlines = airlines
  end

  def rating
    @flight[:displayRating]
  end

  def price
    @flight[:price][:price]
  end

  def stops
    @legs.map { |leg| leg[:stops] }.max
  end

  def duration
    @legs.map { |leg| leg[:duration] }.sum
  end

  def stops_s
    "stops=#{@legs.map { |leg| leg[:stops] }.join(',')}"
  end

  def airlines_s
    airlines = @legs.map { |leg| leg[:airlines].map { |airline| @airlines[airline.to_sym] } }.flatten.uniq
    "airlines=#{airlines.map { |a| a[:name] }.join(',')}"
  end

  def duration_s
    durations = @legs.map { |leg| leg[:duration] }.map { |duration| minutes_to_duration(duration) }
    "duration=#{durations.join(',')}"
  end

  def departure_depart_time_s
    departure_time = DateTime.parse(@legs.first[:departure])
    formatted = departure_time.strftime("%A, %B %d, %Y %H:%M")
    "depart=#{formatted}"
  end

  def departure_arrive_time_s
    departure_time = DateTime.parse(@legs.first[:arrival])
    formatted = departure_time.strftime("%A, %B %d, %Y %H:%M")
    "arrive=#{formatted}"
  end

  def url
    @flight_details[:shareUrl]
  end

  def to_s
    departure_s = "#{departure_depart_time_s} -> #{departure_arrive_time_s}"
    <<~TO_S
    https://www.kayak.com#{url}
    rating=#{rating}
    price=#{price}
    #{stops_s}
    #{duration_s}
    #{airlines_s}
    departure=#{departure_s}
    TO_S
  end

  def <=>(other)
    rating_comparison = other.rating <=> rating
    return rating_comparison unless rating_comparison.zero?

    stops_comparison = stops <=> other.stops
    return stops_comparison unless stops_comparison.zero?

    duration_comparison = duration <=> other.duration
    return duration_comparison unless duration_comparison.zero?

    price <=> other.price
  end

  private

  def minutes_to_duration(minutes)
    hours = minutes / 60
    minutes = minutes % 60
    "#{hours}h #{minutes}m"
  end
end

