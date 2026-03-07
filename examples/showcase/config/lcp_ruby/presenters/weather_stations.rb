define_presenter :weather_stations do
  model :weather_station
  label "Weather Stations"
  slug "weather-stations"
  icon "cloud"

  index do
    description "Demonstrates API-backed models — read-only data from a host-provided data source " \
                "(no database table). Notice: no create/edit/delete actions available (Phase 1 is read-only)."
    default_sort :name, :asc
    per_page 10
    row_click :show

    column :name, link_to: :show, sortable: true, pinned: :left
    column :country, width: "8%", sortable: true
    column :region, width: "12%", sortable: true
    column :station_type, width: "10%", renderer: :badge, options: {
      color_map: { airport: "blue", mountain: "green" }
    }, sortable: true
    column :status, width: "12%", renderer: :badge, options: {
      color_map: { active: "green", maintenance: "orange", decommissioned: "gray" }
    }, sortable: true
    column :elevation, width: "10%", renderer: :number, sortable: true
    column :last_reading_at, width: "15%", renderer: :relative_date, sortable: true
  end

  show do
    description "Read-only detail view of an external weather station record. " \
                "Data comes from a host provider, not the database."

    section "Station Details", columns: 2 do
      field :name, renderer: :heading
      field :station_type, renderer: :badge, options: {
        color_map: { airport: "blue", mountain: "green" }
      }
      field :status, renderer: :badge, options: {
        color_map: { active: "green", maintenance: "orange", decommissioned: "gray" }
      }
      field :country
      field :region
    end

    section "Location", columns: 2, description: "Geographic coordinates and altitude." do
      field :latitude, renderer: :number
      field :longitude, renderer: :number
      field :elevation, renderer: :number
    end

    section "Telemetry", columns: 1 do
      field :last_reading_at, renderer: :datetime
    end
  end

  search do
    searchable_fields :name, :country, :region
    placeholder "Search weather stations..."
  end

  action :show, type: :built_in, on: :single
end
