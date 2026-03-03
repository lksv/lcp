# Design: API-Backed Models (External Data Sources)

**Status:** Proposed
**Date:** 2026-03-03

## Problem

The platform currently assumes all models are backed by an internal database — `ModelFactory::Builder` creates ActiveRecord classes, `SchemaManager` creates tables, and controllers use AR query chains (`where`, `order`, `ransack`, `page`). Every field, every association, every search operation goes through SQL.

Real-world information systems frequently need to display and work with data that lives elsewhere:

- **GIS/spatial data** — buildings, parcels, infrastructure from ESRI ArcGIS or similar
- **ERP integration** — orders, invoices, products from SAP, Navision, or custom ERP APIs
- **Master data services** — organizational units, cost centers, employee directories from a central MDM
- **Government registries** — land registry, company registry, address database (RÚIAN, ARES)
- **IoT / telemetry** — sensor readings, device status from a time-series API

Today, a host application must bypass the platform entirely to integrate external data — writing custom controllers, views, and association logic. This defeats the purpose of a low-code platform.

### What Users Cannot Do Today

- Define a model in YAML that reads from an external API instead of the database
- Reference external records from DB-backed models (e.g., `building_id` pointing to an ESRI geometry)
- Display external data in standard LCP index/show pages with permissions, renderers, and presenters
- Search and filter external data through the platform's filter UI
- Use external records as association select options in forms

## Goals

- Define API-backed models in YAML with the same field/presenter/permission structure as DB models
- Read-only access to external data through standard LCP views (index, show)
- Cross-source associations — DB models can reference API models via foreign keys
- Association select dropdowns populated from API data
- Pluggable adapter architecture — REST JSON built-in, extensible to GraphQL, SOAP, or host-provided implementations
- Configurable caching with TTL per model
- Graceful degradation — API failures do not crash pages that also contain DB-backed data
- Clear, documented feature limitations versus DB-backed models

## Non-Goals

- Making API models behave identically to AR models (no Ransack, no SQL aggregation, no transactions)
- Write operations in the first version (CRUD-ready architecture, but readonly MVP)
- Real-time data streaming or WebSocket subscriptions
- API schema auto-discovery or code generation from OpenAPI/Swagger specs
- Proxy mode (platform acting as API gateway for other consumers)
- Offline-first or sync-based data access

## Design

### Model YAML Configuration

API-backed models use the same `fields` and `associations` structure as DB models, with an additional `data_source` key:

```yaml
# config/lcp_ruby/models/external_building.yml
name: external_building

data_source:
  type: rest_json
  base_url: "https://gis.example.com/api/v2"
  resource: "/buildings"
  auth:
    type: bearer
    token_env: "GIS_API_TOKEN"
  pagination:
    style: offset_limit        # offset_limit | cursor | page_number
    default_per_page: 25
    max_per_page: 100
  timeout: 10
  cache:
    enabled: true
    ttl: 300                   # seconds, individual records
    list_ttl: 60               # seconds, search/list results
    stale_on_error: true       # serve expired cache when API is down
  field_mapping:               # remote field name → local field name
    buildingNumber: number
    streetAddress: address
    geoJson: geometry

fields:
  number:
    type: string
  address:
    type: string
  geometry:
    type: json
    readonly: true
  status:
    type: enum
    values: [active, demolished, under_construction]
  built_year:
    type: integer
```

The `data_source.type` key determines how the model is built:

| `type` | Description |
|--------|-------------|
| *(omitted)* or `db` | Standard ActiveRecord model with database table (current behavior) |
| `rest_json` | Built-in REST/JSON adapter with configurable endpoints |
| `host` | Host application provides a Ruby class implementing the data source contract |

#### Host-Provided Data Source

```yaml
# config/lcp_ruby/models/erp_order.yml
name: erp_order

data_source:
  type: host
  provider: "Erp::OrderDataSource"

fields:
  order_number: { type: string }
  customer_name: { type: string }
  total: { type: decimal }
```

The host class implements the data source contract:

```ruby
# app/data_sources/erp/order_data_source.rb
class Erp::OrderDataSource < LcpRuby::DataSource::Base
  def find(id)
    response = ErpClient.get("/orders/#{id}")
    hydrate(response)
  end

  def search(params, sort:, page:, per:)
    response = ErpClient.get("/orders", query: translate(params, sort, page, per))
    SearchResult.new(
      records: response["items"].map { |r| hydrate(r) },
      total_count: response["total"],
      current_page: page,
      per_page: per
    )
  end

  def find_many(ids)
    response = ErpClient.get("/orders", query: { ids: ids.join(",") })
    response["items"].map { |r| hydrate(r) }
  end

  def select_options(search: nil, filter: nil, sort: nil, label_method:, limit: 1000)
    # Return [{value: id, label: display_text}, ...]
  end

  private

  def hydrate(json)
    @model_class.new(
      id: json["orderNumber"],
      customer_name: json["customerName"],
      total: json["totalAmount"]
    )
  end
end
```

#### REST JSON Adapter Configuration

The built-in `rest_json` adapter maps CRUD operations to standard REST endpoints:

```yaml
data_source:
  type: rest_json
  base_url: "https://api.example.com/v2"
  resource: "/buildings"
  auth:
    type: bearer               # bearer | basic | header
    token_env: "API_TOKEN"     # reads from ENV
    # basic auth:
    # type: basic
    # username_env: "API_USER"
    # password_env: "API_PASS"
    # custom header:
    # type: header
    # header_name: "X-Api-Key"
    # value_env: "API_KEY"
  endpoints:                   # optional, defaults to REST conventions
    find: "GET /buildings/:id"
    search: "GET /buildings"
    # Phase 2 (CRUD):
    # create: "POST /buildings"
    # update: "PUT /buildings/:id"
    # destroy: "DELETE /buildings/:id"
  pagination:
    style: offset_limit
    params:                    # map LCP params to API params
      page: "offset"
      per: "limit"
    response:                  # map API response to LCP structure
      records: "data.items"    # dot-path into response JSON
      total: "data.totalCount"
  id_field: "buildingId"       # which response field is the primary key
  timeout: 10
  field_mapping:
    buildingNumber: number
    streetAddress: address
```

### Model Class Generation

`ModelFactory::Builder` detects `data_source.type` and branches:

- **`db` (default):** Current behavior — creates AR class, runs SchemaManager, applies all applicators.
- **`api`:** Creates ActiveModel class with data source adapter attached. Skips SchemaManager, skips AR-specific applicators (associations via AR macros, Ransack, positioning, tree CTE). Applies compatible applicators (validations, transforms, computed fields, label method).

The generated API model class:

```ruby
# Generated at boot (conceptual, not literal code)
class LcpRuby::Dynamic::ExternalBuilding
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Serialization
  include LcpRuby::ApiModelConcern

  # From YAML fields
  attribute :id, :string
  attribute :number, :string
  attribute :address, :string
  attribute :geometry, :string  # JSON stored as string
  attribute :status, :string
  attribute :built_year, :integer

  # Platform integration
  def self.model_name
    ActiveModel::Name.new(self, LcpRuby::Dynamic, "ExternalBuilding")
  end

  def persisted? = id.present?
  def to_param = id.to_s
  def to_label = public_send(self.class.lcp_label_field)

  # Data source (set by builder)
  class << self
    attr_accessor :lcp_data_source

    def find(id) = lcp_data_source.find(id)
    def find_many(ids) = lcp_data_source.find_many(ids)
    def lcp_search(...) = lcp_data_source.search(...)
    def lcp_select_options(...) = lcp_data_source.select_options(...)
    def lcp_api_model? = true
  end
end
```

### Data Source Contract

```ruby
module LcpRuby
  module DataSource
    class Base
      attr_reader :model_class, :config

      def initialize(model_class:, config:)
        @model_class = model_class
        @config = config
      end

      # --- Phase 1: Read-only ---

      # Fetch a single record by ID.
      # Returns: model instance or raises RecordNotFound
      def find(id)
        raise NotImplementedError
      end

      # Fetch multiple records by IDs (batch).
      # Default: N sequential find() calls. Override for batch API support.
      # Returns: array of model instances
      def find_many(ids)
        ids.map { |id| find(id) }
      end

      # Search/filter/paginate records.
      # params: hash of filter parameters (translated from LCP filter UI)
      # sort: { field: "name", direction: "asc" }
      # page: integer (1-based)
      # per: integer (records per page)
      # Returns: LcpRuby::SearchResult
      def search(params, sort:, page:, per:)
        raise NotImplementedError
      end

      # Count records matching filter params.
      # Returns: integer
      def count(params = {})
        search(params, sort: nil, page: 1, per: 1).total_count
      end

      # Fetch options for association select dropdowns.
      # Returns: [{value: id, label: text}, ...]
      def select_options(search: nil, filter: nil, sort: nil,
                         label_method:, limit: 1000)
        raise NotImplementedError
      end

      # --- Phase 2: CRUD (raise ReadonlyError by default) ---

      def save(record)
        raise ReadonlyError, "#{self.class.name} does not support writes"
      end

      def destroy(record)
        raise ReadonlyError, "#{self.class.name} does not support writes"
      end

      def writable? = false
    end

    class ReadonlyError < StandardError; end
    class ConnectionError < StandardError; end
    class RecordNotFound < StandardError; end
  end
end
```

### SearchResult — Kaminari-Compatible Wrapper

All API searches return a `SearchResult` that implements the subset of Kaminari's interface that views actually use:

```ruby
module LcpRuby
  class SearchResult
    include Enumerable

    attr_reader :records, :total_count, :current_page, :per_page
    attr_accessor :error, :message, :stale

    def initialize(records:, total_count:, current_page:, per_page:,
                   error: nil, message: nil, stale: false)
      @records = records
      @total_count = total_count
      @current_page = current_page
      @per_page = per_page
      @error = error
      @message = message
      @stale = stale
    end

    def each(&block) = @records.each(&block)
    def size = @records.size
    def empty? = @records.empty?
    def to_a = @records.dup

    # Kaminari-compatible interface
    def total_pages = (total_count.to_f / per_page).ceil
    def limit_value = per_page
    def first_page? = current_page == 1
    def last_page? = current_page >= total_pages
    def count = total_count

    # Error state
    def stale? = @stale
    def error? = @error.present?
  end
end
```

### Cross-Source Associations

The key use case: a DB-backed model has a foreign key that references an API-backed model.

```yaml
# config/lcp_ruby/models/work_order.yml  (DB model)
name: work_order

fields:
  title: { type: string, required: true }
  building_id: { type: string }
  priority: { type: enum, values: [low, medium, high] }

associations:
  - name: building
    type: belongs_to
    target_model: external_building   # ← API model
```

Standard AR `belongs_to` cannot work here — there is no SQL table to JOIN. Instead, the platform generates a **lazy accessor** that fetches from the API:

```ruby
# On the DB model (work_order), instead of AR belongs_to:
define_method(:building) do
  fk_value = read_attribute("building_id")
  return nil if fk_value.blank?

  # Instance-level cache (cleared on reload)
  ivar = :@_api_assoc_building
  cached = instance_variable_get(ivar)
  return cached if cached && cached.id.to_s == fk_value.to_s

  target_class = LcpRuby.registry.model_for("external_building")
  result = target_class.find(fk_value)
  instance_variable_set(ivar, result)
  result
end

define_method(:building=) do |record|
  write_attribute("building_id", record&.id)
  instance_variable_set(:@_api_assoc_building, record)
end
```

#### Batch Preloading for N+1 Prevention

When displaying a list of work orders with `building.address` as a column, naive lazy loading causes N+1 API calls. The platform provides batch preloading:

```ruby
# After loading DB records, before rendering:
# Collect all building_ids → single API call → distribute results
module LcpRuby::ApiPreloader
  def self.preload(records, assoc_name, assoc_def)
    fk_field = assoc_def.foreign_key
    ids = records.filter_map { |r| r.read_attribute(fk_field) }.uniq
    return if ids.empty?

    target_class = LcpRuby.registry.model_for(assoc_def.target_model)
    fetched = target_class.find_many(ids)
    index = fetched.index_by { |r| r.id.to_s }

    records.each do |record|
      fk = record.read_attribute(fk_field).to_s
      record.instance_variable_set(:"@_api_assoc_#{assoc_name}", index[fk])
    end
  end
end
```

`IncludesResolver` detects cross-source associations and calls `ApiPreloader` instead of AR `includes`/`eager_load`.

#### Association Select in Forms

When a form field references an API model, the options builder delegates to the model's data source:

```yaml
# config/lcp_ruby/presenters/work_orders.yml
form:
  sections:
    - fields:
        - field: building_id
          input_type: association_select
          input_options:
            label_method: "number"
            search: true          # remote search via API
```

`AssociationOptionsBuilder` checks if the target model is API-backed. If so, it calls `lcp_select_options` instead of building an AR query.

#### What Works and What Does Not

| Feature | DB → DB | DB → API | API standalone |
|---------|---------|----------|---------------|
| Show page: `building.address` | AR preload | Lazy fetch + batch preload | Direct field access |
| Form select dropdown | AR query | `lcp_select_options` | N/A (API model has no FK to itself) |
| Index column: `building.number` | AR eager_load | Batch preload (single API call) | Direct field access |
| Ransack search across association | JOIN + WHERE | Not supported | Not supported |
| Quick search on FK display value | SQL LIKE | Not supported (search own fields only) | Own data source search |
| Sorting by associated field | ORDER BY JOIN | Not supported (sort own fields only) | Own data source sort |

### Controller Integration

The controller needs branching at specific points where DB and API models diverge. The branching is localized — most of the controller flow (presenter resolution, permission checks, parameter building, view rendering) is identical.

**Points of divergence in ResourcesController / ApplicationController:**

| Method | DB model | API model |
|--------|----------|-----------|
| `find_record` | `@model_class.find(id)` | `@model_class.find(id)` — same interface |
| `apply_advanced_search` | Ransack pipeline (7 steps) | `@model_class.lcp_search(translated_params, sort:, page:, per:)` |
| `paginate` | `scope.page(n).per(m)` | Already paginated in SearchResult |
| `apply_sort` | `scope.order(field => dir)` | Passed as parameter to `lcp_search` |
| `record_count` | `scope.count` | `SearchResult#total_count` |
| `select_options` | `build_options_query` (AR) | `target_class.lcp_select_options(...)` |
| `aggregate` | `scope.sum(field)` | Not supported (returns nil) |
| `build_tree_data` | `scope.pluck(:id, :parent_id)` | Not supported |
| `create` / `update` | AR `save` | `lcp_data_source.save(record)` — Phase 2 |
| `destroy` | AR `destroy!` | `lcp_data_source.destroy(record)` — Phase 2 |

Detection method:

```ruby
# ApplicationController
def api_model?
  @model_definition.data_source_type != :db
end
```

### Search and Filtering

API models do not use Ransack. Instead, the platform translates filter parameters into a generic filter hash and passes it to the data source.

The filter translation happens in a new `ApiFilterTranslator` that maps LCP filter operators to a portable format:

```ruby
# Input: Ransack-style params from the filter UI
{ "name_cont" => "tower", "status_eq" => "active", "built_year_gteq" => "1990" }

# Output: Portable filter hash for the data source
{
  filters: [
    { field: "name", operator: "contains", value: "tower" },
    { field: "status", operator: "eq", value: "active" },
    { field: "built_year", operator: "gte", value: 1990 }
  ]
}
```

The built-in `RestJson` adapter translates this into query parameters. The `Host` adapter passes it as-is to the provider class. Each adapter decides how to map operators to its backend.

Supported filter operators for API models (subset of the full Ransack set):

| Operator | Meaning |
|----------|---------|
| `eq` | Equals |
| `not_eq` | Not equals |
| `cont` | Contains (substring) |
| `lt`, `lteq`, `gt`, `gteq` | Numeric/date comparisons |
| `in` | Value in list |
| `null`, `not_null` | Null checks |
| `start`, `end` | String prefix/suffix |

Complex operators (`matches`, `does_not_match`, multi-level OR/AND) are not supported for API models. The filter UI disables unsupported operators when the presenter's model is API-backed.

### Caching

Caching is implemented as a decorator wrapping the data source — transparent to the rest of the system:

```
DataSource::Base (contract)
    ↓
DataSource::RestJson (HTTP calls)
    ↓ wrapped by
DataSource::CachedWrapper (Rails.cache with TTL)
    ↓ wrapped by
DataSource::ResilientWrapper (error handling, stale fallback)
```

Configuration:

```yaml
data_source:
  cache:
    enabled: false            # default: disabled
    ttl: 300                  # individual record cache (seconds)
    list_ttl: 60              # search/list result cache (seconds)
    stale_on_error: true      # serve expired cache when API is down
```

When `stale_on_error: true` and the API is unreachable:
1. Try to read from cache (even if expired)
2. If found, return the stale data with `stale: true` flag
3. If not found, return an error result

Cache keys are namespaced per model: `lcp_ruby/api/{model_name}/record/{id}` and `lcp_ruby/api/{model_name}/search/{params_hash}`.

Cache invalidation: TTL-based only. No webhook or push invalidation in Phase 1. Future phases could add cache-busting via ETags, conditional GET, or webhook listeners.

### Error Handling and Graceful Degradation

API failures must not crash the page. The platform handles errors at three levels:

**Level 1 — Data source level:** `ResilientWrapper` catches connection errors, timeouts, and HTTP errors. Returns error-flagged results instead of raising.

**Level 2 — Cross-source association level:** When a lazy accessor fails to fetch an API record, it returns an error placeholder instead of crashing the show page:

```ruby
# In the lazy accessor
rescue LcpRuby::DataSource::ConnectionError => e
  Rails.logger.error(
    "[LcpRuby::API] #{target_model_name}.find(#{fk_value}) failed: #{e.message}"
  )
  LcpRuby::ApiErrorPlaceholder.new(
    id: fk_value,
    model_name: target_model_name,
    error: e
  )
end
```

The error placeholder responds to `to_label` with a fallback like `"Building #42 (unavailable)"` and to any field getter with `nil`. Renderers can detect the placeholder and display an appropriate indicator.

**Level 3 — View level:** Templates check for error state and display a warning banner while rendering the rest of the page normally:

```
┌─────────────────────────────────────────────────┐
│ ⚠ Building data is temporarily unavailable.     │
│   Showing cached data from 5 minutes ago.       │
├─────────────────────────────────────────────────┤
│ Work Order: WO-2024-001                         │
│ Title: Roof repair                              │
│ Building: Building #42 (cached)                 │
│ Priority: High                                  │
│ Status: Open                                    │
└─────────────────────────────────────────────────┘
```

### Feature Availability Matrix

Not all platform features work with API-backed models. The platform documents and enforces these limitations:

| Feature | DB model | API model | Notes |
|---------|----------|-----------|-------|
| Index view | Yes | Yes | Via `lcp_search` |
| Show view | Yes | Yes | Via `find` |
| Create / Edit / Delete | Yes | Phase 2 | Architecture ready, `ReadonlyError` by default |
| Permissions (field-level) | Yes | Yes | PermissionEvaluator is data-source agnostic |
| Permissions (record_rules) | Yes | Yes | ConditionEvaluator works on attributes |
| Display renderers | Yes | Yes | Renderers work on field values |
| View slots | Yes | Yes | SlotContext is data-source agnostic |
| Custom actions | Yes | Phase 2 | Need writable data source |
| Events | Yes | Yes | Dispatcher is agnostic |
| Quick search | Yes | Limited | Delegated to data source, not SQL LIKE |
| Advanced filters | Yes | Subset | Supported operators only, no Ransack |
| Saved filters | Yes | Subset | Condition-based filters work, scope-based do not |
| Ransack | Yes | No | Requires ActiveRecord |
| Aggregation (sum/avg) | Yes | No | Requires SQL |
| Tree structures | Yes | No | Requires recursive CTE |
| Positioning | Yes | No | Requires DB updates |
| Soft delete | Yes | No | Requires DB column |
| Auditing | Yes | No | Requires AR callbacks |
| Custom fields | Yes | No | Requires JSON column |
| Userstamps | Yes | No | Requires DB columns |
| Attachments | Yes | No | Requires Active Storage |
| Bulk operations | Yes | No | Requires `update_all` |
| Associations (as target of belongs_to) | Yes | Yes | Lazy accessor + batch preload |
| Associations (as source of belongs_to) | Yes | Limited | FK fields work, no JOINs |
| Reverse associations (API has_many DB) | Yes | Yes | Query-based accessor, returns AR relation |
| Reverse associations (API has_many API) | Yes | No | Future extension |
| Nested attributes | Yes | No | Requires AR transaction |

`ConfigurationValidator` enforces these constraints at boot time — if an API model YAML enables `auditing: true` or `soft_delete: true`, the validator reports an error.

### Presenter Configuration

API model presenters work the same as DB model presenters, with automatic restrictions:

```yaml
# config/lcp_ruby/presenters/external_buildings.yml
model: external_building
slug: buildings

table:
  columns: [number, address, status, built_year]
  default_sort: number
  # No aggregate_columns (not supported)

search:
  quick_search_fields: [number, address]
  advanced_filter:
    enabled: true
    # Operator list automatically limited to supported subset

show:
  sections:
    - title: details
      fields: [number, address, geometry, status, built_year]

actions:
  - type: built_in
    name: show
  # No edit/create/destroy in Phase 1 (readonly)
```

### Schema Validation (Optional)

The platform does **not** validate API model schemas against the actual API at boot time. This avoids boot failures when an external API is temporarily unavailable.

Instead, the platform provides:

**Runtime warnings (development/test only):** On the first successful API response, the adapter logs warnings about field mismatches:

```
[LcpRuby::API] external_building: response contains unmapped fields: ["lastModified", "ownerRef"]
[LcpRuby::API] external_building: configured field "demolition_date" not found in response
```

**Rake task for explicit validation:**

```bash
bundle exec rake lcp_ruby:validate_api_schemas
# Calls each API model's endpoint, compares response fields against YAML definition
# Reports: missing fields, extra fields, type mismatches
```

This approach balances safety (developers see mismatches) with resilience (boot never fails due to external APIs).

## Usage Examples

### Example 1: GIS Building Integration

A facility management app tracks work orders. Buildings come from ESRI ArcGIS.

```yaml
# config/lcp_ruby/models/external_building.yml
name: external_building
data_source:
  type: rest_json
  base_url: "https://gis.company.com/arcgis/rest/services/Buildings/query"
  auth:
    type: bearer
    token_env: "ARCGIS_TOKEN"
  pagination:
    style: offset_limit
  cache:
    enabled: true
    ttl: 600
    list_ttl: 120
    stale_on_error: true
  field_mapping:
    OBJECTID: id
    BUILDING_NUM: number
    STREET_ADDR: address
    STATUS: status

fields:
  number: { type: string }
  address: { type: string }
  status: { type: string }
  floor_count: { type: integer }
```

```yaml
# config/lcp_ruby/models/work_order.yml
name: work_order
fields:
  title: { type: string, required: true }
  building_id: { type: string }
  description: { type: text }
  priority: { type: enum, values: [low, medium, high] }
  status: { type: enum, values: [open, in_progress, done] }

associations:
  - name: building
    type: belongs_to
    target_model: external_building
```

```yaml
# config/lcp_ruby/presenters/work_orders.yml
model: work_order
slug: work-orders

table:
  columns: [title, building.address, priority, status]
  default_sort: created_at

form:
  sections:
    - fields:
        - field: title
        - field: building_id
          input_type: association_select
          input_options:
            label_method: "number"
            search: true
        - field: description
        - field: priority
        - field: status
```

### Example 2: Host-Provided ERP Data

A manufacturing app needs product catalog data from an internal ERP. The host app provides the data source.

```yaml
# config/lcp_ruby/models/erp_product.yml
name: erp_product
data_source:
  type: host
  provider: "Erp::ProductDataSource"

fields:
  sku: { type: string }
  name: { type: string }
  category: { type: string }
  unit_price: { type: decimal }
  in_stock: { type: boolean }
```

```ruby
# app/data_sources/erp/product_data_source.rb
class Erp::ProductDataSource < LcpRuby::DataSource::Base
  def find(id)
    json = ErpClient.get("/products/#{id}")
    hydrate(json)
  end

  def find_many(ids)
    json = ErpClient.post("/products/batch", body: { ids: ids })
    json["products"].map { |p| hydrate(p) }
  end

  def search(params, sort:, page:, per:)
    query = { offset: (page - 1) * per, limit: per }
    query[:sort] = "#{sort[:field]}:#{sort[:direction]}" if sort
    params[:filters]&.each { |f| query[f[:field]] = f[:value] }

    json = ErpClient.get("/products", query: query)
    LcpRuby::SearchResult.new(
      records: json["items"].map { |p| hydrate(p) },
      total_count: json["total"],
      current_page: page,
      per_page: per
    )
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
      name: json["productName"],
      category: json["category"],
      unit_price: json["unitPrice"],
      in_stock: json["stockQuantity"].to_i > 0
    )
  end
end
```

## General Implementation Approach

### Boot-Time Flow

The existing boot sequence (in `LcpRuby::Engine` initializer) extends with one branch:

1. `Metadata::Loader` parses YAML — no changes needed, `data_source` is just another key in the model definition.
2. `ModelFactory::Builder.build(model_definition)`:
   - If `data_source_type == :db` → current flow (AR class, SchemaManager, all applicators).
   - If `data_source_type != :db` → new flow: build ActiveModel class, attach data source adapter, apply compatible applicators only.
3. `LcpRuby.registry.register(name, model_class)` — no changes, registry stores both AR and API model classes.
4. New: `DataSource::Setup.apply!(loader)` — instantiates and attaches data source adapters, wraps with cache/resilient decorators.
5. Existing subsystems (`Presenter::Resolver`, `Authorization::PolicyFactory`, etc.) work unchanged — they read from the registry and metadata, not from AR directly.

### Data Source Adapter Stack

Data source adapters are composed via decorators:

```
                        ┌─────────────────────────┐
                        │   ResilientWrapper       │ ← catches errors, returns fallbacks
                        │   ┌─────────────────┐   │
                        │   │ CachedWrapper    │   │ ← Rails.cache with TTL
                        │   │ ┌─────────────┐ │   │
                        │   │ │ RestJson     │ │   │ ← actual HTTP calls
                        │   │ └─────────────┘ │   │
                        │   └─────────────────┘   │
                        └─────────────────────────┘
```

For `type: host`, the stack is: `ResilientWrapper → CachedWrapper (if enabled) → Host (delegates to provider class)`.

### Cross-Source Association Detection

`AssociationApplicator` already resolves the target model class via `LcpRuby.registry.model_for(assoc.target_model)`. The new logic checks whether the source and target are DB or API models and picks the right strategy:

| Source | Target | Association type | Strategy |
|--------|--------|------------------|----------|
| DB | DB | any | Standard AR macros (current behavior) |
| DB | API | `belongs_to` | Lazy accessor with instance cache + batch `ApiPreloader` |
| API | DB | `belongs_to` | Lazy accessor calling AR `.find(fk_value)` |
| API | DB | `has_many` | Query-based accessor: `TargetModel.where(fk: self.id)` → returns AR relation |
| DB | API | `has_many` | Lazy accessor calling target's `lcp_data_source.search(filter: {fk: id})` |
| API | API | `belongs_to` | Lazy accessor calling target's `find(fk_value)` via data source |
| API | API | `has_many` | Not supported in Phase 1 |

The **API → DB `has_many`** case is particularly clean because the accessor returns a real AR relation. The existing `association_list` partial works unchanged — it can call `.reorder()`, `.limit()`, `.public_send(scope_name)` on the result. There is no N+1 concern because show pages have a single parent record.

### Controller Branching Strategy

Rather than scattering `if api_model?` checks throughout the controller, the divergent logic is extracted into a strategy object:

```ruby
# Conceptual design — not literal implementation
class QueryStrategy
  def self.for(model_class, model_definition)
    if model_definition.data_source_type == :db
      DatabaseQueryStrategy.new(model_class)
    else
      ApiQueryStrategy.new(model_class)
    end
  end
end
```

The controller calls `@query_strategy.search(params, sort:, page:, per:)` and gets back either an AR relation (wrapped for compatibility) or a `SearchResult`. Both respond to `each`, `total_count`, `current_page`, etc.

### Phase 2: CRUD Extension Points

The architecture is designed so that adding write operations requires:

1. Data source classes override `save(record)` and `destroy(record)`, set `writable? = true`.
2. Controller's create/update/destroy actions check `api_model?` and delegate to data source.
3. Presenter adds `edit`, `create`, `destroy` actions.
4. Validation errors from the API are mapped to `ActiveModel::Errors` on the record.

No architectural changes are needed — only filling in the method implementations.

## Decisions

1. **Virtual model approach (ActiveModel, not AR facade).** API models are ActiveModel classes, not ActiveRecord subclasses pretending to talk to a database. This avoids the fragility of simulating AR internals and makes the boundary explicit. The tradeoff — some features (Ransack, Kaminari, aggregation) require separate handling — is acceptable because those features fundamentally depend on SQL.

2. **Localized controller branching, not DataSource abstraction layer.** The controller branches at ~7 specific points rather than routing all operations through a unified DataSource interface. This avoids a costly refactoring of the entire controller and keeps DB-backed models on the fast, well-tested AR path. The branching is contained in a strategy object to stay clean.

3. **Cross-source associations via lazy accessors, not AR macros.** When a DB model references an API model, the platform generates method-based accessors with instance caching and batch preloading support, rather than trying to make AR `belongs_to` work without a SQL table.

4. **Cache as a decorator, not embedded in the adapter.** Caching wraps the data source transparently. The adapter itself is pure I/O. This keeps adapters simple and makes caching behavior consistent across adapter types.

5. **No boot-time schema validation.** The platform trusts the YAML configuration and does not call external APIs during boot. Runtime warnings and a rake task provide schema drift detection without risking boot failures.

6. **Readonly MVP with CRUD-ready contract.** The data source contract includes `save` and `destroy` methods that raise `ReadonlyError` by default. Phase 2 only requires overriding these methods — no contract changes.

7. **Filter operators defined at model level, not presenter level.** The model (via its `data_source` config) declares which filter operators it supports — because the model knows its data source capabilities. The presenter only controls which fields appear in the filter UI. `FilterMetadataBuilder` reads operators from the model definition and the filter UI disables unsupported operators automatically.

8. **Best-effort compensation for cross-source writes (Phase 2).** When a DB transaction includes API calls, the platform attempts to roll back DB changes if the API call fails. This is explicitly documented as best-effort, not guaranteed — if the DB commit succeeds before an API failure is detected (e.g., in `after_commit`), the DB change persists. For strict consistency, host providers should implement their own saga/compensation logic.

9. **Reverse associations (API → DB) via query-based accessors.** When an API model has `has_many` pointing at a DB model, the platform generates a method that returns an AR relation (`TargetModel.where(fk: self.id)`). This integrates with the existing `association_list` partial without changes — sorting, scoping, limiting, and display templates all work because the result is a standard AR relation.

10. **Rate limiting deferred but architecture-ready.** The decorator-based data source stack supports adding a `RateLimitWrapper` between `ResilientWrapper` and `CachedWrapper` without changing any adapter or controller code. Not implemented in Phase 1.

### Reverse Associations (API → DB)

An API model can conceptually "have many" DB records. For example, an `external_building` has many `work_orders` in the local database. The platform supports this through the existing `association_list` section mechanism — no new section type is needed.

**How it works:**

The API model's YAML declares a `has_many` association pointing at a DB model:

```yaml
# config/lcp_ruby/models/external_building.yml
name: external_building
data_source:
  type: rest_json
  # ...

fields:
  number: { type: string }
  address: { type: string }

associations:
  - name: work_orders
    type: has_many
    target_model: work_order
    foreign_key: building_id
```

The platform generates a **query-based accessor** on the API model class:

```ruby
# Generated on LcpRuby::Dynamic::ExternalBuilding
define_method(:work_orders) do
  target_class = LcpRuby.registry.model_for("work_order")
  target_class.where(building_id: id)
end
```

This returns a standard AR relation. The `association_list` partial already handles AR relations — it can call `.reorder()`, `.limit()`, `.public_send(scope_name)` on the result, and it works exactly like a DB-to-DB `has_many`.

The presenter uses the standard `association_list` section:

```yaml
# config/lcp_ruby/presenters/external_buildings.yml
show:
  layout:
    - title: details
      fields: [number, address, status]
    - title: work_orders
      type: association_list
      association: work_orders
      display_template: default
      link: true
      sort: { created_at: desc }
      limit: 10
```

**What works:**

| Feature | Behavior |
|---------|----------|
| Display template | Works — target is a DB model, full FieldValueResolver support |
| Sorting | Works — AR relation supports `.reorder()` |
| Scoping | Works — named scopes on the DB model |
| Limit | Works — `.limit(n)` |
| Linking to target show page | Works — target has a presenter with a slug |
| Permissions on target fields | Works — `PermissionEvaluator` for the target model |
| Preloading nested associations | Works — `IncludesResolver` detects template deps |

**What does not work:**

| Feature | Reason |
|---------|--------|
| AR preloading of the `has_many` itself | There is no AR association to preload. But this is fine — on a show page there is only one parent record, so the query-based accessor runs once (one SQL query, not N+1). |
| `includes(work_orders: :assignee)` | Cannot chain AR `includes` on the accessor. Nested preloading must be done after fetching: `Preloader.new(records: work_orders, associations: [:assignee]).call` |

**Important constraint:** This only works for **API → DB** direction (the "many" side is in the database). API → API `has_many` is not supported in the `association_list` partial because the partial relies on AR relation methods (`.reorder`, `.limit`, named scopes). A future extension could add support by delegating to the target's data source search.

**The three directions:**

| Direction | Association type | Implementation |
|-----------|-----------------|----------------|
| DB → API | `belongs_to` | Lazy accessor with instance cache + batch preload |
| API → DB | `has_many` | Query-based accessor returning AR relation |
| DB → API | `has_many` (rare) | Lazy accessor calling target's `lcp_data_source.search(filter: {fk: id})` |
| API → API | any | Lazy accessor calling target's data source |

### Supported Filter Operators per Model

Filter operator availability is defined at the **model level**, not the presenter level. The model knows what its data source can handle — the presenter only controls which fields appear in the filter UI.

**Default behavior:**
- DB models: all operators supported (Ransack handles them)
- API models with `rest_json`: a default subset is supported (`eq`, `not_eq`, `cont`, `lt`, `lteq`, `gt`, `gteq`, `in`, `null`, `not_null`, `start`, `end`)
- API models with `host`: the host provider declares supported operators

**Model-level configuration:**

```yaml
# config/lcp_ruby/models/external_building.yml
name: external_building
data_source:
  type: rest_json
  # ...
  supported_operators:
    default: [eq, not_eq, cont, in, null, not_null]
    string: [eq, not_eq, cont, start, end, in, null, not_null]
    integer: [eq, not_eq, lt, lteq, gt, gteq, in, null, not_null]
    date: [eq, not_eq, lt, lteq, gt, gteq, null, not_null]
    enum: [eq, not_eq, in, null, not_null]
    boolean: [eq, null, not_null]
```

For `host` data sources, the provider class can declare operators programmatically:

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

`FilterMetadataBuilder` (which generates the JSON metadata for the visual filter builder) reads operators from the model definition. For DB models, the existing `OperatorRegistry` type-to-operator mapping is used unchanged. For API models, it reads `data_source.supported_operators` and intersects with the type defaults.

The filter UI disables operators that are not in the model's supported list. If a user somehow submits an unsupported operator (e.g., via URL manipulation), `ApiFilterTranslator` silently drops the filter term and logs a warning.

### Multi-Source Transactions (Phase 2)

When Phase 2 enables writes, cross-source operations (e.g., creating a DB record with an FK to an API record, or updating a DB record and then pushing changes to an API) are **not atomic**. The platform uses **best-effort compensation**:

```ruby
# Conceptual flow for create with cross-source association
def create_with_compensation(record, api_operations)
  ActiveRecord::Base.transaction do
    record.save!

    api_operations.each do |op|
      begin
        op.execute!
      rescue LcpRuby::DataSource::ConnectionError => e
        # API failed — roll back DB transaction
        Rails.logger.error(
          "[LcpRuby::API] Cross-source write failed, rolling back: #{e.message}"
        )
        raise ActiveRecord::Rollback
      end
    end
  end
end
```

**Behavior:**
- DB operations happen inside an AR transaction
- API operations happen sequentially after DB save but inside the transaction block
- If an API call fails, the DB transaction is rolled back
- If the DB commit succeeds but a subsequent API call fails (e.g., in an after_commit hook), the DB change persists — **this is the non-atomic edge case**
- The platform logs the inconsistency and surfaces an error to the user

**Documented guarantees:**
- Best-effort: the platform attempts to roll back DB changes when API calls fail
- Not guaranteed: if the DB commit succeeds and the API call fails after commit, the DB change is not automatically reverted
- Recommendation: for critical cross-source consistency, use the `host` data source type and implement saga/compensation logic in the provider class

### Rate Limiting and Backpressure (Future)

Not in Phase 1. The architecture supports adding rate limiting as another decorator in the data source stack:

```
ResilientWrapper → RateLimitWrapper → CachedWrapper → RestJson
```

The `RateLimitWrapper` would:
- Enforce max concurrent requests per data source (configurable)
- Queue excess requests and process them when slots free up
- Coalesce identical concurrent requests (same URL + params → single HTTP call, shared result)
- Return `429 Too Many Requests` equivalent error after queue timeout

Configuration placeholder (not implemented in Phase 1):

```yaml
data_source:
  rate_limit:
    max_concurrent: 10          # max parallel HTTP requests
    queue_timeout: 5            # seconds to wait in queue before error
    coalesce_identical: true    # deduplicate concurrent identical requests
```

The decorator pattern means this can be added without changing any adapter or controller code.

## Cross-References with Other Design Documents

API-backed models interact with most platform features. The table below summarizes compatibility and required adaptations.

### Fully Compatible (no changes needed)

These features work identically for DB and API models because they operate at the presentation, permission, or in-memory evaluation layer:

| Design Doc | Why It Works |
|-----------|-------------|
| [Context-Aware Presenters](context_aware_presenters.md) | Presenter resolution is data-source agnostic |
| [Dynamic Presenters](dynamic_presenters.md) | Override layer reads/writes its own DB table, independent of target model source |
| [Page Layouts & Slots](page_layout_and_slots.md) | View slots are presentation-level; SlotContext carries data, not queries |
| [View Switcher](view_switcher_context.md) | Auto-detection compares presenter configs, not data sources |
| [Groups & Roles](groups_roles_and_org_structure.md) | Role resolution and group membership are independent of model storage |
| [Scoped Permissions](scoped_permissions.md) | Permission lookup and fallback chain are generic |
| [Record Rules](record_rules_action_visibility.md) | `ConditionEvaluator` works on in-memory record attributes |
| [Unified Condition Operators](unified_condition_operators.md) | All 12 operators evaluate in-memory |
| [External Field Accessors](fields_accessors.md) | Direct application — API model fields are effectively virtual accessors |
| [Document Management](document_management.md) | Attachments use local Active Storage; metadata model is a standard LCP model |

### Require Adaptation

These features work for API models but need adapter-specific logic or operate in a reduced mode:

| Design Doc | What Changes | Impact |
|-----------|-------------|--------|
| [Advanced Search](advanced_search.md) | Ransack pipeline replaced by `ApiFilterTranslator` → data source `search()`. Custom `filter_*` method pattern is reusable. Quick search delegates to data source instead of SQL LIKE. | **High** — filter builder must read supported operators from model, not assume Ransack |
| [Saved Filters](saved_filters.md) | Saved filter model itself is a standard LCP DB model (no change). Filter *application* depends on the adapter translating condition trees to API queries. Scope-based saved filters (parameterized scopes) need adapter-specific scope handlers. | **Medium** — condition-based filters work; scope filters need translation |
| [Aggregate Columns](aggregate_columns.md) | SQL aggregates (`SUM`, `COUNT`, `AVG`) unavailable. Only `service:` aggregation type works — host app provides a Ruby class that computes the value. | **Medium** — presenter config must not declare SQL aggregates for API models; `ConfigurationValidator` enforces this |
| [Recursive Association Field Picker](recursive_association_field_picker.md) | `FilterMetadataBuilder` traverses AR reflections to discover nested filterable fields. For API models, it must read association metadata from `ModelDefinition` instead. Has_many filtering (EXISTS subquery) not available. | **Medium** — picker UI works; backend traversal needs adaptation |
| [Inline Collection Editor](inline_collection_editor.md) | `association:` source (nested AR attributes) unavailable. `json_field:` source works if the API model has a JSON field. `model-backed` mode works (virtual model with `source: { service: "json_field" }`). | **Low** — two of three modes work unchanged |
| [Tree Structures](tree_structures.md) | Parent/children associations work via lazy accessors. Traversal methods (`ancestors`, `descendants`, `depth`) must compute in-memory (load all nodes, build tree). No recursive CTE. No positioning integration. Tree index view works if traversal is in-memory. | **Medium** — functional but slower for large trees |
| [Workflow & Approvals](workflow_and_approvals.md) | API data is read-only input to workflow. Workflow state (enum field) is a *local* concept — stored separately (e.g., in a companion DB model or local cache). Guards (conditions) evaluate against fetched API record attributes. Actions (set_fields) only work on local fields. | **Medium** — workflow wraps API data with local state |
| [Model Options Infrastructure](model_options_infrastructure.md) | `ModelFactory::Builder` pipeline must skip DB-mutation applicators (SchemaManager, SoftDeleteApplicator, AuditingApplicator, PositioningApplicator, UserstampsApplicator) for API models. Compatible applicators (ValidationApplicator, TransformApplicator, computed fields, label method) still apply. | **High** — builder needs a branch for API model construction |

### Not Applicable (skipped for API models)

These features fundamentally require database mutations or AR-specific infrastructure. They are disabled for API models. `ConfigurationValidator` reports an error if an API model YAML enables them.

| Design Doc | Why It's Skipped |
|-----------|-----------------|
| [Auditing](auditing.md) | Requires AR callbacks (`after_save`, `after_destroy`) to capture `saved_changes` |
| [Userstamps](userstamps.md) | Requires `created_by_id` / `updated_by_id` DB columns and `before_save` callback |
| [Soft Delete](soft_delete.md) | Requires `discarded_at` DB column and `update_columns` |
| [Record Positioning](record_positioning.md) | Requires `positioning` gem with DB-backed position column and unique index |
| [Multiselect & Batch Actions](multiselect_and_batch_actions.md) | Batch mutations (`destroy`, `update`) not supported for read-only models |
| [Data Retention](data_retention.md) | External API manages its own data lifecycle |
| [Array Field Type](array_field_type.md) | `text[]` / `json` array columns require DB. Array *display* and *validation* work, but array *scopes* (contains, overlaps) do not |

### Reference

| Design Doc | Relevance |
|-----------|-----------|
| [Basepack Lessons](basepack_lessons.md) | Design patterns (custom filter methods, type-aware search, parameterized scopes) are reusable for API models |
| [Demo App HR](demo-app-hr.md) | Shows DB-model architecture; could have an API variant (org structure from AD/LDAP, employees from HCM API) |

## Open Questions

1. **Webhook-based cache invalidation.** Deferred to a future phase. TTL-based expiration is sufficient for Phase 1. When needed, the platform could expose a `POST /lcp/api-cache/invalidate/:model_name` endpoint with token authentication.

2. **API → API has_many.** The current design only supports API → DB `has_many` (because the partial relies on AR relation methods). Should the platform support API → API `has_many` via a data source search call? This requires the `association_list` partial to handle `SearchResult` in addition to AR relations.

3. **Retry policies.** Should the `ResilientWrapper` support configurable retry for transient failures (e.g., retry once on 503 with exponential backoff)? Or is immediate fallback to cache/error sufficient?

4. **Health check endpoint.** Should each API data source expose a health check (e.g., `GET /buildings?limit=1`) that the platform calls periodically to pre-warm the circuit breaker state? This would avoid the first-request latency spike when an API is down.

5. **Aggregate columns for API models.** The `service:` aggregation type works, but should the platform also support asking the API for aggregates (e.g., `GET /buildings/stats?aggregate=count`)? This would require an optional `aggregate` method on the data source contract.

6. **Tree traversal performance.** In-memory tree building for API models requires fetching all nodes. For large trees (10k+ nodes), this is impractical. Should the platform support API-side tree queries (e.g., `GET /categories?parent_id=5&depth=3`) via an optional `tree_query` method on the data source?
