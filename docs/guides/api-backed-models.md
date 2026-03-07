# API-Backed Models Guide

This guide walks through integrating external data sources into your LCP application. You'll learn how to define API-backed models, configure data source adapters, set up cross-source associations, and handle common scenarios.

## When to Use API-Backed Models

Use API-backed models when your application needs to display data from external systems:

- **GIS/spatial data** — buildings, parcels from ESRI ArcGIS
- **ERP integration** — orders, products from SAP, Navision
- **Master data services** — organizational units, employee directories
- **Government registries** — land registry, company registry
- **IoT / telemetry** — sensor readings, device status

API-backed models appear in the platform UI (index pages, show pages, association selects) just like DB models, but read from external APIs instead of the database.

## Quick Start: REST JSON Adapter

### 1. Define the API Model

```yaml
# config/lcp_ruby/models/external_building.yml
model:
  name: external_building
  label: "Building"
  label_plural: "Buildings"

  data_source:
    type: rest_json
    base_url: "https://gis.example.com/api/v2"
    resource: "/buildings"
    auth:
      type: bearer
      token_env: "GIS_API_TOKEN"
    cache:
      enabled: true
      ttl: 300
      list_ttl: 60
      stale_on_error: true

  fields:
    - name: name
      type: string
    - name: address
      type: string
    - name: floors
      type: integer
    - name: status
      type: enum
      values: [active, demolished, under_construction]

  options:
    label_method: name
```

### 2. Create the Presenter

```yaml
# config/lcp_ruby/presenters/external_buildings.yml
presenter:
  name: external_buildings
  model: external_building
  slug: external-buildings

  index:
    table_columns:
      - field: name
        sortable: true
      - field: address
      - field: floors
      - field: status

  show:
    layout:
      - section: Details
        fields:
          - field: name
          - field: address
          - field: floors
          - field: status

  actions:
    single:
      - name: show
        type: built_in
```

### 3. Define Permissions

```yaml
# config/lcp_ruby/permissions/external_buildings.yml
permissions:
  model: external_building
  roles:
    admin:
      crud: [index, show]
      fields:
        readable: [name, address, floors, status]
      presenters: all
    viewer:
      crud: [index, show]
      fields:
        readable: [name, address]
```

### 4. Set the Environment Variable

```bash
export GIS_API_TOKEN="your-api-token-here"
```

The platform reads auth credentials from environment variables — never from YAML config.

## Host-Provided Data Source

When the built-in REST adapter doesn't fit your API's conventions, provide a custom data source class.

### 1. Define the Model

```yaml
# config/lcp_ruby/models/erp_product.yml
model:
  name: erp_product
  label: "Product"

  data_source:
    type: host
    provider: "Erp::ProductDataSource"

  fields:
    - name: sku
      type: string
    - name: title
      type: string
    - name: category
      type: string
    - name: unit_price
      type: decimal

  options:
    label_method: title
```

### 2. Implement the Data Source

```ruby
# app/data_sources/erp/product_data_source.rb
class Erp::ProductDataSource < LcpRuby::DataSource::Base
  def find(id)
    json = ErpClient.get("/products/#{id}")
    hydrate(json)
  end

  def search(params, sort:, page:, per:)
    query = { offset: (page - 1) * per, limit: per }
    query[:sort] = "#{sort[:field]}:#{sort[:direction]}" if sort
    params.each { |f| query[f[:field]] = f[:value] }

    json = ErpClient.get("/products", query: query)
    LcpRuby::SearchResult.new(
      records: json["items"].map { |p| hydrate(p) },
      total_count: json["total"],
      current_page: page,
      per_page: per
    )
  end

  def find_many(ids)
    json = ErpClient.post("/products/batch", body: { ids: ids })
    json["products"].map { |p| hydrate(p) }
  end

  def select_options(search: nil, label_method:, limit: 1000, **)
    query = { limit: limit }
    query[:q] = search if search.present?
    json = ErpClient.get("/products", query: query)
    json["items"].map do |p|
      record = hydrate(p)
      { value: record.id, label: record.public_send(label_method) }
    end
  end

  private

  def hydrate(json)
    model_class.new(
      id: json["productId"],
      sku: json["sku"],
      title: json["productName"],
      category: json["category"],
      unit_price: json["unitPrice"]
    )
  end
end
```

Key points:
- Inherit from `LcpRuby::DataSource::Base`
- `model_class` is available — it's the generated API model class
- `hydrate` maps API JSON fields to local field names
- `search` must return a `LcpRuby::SearchResult`

### 3. Override `find_many` for Batch APIs

The default `find_many` makes sequential `find` calls. If your API has a batch endpoint, override it for better performance:

```ruby
def find_many(ids)
  json = ErpClient.post("/products/batch", body: { ids: ids })
  json["products"].map { |p| hydrate(p) }
end
```

This is called by the batch preloader to prevent N+1 API calls on index pages.

## Cross-Source Associations

### DB Model Referencing an API Model

The most common pattern: a DB model has a foreign key pointing to an API model.

```yaml
# config/lcp_ruby/models/work_order.yml
model:
  name: work_order
  fields:
    - name: title
      type: string
      validations: [{ type: presence }]
    - name: external_building_id
      type: string
    - name: status
      type: enum
      values: [open, in_progress, done]
  associations:
    - name: external_building
      type: belongs_to
      target_model: external_building
      foreign_key: external_building_id
```

The platform generates a lazy accessor on `work_order`:
- `work_order.external_building` → fetches from API (cached per instance)
- `work_order.external_building = record` → sets FK and caches the record

On index pages, the platform batch-preloads all referenced API records in a single `find_many` call.

### Displaying Cross-Source Fields

Use dot-notation in presenter columns to display API model fields:

```yaml
# config/lcp_ruby/presenters/work_orders.yml
presenter:
  name: work_orders
  model: work_order
  slug: work-orders

  index:
    table_columns:
      - field: title
      - field: external_building.name    # dot-path into API model
      - field: status
```

### Association Select for API Target

When a form field references an API model, the platform automatically uses remote search mode:

```yaml
  form:
    sections:
      - title: Details
        fields:
          - field: title
          - field: external_building_id
            input_type: association_select
          - field: status
```

No extra configuration needed — the platform detects the API target and delegates to `lcp_select_options`.

### API Model with has_many to DB Model

An API model can have a `has_many` association pointing at a DB model. The platform generates a query-based accessor that returns a standard AR relation:

```yaml
# config/lcp_ruby/models/external_building.yml
model:
  name: external_building
  data_source:
    type: rest_json
    # ...
  fields:
    - name: name
      type: string
  associations:
    - name: work_orders
      type: has_many
      target_model: work_order
      foreign_key: external_building_id
```

The accessor `building.work_orders` returns `WorkOrder.where(external_building_id: building.id)` — a real AR relation that supports sorting, scoping, and limiting.

## Caching

### Enable Caching

```yaml
data_source:
  cache:
    enabled: true
    ttl: 300          # individual records: 5 minutes
    list_ttl: 60      # search results: 1 minute
    stale_on_error: true
```

### Stale-on-Error

When `stale_on_error: true` and the API is unreachable:
1. The platform reads from cache (even if expired)
2. Returns the stale data with a `stale: true` flag
3. The view shows a "Cached data" warning banner
4. If no cache exists, returns an error result

### Cache Keys

Records: `lcp_ruby/api/{model_name}/record/{id}`
Searches: `lcp_ruby/api/{model_name}/search/{params_hash}`

Cache invalidation is TTL-based only (no webhook invalidation in Phase 1).

## Filter Operators

API models support a subset of the filter operators available to DB models. The filter UI automatically disables unsupported operators.

### Default Operators

For `rest_json` adapters: `eq`, `not_eq`, `cont`, `lt`, `lteq`, `gt`, `gteq`, `in`, `null`, `not_null`, `start`, `end`.

### Custom Operator Set

Restrict or customize per field type:

```yaml
data_source:
  supported_operators:
    default: [eq, not_eq, cont, in]
    integer: [eq, not_eq, lt, lteq, gt, gteq]
    enum: [eq, not_eq, in]
    boolean: [eq]
```

### Host Provider Operators

Host data sources can declare operators programmatically:

```ruby
class Erp::ProductDataSource < LcpRuby::DataSource::Base
  def supported_operators
    {
      default: %i[eq not_eq cont in],
      decimal: %i[eq not_eq lt lteq gt gteq],
      boolean: %i[eq]
    }
  end
end
```

## Error Handling

### Connection Failures

When an API is unreachable:
- **Index page:** Shows an error banner with "Data unavailable" message. If cached data exists (with `stale_on_error`), shows stale data with a warning.
- **Show page:** If fetched via cross-source association, returns an `ApiErrorPlaceholder` that displays `"ModelName #id (unavailable)"`.
- **Other pages:** DB-backed content renders normally — API failures don't crash the page.

### Error Placeholder

When a cross-source association fetch fails:

```ruby
work_order.external_building
# => #<LcpRuby::DataSource::ApiErrorPlaceholder
#      id="42", model_name="external_building">
#    .to_label => "External building #42 (unavailable)"
#    .name => nil
#    .error? => true
```

Renderers can detect the placeholder and display an appropriate indicator.

## Feature Limitations

These features are **not available** for API models:

- **Soft delete** — requires DB column
- **Auditing** — requires AR callbacks
- **Userstamps** — requires DB columns
- **Tree structures** — requires recursive CTE
- **Positioning** — requires DB updates
- **Custom fields** — requires JSON column
- **Ransack** — requires ActiveRecord
- **SQL aggregates** — use service-based aggregates instead
- **Attachments** — requires Active Storage
- **Bulk operations** — requires `update_all`
- **Nested attributes** — requires AR transaction
- **Create / Edit / Delete** — Phase 2

The `ConfigurationValidator` reports errors if you enable incompatible features on an API model.

## Testing

### Integration Test Example

```ruby
RSpec.describe "API-backed model integration", type: :request do
  before do
    load_integration_metadata!("api_model")

    # Register a test data source provider
    building_class = LcpRuby.registry.model_for("external_building")
    building_class.lcp_data_source = TestBuildingProvider.new(
      model_class: building_class, config: {}
    )
    LcpRuby::DataSource::Registry.register("external_building", building_class.lcp_data_source)
    LcpRuby::DataSource::Registry.mark_available!
  end

  it "renders the index page" do
    get "/external-buildings"
    expect(response).to have_http_status(:ok)
  end

  it "renders the show page" do
    get "/external-buildings/1"
    expect(response).to have_http_status(:ok)
  end
end
```

### Mocking Data Sources in Tests

For unit tests, mock the data source on the model class:

```ruby
let(:mock_source) { instance_double(LcpRuby::DataSource::Base) }

before do
  allow(model_class).to receive(:lcp_data_source).and_return(mock_source)
  allow(mock_source).to receive(:find).with("1").and_return(
    model_class.new(id: "1", name: "Test Building")
  )
end
```

## DSL Alternative

```ruby
LcpRuby.define_model :external_building do
  label "Building"

  data_source type: :rest_json,
              base_url: "https://gis.example.com/api/v2",
              resource: "/buildings",
              auth: { type: "bearer", token_env: "GIS_API_TOKEN" },
              cache: { enabled: true, ttl: 300, list_ttl: 60, stale_on_error: true }

  field :name, :string
  field :address, :string
  field :floors, :integer
  field :status, :string, enum: { values: %w[active demolished under_construction] }

  options label_method: "name"
end
```
