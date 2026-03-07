# Host data source provider for the showcase API-backed model.
# Serves in-memory weather station data to demonstrate the feature
# without needing a real external API.
class WeatherStationProvider
  STATIONS = [
    { id: "WS-001", name: "Prague Ruzyne", country: "CZ", region: "Central Europe", latitude: 50.1008, longitude: 14.26,
      elevation: 380, station_type: "airport", status: "active", last_reading_at: "2026-03-07T08:30:00Z" },
    { id: "WS-002", name: "Bratislava Ivanka", country: "SK", region: "Central Europe", latitude: 48.1702, longitude: 17.2127,
      elevation: 133, station_type: "airport", status: "active", last_reading_at: "2026-03-07T09:00:00Z" },
    { id: "WS-003", name: "Vienna Schwechat", country: "AT", region: "Central Europe", latitude: 48.1103, longitude: 16.5697,
      elevation: 183, station_type: "airport", status: "active", last_reading_at: "2026-03-07T08:45:00Z" },
    { id: "WS-004", name: "Berlin Tegel", country: "DE", region: "Central Europe", latitude: 52.5597, longitude: 13.2877,
      elevation: 37, station_type: "airport", status: "decommissioned", last_reading_at: "2024-11-08T12:00:00Z" },
    { id: "WS-005", name: "Snezka Summit", country: "CZ", region: "Central Europe", latitude: 50.7361, longitude: 15.7397,
      elevation: 1602, station_type: "mountain", status: "active", last_reading_at: "2026-03-07T07:15:00Z" },
    { id: "WS-006", name: "High Tatras Lomnicky", country: "SK", region: "Central Europe", latitude: 49.1953, longitude: 20.2131,
      elevation: 2634, station_type: "mountain", status: "active", last_reading_at: "2026-03-07T06:00:00Z" },
    { id: "WS-007", name: "Zugspitze", country: "DE", region: "Central Europe", latitude: 47.4211, longitude: 10.9853,
      elevation: 2962, station_type: "mountain", status: "active", last_reading_at: "2026-03-07T05:30:00Z" },
    { id: "WS-008", name: "Warsaw Chopin", country: "PL", region: "Eastern Europe", latitude: 52.1657, longitude: 20.9671,
      elevation: 110, station_type: "airport", status: "active", last_reading_at: "2026-03-07T09:15:00Z" },
    { id: "WS-009", name: "Budapest Liszt", country: "HU", region: "Central Europe", latitude: 47.4399, longitude: 19.2556,
      elevation: 185, station_type: "airport", status: "active", last_reading_at: "2026-03-07T08:00:00Z" },
    { id: "WS-010", name: "Krkonose Labska", country: "CZ", region: "Central Europe", latitude: 50.7683, longitude: 15.5475,
      elevation: 1320, station_type: "mountain", status: "maintenance", last_reading_at: "2026-02-28T16:00:00Z" },
    { id: "WS-011", name: "London Heathrow", country: "GB", region: "Western Europe", latitude: 51.4700, longitude: -0.4543,
      elevation: 25, station_type: "airport", status: "active", last_reading_at: "2026-03-07T09:30:00Z" },
    { id: "WS-012", name: "Paris CDG", country: "FR", region: "Western Europe", latitude: 49.0097, longitude: 2.5478,
      elevation: 119, station_type: "airport", status: "active", last_reading_at: "2026-03-07T09:20:00Z" },
    { id: "WS-013", name: "Morske Oko", country: "SK", region: "Central Europe", latitude: 49.1919, longitude: 20.0656,
      elevation: 1395, station_type: "mountain", status: "active", last_reading_at: "2026-03-07T07:45:00Z" },
    { id: "WS-014", name: "Mont Blanc Observatory", country: "FR", region: "Western Europe", latitude: 45.8326, longitude: 6.8652,
      elevation: 4810, station_type: "mountain", status: "active", last_reading_at: "2026-03-07T04:00:00Z" },
    { id: "WS-015", name: "Zurich Kloten", country: "CH", region: "Western Europe", latitude: 47.4647, longitude: 8.5492,
      elevation: 432, station_type: "airport", status: "active", last_reading_at: "2026-03-07T09:10:00Z" }
  ].freeze

  def find(id)
    data = STATIONS.find { |s| s[:id].to_s == id.to_s }
    raise LcpRuby::DataSource::RecordNotFound, "WeatherStation with id=#{id} not found" unless data

    build_record(data)
  end

  def find_many(ids)
    id_strings = ids.map(&:to_s)
    STATIONS.select { |s| id_strings.include?(s[:id].to_s) }.map { |d| build_record(d) }
  end

  def search(params = {}, sort: nil, page: 1, per: 25)
    results = filter_stations(params)
    results = sort_stations(results, sort)

    total = results.size
    offset = (page - 1) * per
    page_records = results[offset, per] || []

    LcpRuby::SearchResult.new(
      records: page_records.map { |d| build_record(d) },
      total_count: total,
      current_page: page,
      per_page: per
    )
  end

  def select_options(search: nil, filter: {}, sort: nil, label_method: "to_label", limit: 200)
    results = STATIONS.dup
    if search.present?
      q = search.downcase
      results = results.select { |s| s[:name].downcase.include?(q) || s[:country].downcase.include?(q) }
    end
    results = sort_stations(results, sort)
    results.first(limit).map do |d|
      record = build_record(d)
      { id: record.id, label: record.respond_to?(label_method) ? record.send(label_method).to_s : record.to_s }
    end
  end

  def supported_operators
    %w[eq not_eq cont in null not_null]
  end

  private

  def build_record(data)
    model_class = LcpRuby.registry.model_for("weather_station")
    record = model_class.new
    data.each do |key, value|
      record.send(:"#{key}=", value) if record.respond_to?(:"#{key}=")
    end
    record.instance_variable_set(:@persisted, true)
    record
  end

  def filter_stations(params)
    results = STATIONS.dup
    return results if params.blank?

    # Support both array-of-hashes filter format and hash format
    filters = if params.is_a?(Array)
      params
    elsif params.is_a?(Hash)
      params.map { |field, value| { field: field.to_s, operator: "eq", value: value } }
    else
      []
    end

    filters.each do |filter|
      field = filter[:field]&.to_sym || filter["field"]&.to_sym
      operator = filter[:operator] || filter["operator"] || "eq"
      value = filter[:value] || filter["value"]
      next unless field

      results = results.select do |station|
        station_value = station[field]
        case operator
        when "eq" then station_value.to_s == value.to_s
        when "not_eq" then station_value.to_s != value.to_s
        when "cont" then station_value.to_s.downcase.include?(value.to_s.downcase)
        when "in" then Array(value).map(&:to_s).include?(station_value.to_s)
        when "null" then station_value.nil?
        when "not_null" then !station_value.nil?
        else true
        end
      end
    end

    results
  end

  def sort_stations(results, sort)
    return results unless sort

    field = (sort[:field] || sort["field"])&.to_sym
    direction = (sort[:direction] || sort["direction"] || "asc").to_s
    return results unless field

    results.sort_by { |s| s[field].to_s }.then { |sorted| direction == "desc" ? sorted.reverse : sorted }
  end
end
