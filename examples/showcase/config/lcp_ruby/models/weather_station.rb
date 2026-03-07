define_model :weather_station do
  label "Weather Station"
  label_plural "Weather Stations"

  field :name, :string, label: "Station Name"
  field :country, :string, label: "Country"
  field :region, :string, label: "Region"
  field :latitude, :float, label: "Latitude"
  field :longitude, :float, label: "Longitude"
  field :elevation, :integer, label: "Elevation (m)"
  field :station_type, :enum, label: "Type",
    values: { airport: "Airport", mountain: "Mountain" }
  field :status, :enum, label: "Status",
    values: { active: "Active", maintenance: "Maintenance", decommissioned: "Decommissioned" }
  field :last_reading_at, :datetime, label: "Last Reading"

  data_source type: :host, provider: "WeatherStationProvider"

  label_method :name
end
