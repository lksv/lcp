# Design: API-Backed Models (External Data Sources)

**Status:** Implemented (Phase 1 — read-only)
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

  # Override do_search (not search) — Base#search wraps the result
  # to ensure model_name is always set.
  def do_search(params, sort:, page:, per:)
    response = ErpClient.get("/orders", query: translate(params, sort, page, per))
    SearchResult.new(
      records: response["items"].map { |r| hydrate(r) },
      total_count: response["total"],
      current_page: page,
      per_page: per,
      model_name: model_class.model_name
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
  id_field: "buildingId"       # which remote field is the PK (before mapping)
  timeout: 10
  field_mapping:               # remote field name → local field name
    buildingNumber: number
    streetAddress: address
```

**`id_field` vs `field_mapping` — mutually exclusive for PK mapping:** `id_field` specifies which **remote** field contains the primary key, applied **before** `field_mapping`. The adapter reads `response[id_field]` as the record's `id`. If `field_mapping` also maps a remote field to `id` (e.g., `OBJECTID: id`), this is a **configuration error** — `ConfigurationValidator` reports an error at boot time. Use **either** `id_field` (when the remote PK needs no rename) **or** a `field_mapping` entry to `id` (when it does), never both. Silent precedence rules lead to hard-to-debug data mapping issues.

### ModelDefinition Extension

`ModelDefinition` gains a new `data_source_config` attribute parsed from the YAML `data_source` key. This is a **first-class attribute** — not a lazy lookup into `raw_hash`. It is parsed in `from_hash` alongside fields, associations, and other top-level keys:

```ruby
# In ModelDefinition
attr_reader :data_source_config

# In from_hash:
#   data_source_config: hash["data_source"] ? HashUtils.stringify_deep(hash["data_source"]) : nil

def data_source_type
  return :db unless data_source_config
  (data_source_config["type"] || "db").to_sym
end

def api_model?
  data_source_type != :db
end

# Supported operators for API model filter UI (intersection with OperatorRegistry).
# Returns per-type hash from data_source config, or default API operator set.
def data_source_supported_operators(base_type)
  return nil unless api_model?

  custom = data_source_config.dig("supported_operators", base_type.to_s)
  custom || data_source_config.dig("supported_operators", "default") || DEFAULT_API_OPERATORS
end
```

**Important distinction from `virtual?`:** Virtual models (`table_name: _virtual`) are metadata-only — no AR class, no data source, no controller routes. API models are fully functional models with controllers, presenters, permissions, and views — they just fetch data from an external source instead of SQL. The builder uses `api_model?` (not `virtual?`) to branch.

For API models, `table_name` is set to `nil` (no database table). `SchemaManager` skips models where `api_model?` is true.

### Model Class Generation

`ModelFactory::Builder` detects `api_model?` on the model definition and branches. The condition is `model_definition.api_model?` (i.e., `data_source_type != :db`), **not** a check for a specific type like `:api`.

- **DB model (`api_model? == false`, default):** Current behavior — creates AR class, runs SchemaManager, applies all applicators.
- **API model (`api_model? == true`):** Creates ActiveModel class with data source adapter attached. Skips SchemaManager. Each applicator is classified as compatible, skipped, or partially compatible.

#### Applicator Compatibility Matrix

Every applicator in the current `Builder.build` pipeline is classified for API models:

| Applicator | API model | Reason |
|-----------|-----------|--------|
| `create_model_class` | **Changed** — creates `ActiveModel` class instead of `AR::Base` subclass |
| `apply_table_name` | **Skip** — no DB table |
| `apply_enums` | **Partial** — skip AR `enum` macro (no DB column); apply `validates_inclusion_of` for the enum values list. Note: the current codebase has no "virtual enum path" — this is new logic that must be implemented for API models |
| `apply_validations` | **Partial** — skip `validates_uniqueness_of` (requires DB query); all other validators (`presence`, `length`, `numericality`, `format`, `inclusion`, `exclusion`, `confirmation`) work on ActiveModel |
| `apply_transforms` | **Compatible** — `before_validation` callbacks work on ActiveModel, but the generated class must explicitly `include ActiveModel::Validations::Callbacks` (not included by `ActiveModel::Model` by default) |
| `apply_associations` | **Changed** — skip AR macros (`belongs_to`, `has_many`); generate lazy accessors instead (see Cross-Source Associations) |
| `apply_aggregates` | **Skip** — requires SQL subqueries |
| `apply_attachments` | **Skip** — requires Active Storage (DB-backed) |
| `apply_scopes` | **Skip** — requires AR relation; `ConfigurationValidator` errors if scopes defined |
| `apply_soft_delete` | **Skip** — requires DB column; `ConfigurationValidator` errors |
| `apply_tree` | **Skip** — requires recursive CTE; `ConfigurationValidator` errors |
| `apply_ransack` | **Skip** — requires AR; filter metadata uses `FilterMetadataBuilder` intersection logic instead |
| `apply_sequences` | **Skip** — requires counter table + `before_create`; `ConfigurationValidator` errors |
| `apply_auditing` | **Skip** — requires AR `saved_changes`; `ConfigurationValidator` errors |
| `apply_defaults` | **Compatible** — `after_initialize` works on ActiveModel |
| `apply_computed` | **Skip** — requires `before_save` callback |
| `apply_positioning` | **Skip** — requires `positioning` gem + DB column; `ConfigurationValidator` errors |
| `apply_userstamps` | **Skip** — requires DB columns; `ConfigurationValidator` errors |
| `apply_external_fields` | **Compatible** — defines getter/setter methods, works on any class |
| `apply_model_extensions` | **Compatible** — host blocks receive the model class regardless of type |
| `apply_custom_fields` | **Skip** — requires `custom_data` JSON DB column |
| `apply_label_method` | **Compatible** — defines `to_label` method |

The generated API model class:

```ruby
# Generated at boot (conceptual, not literal code)
class LcpRuby::Dynamic::ExternalBuilding
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations::Callbacks  # Required for before_validation (transforms)
  include ActiveModel::Serialization
  include LcpRuby::ApiModelConcern

  # From YAML fields
  attribute :id, :string
  attribute :number, :string
  attribute :address, :string
  attribute :geometry, :value   # :value preserves Hash/Array from JSON parsing (not :string)
  attribute :status, :string
  attribute :built_year, :integer

  # Platform integration
  def self.model_name
    ActiveModel::Name.new(self, LcpRuby::Dynamic, "ExternalBuilding")
  end

  # NOTE: id.present? would return false for id=0 and id="" (ActiveSupport
  # treats numeric zero and empty string as blank). We need to handle both:
  # integer-zero IDs (valid in some APIs) and empty strings (not valid).
  def persisted?
    !id.nil? && id != ""
  end

  def to_param
    id.to_s
  end

  def to_label
    public_send(self.class.lcp_label_field)
  end

  # Data source (set by builder)
  class << self
    attr_accessor :lcp_data_source

    def find(id)
      lcp_data_source.find(id)
    end

    def find_many(ids)
      lcp_data_source.find_many(ids)
    end

    def lcp_search(params, sort:, page:, per:)
      lcp_data_source.search(params, sort: sort, page: page, per: per)
    end

    def lcp_select_options(**kwargs)
      lcp_data_source.select_options(**kwargs)
    end

    def lcp_api_model?
      true
    end
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
      # Subclasses override do_search (not search) to implement the actual query.
      # Base#search wraps the result to ensure model_name is always set.
      # params: hash of filter parameters (translated from LCP filter UI)
      # sort: { field: "name", direction: "asc" }
      # page: integer (1-based)
      # per: integer (records per page)
      # Returns: LcpRuby::SearchResult (with model_name guaranteed)
      def search(params, sort:, page:, per:)
        result = do_search(params, sort: sort, page: page, per: per)
        # Auto-inject model_name if the subclass forgot — prevents Kaminari crashes
        result.instance_variable_set(:@model_name, model_class.model_name) unless result.model_name
        result
      end

      # Override this in subclasses. Returns LcpRuby::SearchResult.
      def do_search(params, sort:, page:, per:)
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

      def writable?
        false
      end
    end

    class ReadonlyError < StandardError; end
    class ConnectionError < StandardError; end
    class RecordNotFound < StandardError; end
  end
end
```

### SearchResult — Kaminari-Compatible Wrapper

All API searches return a `SearchResult` that implements the full subset of Kaminari's interface needed by the `paginate` helper and the platform's pagination slot. Kaminari's `paginate` view helper calls more than just `total_pages` — it uses `offset_value`, `limit_value`, `entry_name`, `model_name`, `current_page`, and `num_pages` for URL generation and display. The `SearchResult` must satisfy all of these.

```ruby
module LcpRuby
  class SearchResult
    include Enumerable

    attr_reader :records, :total_count, :current_page, :per_page
    attr_accessor :error, :message, :stale

    def initialize(records:, total_count:, current_page:, per_page:,
                   model_name:, error: nil, message: nil, stale: false)
      @records = records
      @total_count = total_count
      @current_page = current_page
      @per_page = per_page
      @model_name = model_name
      @error = error
      @message = message
      @stale = stale
    end

    def each(&block)
      @records.each(&block)
    end

    def size
      @records.size
    end

    def empty?
      @records.empty?
    end

    def to_a
      @records.dup
    end

    # Kaminari-compatible interface (full set used by `paginate` helper).
    #
    # IMPORTANT: Do NOT override Enumerable#count here. Kaminari uses
    # total_count (not count) for pagination math. Overriding count would
    # cause confusion: result.count would return total_count (e.g. 500)
    # while result.size returns page size (e.g. 25).
    def total_pages
      (total_count.to_f / per_page).ceil
    end
    alias_method :num_pages, :total_pages  # Some Kaminari versions use num_pages

    def limit_value
      per_page
    end

    def offset_value
      (current_page - 1) * per_page
    end

    def first_page?
      current_page == 1
    end

    def last_page?
      current_page >= total_pages
    end

    # Kaminari URL generation support.
    # model_name is REQUIRED — the controller must always inject the API model
    # class's model_name so Kaminari generates correct URL param keys.
    def model_name
      @model_name
    end

    def entry_name(options = {})
      model_name.human(options.reverse_merge(count: total_count))
    end

    # Error state
    def stale?
      @stale
    end

    def error?
      @error.present?
    end
  end
end
```

The `model_name` is a **required** parameter and must be an `ActiveModel::Name` instance (not a plain string) — Kaminari's `paginate` helper calls `model_name.param_key` for URL generation, which would raise `NoMethodError` on a plain string. To prevent host adapter bugs, `DataSource::Base#search` should auto-inject `model_name` by wrapping the subclass result:

```ruby
# In DataSource::Base — wrapper ensures model_name is always set
def search(params, sort:, page:, per:)
  result = do_search(params, sort: sort, page: page, per: per)
  result.instance_variable_set(:@model_name, model_class.model_name) unless result.model_name
  result
end

# Subclasses override do_search instead of search
def do_search(params, sort:, page:, per:)
  raise NotImplementedError
end
```

This way host adapters cannot accidentally omit `model_name` — the base class fills it in if missing. A `nil` model_name would cause `NoMethodError` in Kaminari — this is intentional to catch misconfiguration early.

**Pagination slot compatibility:** The existing pagination slot (`<%= paginate slot_context.records if slot_context.records.respond_to?(:total_pages) %>`) works because `SearchResult` responds to `total_pages`. The `paginate` helper then uses the remaining methods above. If edge cases arise with Kaminari's internal expectations, the platform can provide a custom pagination partial for API models as a fallback.

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
# assoc_def is the AssociationDefinition from model YAML.
# All names (assoc name, FK field, target model) come from assoc_def,
# not hardcoded — this handles non-conventional FK names correctly.
assoc_name = assoc_def.name           # "building"
fk_field = assoc_def.foreign_key      # "building_id"
target_model = assoc_def.target_model # "external_building"
ivar = :"@_api_assoc_#{assoc_name}"

# NOTE: Use public_send (not read_attribute/write_attribute) to support
# both AR models (DB source) and ActiveModel models (API source).
# read_attribute/write_attribute are AR-specific and would raise
# NoMethodError on ActiveModel classes.
define_method(assoc_name) do
  fk_value = public_send(fk_field)
  return nil if fk_value.blank?

  # Instance-level cache (cleared on reload)
  cached = instance_variable_get(ivar)
  return cached if cached && cached.id.to_s == fk_value.to_s

  target_class = LcpRuby.registry.model_for(target_model)
  result = target_class.find(fk_value)
  instance_variable_set(ivar, result)
  result
end

define_method(:"#{assoc_name}=") do |record|
  public_send(:"#{fk_field}=", record&.id)
  instance_variable_set(ivar, record)
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
    ids = records.filter_map { |r| r.public_send(fk_field) }.uniq
    return if ids.empty?

    target_class = LcpRuby.registry.model_for(assoc_def.target_model)
    fetched = target_class.find_many(ids)
    index = fetched.index_by { |r| r.id.to_s }

    records.each do |record|
      fk = record.public_send(fk_field).to_s
      record.instance_variable_set(:"@_api_assoc_#{assoc_name}", index[fk])
    end
  end
end
```

#### IncludesResolver Integration

The existing `IncludesResolver::StrategyResolver` classifies each association dependency into `includes`, `eager_load`, or `joins` — all AR-only methods. It also uses `model_class.reflect_on_association` (AR reflection) to determine association types.

For cross-source associations, the strategy resolver must detect that the target is an API model and emit an **`api_preload`** action instead of AR loading methods:

```ruby
# In StrategyResolver#resolve — new branches
def resolve_assoc_type(assoc, assoc_name)
  # Check if target is an API model before falling back to AR reflections.
  # API targets cannot be eager-loaded via AR — they need ApiPreloader.
  if assoc && assoc.lcp_model?
    target_def = LcpRuby.loader.model_definition(assoc.target_model)
    if target_def&.api_model?
      return :api  # special marker — not an AR association type
    end
  end

  return assoc.type if assoc

  # Guard: API models have no AR reflections. Do not attempt
  # reflect_on_association on a non-AR class — it would raise.
  source_def = @model_def
  return nil if source_def.api_model?

  return nil unless LcpRuby.registry.registered?(@model_def.name)

  # ... existing AR reflection logic for tree-generated associations
  model_class = LcpRuby.registry.model_for(@model_def.name)
  reflection = model_class.reflect_on_association(assoc_name.to_sym)
  # ...
end
```

When an association is classified as `:api`, `StrategyResolver` adds it to a separate `api_preloads` list instead of `includes`/`eager_load`/`joins`. `LoadingStrategy` gains a new step:

```ruby
class LoadingStrategy
  def apply(scope_or_records)
    # ... existing includes/eager_load/joins for AR associations

    # After AR query executes and records are loaded:
    # api_preloads are applied to the materialized record array
    scope_or_records
  end

  def apply_api_preloads(records)
    @api_preloads.each do |assoc_name|
      assoc_def = find_association_def(assoc_name)
      ApiPreloader.preload(records, assoc_name.to_s, assoc_def)
    end
  end
end
```

The controller calls `strategy.apply_api_preloads(@records.to_a)` after pagination (when records are materialized) but before rendering. This ensures the batch API call happens once per page, not once per record.

**Two-phase preloading in the controller:** The existing `preload_associations` method currently uses `ActiveRecord::Associations::Preloader` directly. For cross-source scenarios (DB model with some API targets), preloading becomes two-phase:

```ruby
def preload_associations(record_or_records, context)
  strategy = resolve_loading_strategy(context)
  return if strategy.empty?

  records = Array(record_or_records)

  # Phase 1: AR preloader for DB-backed associations
  ar_assocs = strategy.includes + strategy.eager_load
  if ar_assocs.any?
    ActiveRecord::Associations::Preloader.new(
      records: records, associations: ar_assocs
    ).call
  end

  # Phase 2: ApiPreloader for API-backed associations
  strategy.apply_api_preloads(records)
end
```

Phase 1 handles standard AR associations (no change from current behavior). Phase 2 runs `ApiPreloader` for each association classified as `:api` by `StrategyResolver`. Both phases run on the same materialized records array.

For **API standalone models** (the model itself is API-backed), `IncludesResolver` is not used at all — the data source returns fully hydrated records. `DependencyCollector` skips API models entirely.

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

The controller needs branching at specific points where DB and API models diverge. The branching is localized — most of the controller flow (presenter resolution, permission checks, parameter building, view rendering) is identical. The divergent logic is encapsulated in a **strategy object** (`QueryStrategy`) to avoid scattering `if api_model?` throughout the controller.

Detection method:

```ruby
# ApplicationController
def api_model?
  @model_definition&.api_model?
end
```

**`set_presenter_and_model` adaptation:** The existing code sets `@model_class = nil` for virtual models. For API models, the model class is **not nil** — it is a fully functional ActiveModel class from the registry:

```ruby
def set_presenter_and_model
  # ...existing code...
  @model_class = @model_definition.virtual? ? nil : LcpRuby.registry.model_for(@presenter_definition.model)
  # API models get a non-nil @model_class (ActiveModel class, not AR class).
  # The api_model? helper distinguishes them from DB models.
  @query_strategy = QueryStrategy.for(@model_class, @model_definition) if @model_class
end
```

#### Error Handling for API Models

`ApplicationController` must rescue both AR and data source exceptions:

```ruby
rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
rescue_from LcpRuby::DataSource::RecordNotFound, with: :record_not_found
rescue_from LcpRuby::DataSource::ConnectionError, with: :data_source_error
```

The `data_source_error` handler renders a user-friendly error page (similar to `record_not_found`) with the connection error message. In production, it returns a 503 Service Unavailable status.

#### Query Strategy

```ruby
class QueryStrategy
  def self.for(model_class, model_definition)
    if model_definition.api_model?
      ApiQueryStrategy.new(model_class, model_definition)
    else
      DatabaseQueryStrategy.new(model_class)
    end
  end
end
```

The controller calls `@query_strategy = QueryStrategy.for(@model_class, @model_definition)` in `set_presenter_and_model` and delegates all data-access operations to it.

#### Points of Divergence

| Method | DB model | API model |
|--------|----------|-----------|
| `policy_scope` | `ScopeBuilder.apply(relation)` — AR `.where()` | Translated to data source filter params (see below) |
| `set_record` | `scope.find(id)` via AR | `@model_class.find(id)` via data source |
| `apply_advanced_search` | 7-step Ransack pipeline | `ApiSearchPipeline` (see below) |
| `apply_sort` | `scope.order(field => dir)`, dot-path uses `@model_class.connection` + Arel, aggregate uses `@model_class.connection.quote_column_name` | Passed as parameter to `lcp_search`; dot-path and aggregate sorting not supported; direct field validated against `model_definition.fields` (not `column_names`) |
| `paginate` | `scope.page(n).per(m)` (Kaminari) | Already paginated in `SearchResult` |
| `record_count` | `scope.count` | `SearchResult#total_count` |
| `select_options` | `build_options_query` (AR) | `target_class.lcp_select_options(...)` (see below) |
| `validate_association_values!` | `build_options_query` (AR), `.to_i` on IDs | Delegates to `lcp_select_options` for API targets; **type-aware ID comparison** (see below) |
| `compute_summaries` | `scope.sum(field)` | **Runtime guard**: `return {} if api_model?` — skipped |
| `compute_summary_bar` | `scope.average(field)` | **Runtime guard**: `return if api_model?` — skipped |
| `apply_aggregates` | `Aggregates::QueryBuilder.apply` (SQL subqueries) | **Runtime guard**: `return scope if api_model?` — skipped |
| `build_tree_data` | `scope.pluck(:id, :parent_id)` | Not supported |
| `strict_loading` | `scope.strict_loading` (AR-only) | **Runtime guard**: skip `strict_loading` call for API models |
| `create` / `update` | AR `save` | `lcp_data_source.save(record)` — Phase 2 |
| `destroy` | AR `destroy!` | `lcp_data_source.destroy(record)` — Phase 2 |
| `compute_list_version` | `@model_class.all.order().pluck(:id)` | Not supported (positioning not available); **runtime guard**: skip |
| `compute_tree_version` | `@model_class.order(:id).pluck(:id, parent_field)` | Not supported (tree not available); **runtime guard**: skip |

**Additional adaptation points outside the controller:**

| Location | DB model | API model |
|----------|----------|-----------|
| `form_helper.rb` `render_association_select` | `target_class.find_by(id: current_id)` for current value | Must use `target_class.find(current_id)` with rescue (no `find_by`) |
| `form_helper.rb` `render_tree_select` | `target_class.all` to load all records | Not supported for API targets (`ConfigurationValidator` warns) |
| `build_select_options_search` (AJAX) | `target_class.connection`, `column_names`, `sanitize_sql_like` | Must delegate to `target_class.lcp_select_options(search: params[:q])` |
| `resolve_field_ancestors` | `target_class.find_by(id: value)` | Must use `target_class.find(value)` with rescue |
| `ActionsController` | `@model_class.where(id: ids)` | Phase 2 — runtime guard: reject batch actions for API models |

**Runtime guards are mandatory** — even when `ConfigurationValidator` warns about unsupported features at boot time, the runtime guards protect against misconfigured YAML or dynamic presenter changes. The cost is a single boolean check per action.

#### Permission Scoping (`policy_scope`) for API Models

**The full scope resolution chain:** `ResourcesController.policy_scope(@model_class)` → `PolicyFactory::Scope.resolve` → `PermissionEvaluator.apply_scope(scope)` → `ScopeBuilder.apply(base_relation)`. Every step in this chain currently assumes an AR relation.

**Key problem:** `PermissionEvaluator.apply_scope` currently accepts and returns an AR relation. For API models, it must return a portable filter array instead. This changes the method's return type contract. `PermissionEvaluator` currently only has `@model_name` (a string), so it needs `LcpRuby.loader.model_definition(@model_name)` to detect API models — this is a new dependency.

The branching happens at the `PermissionEvaluator` level, but the Pundit integration must also adapt:

```ruby
# PolicyFactory — Scope#resolve must handle the return type split
scope_class = Class.new do
  define_method(:resolve) do
    result = @evaluator.apply_scope(scope)
    # For DB models: result is an AR relation (pass through)
    # For API models: result is an Array of filter hashes
    result
  end
end
```

The **controller** must handle both return types from `policy_scope`:

```ruby
# In ApiQueryStrategy (controller)
def index
  policy_result = policy_scope(@model_class)

  if api_model?
    # policy_scope returned a filter array, not an AR relation.
    # Pass filters into the search pipeline.
    @policy_filters = policy_result.is_a?(Array) ? policy_result : []
    @records = ApiSearchPipeline.new(...).execute(params, policy_filters: @policy_filters)
  else
    # policy_scope returned an AR relation (current behavior)
    scope = policy_result
    scope = apply_advanced_search(scope)
    # ...
  end
end
```

**PermissionEvaluator branching:**

```ruby
# PermissionEvaluator — branching point
def apply_scope(base_relation_or_nil)
  scope_config = effective_config["scope"]
  return base_relation_or_nil if scope_config == "all" || scope_config.nil?

  model_def = LcpRuby.loader.model_definition(@model_name)
  if model_def.api_model?
    # Return portable filter array for API models.
    # For "all" or nil scope, return empty array (handled above).
    ApiScopeTranslator.translate(scope_config, user)
  else
    ScopeBuilder.new(scope_config, user).apply(base_relation_or_nil)
  end
end
```

`ApiScopeTranslator` converts each scope type to portable filter params:

```ruby
# ApiScopeTranslator — returns filter array, not AR relation
def self.translate(scope_config, user)
  scope_config = scope_config.transform_keys(&:to_s) if scope_config.is_a?(Hash)
  return [] unless scope_config.is_a?(Hash)

  case scope_config["type"]
  when "field_match"
    field = scope_config["field"]
    value = resolve_scope_value(scope_config["value"], user)
    [{ field: field, operator: "eq", value: value }]
  when "where"
    # Handle arrays (IN), nil (NULL), ranges (BETWEEN), and simple values (EQ).
    # NOTE: The existing ScopeBuilder.apply_where passes conditions directly
    # to AR's .where(), which handles Range values as BETWEEN automatically.
    # ApiScopeTranslator must handle ranges explicitly.
    scope_config["conditions"].map do |field, value|
      case value
      when Array
        { field: field, operator: "in", value: value }
      when Range
        { field: field, operator: "between", value: [value.min, value.max] }
      when nil
        { field: field, operator: "null", value: nil }
      else
        { field: field, operator: "eq", value: value }
      end
    end
  when "association"
    field = scope_config["field"]
    values = user.send(scope_config["method"])
    [{ field: field, operator: "in", value: Array(values) }]
  when "custom"
    # Custom scopes call arbitrary Ruby on an AR relation — cannot be translated.
    # ConfigurationValidator warns at boot; skip at runtime with log.
    Rails.logger.warn(
      "[LcpRuby::API] Custom policy scope '#{scope_config['method']}' " \
      "not supported for API model. Scope skipped."
    )
    []
  else
    []
  end
end

# Mirrors ScopeBuilder#resolve_value exactly — same regex pattern.
def self.resolve_scope_value(value_ref, user)
  case value_ref
  when "current_user_id"
    user&.id
  when /\Acurrent_user_(\w+)\z/
    method_name = $1
    user.respond_to?(method_name) ? user.send(method_name) : nil
  else
    value_ref
  end
end
```

The `field_match`, `where`, and `association` scope types translate cleanly because they express field-level conditions. The `where` translation handles arrays (→ `in` operator), nil (→ `null` operator), and ranges (→ `between` operator) in addition to simple equality. The `resolve_scope_value` method mirrors the exact same regex pattern as the existing `ScopeBuilder#resolve_value` (including `current_user_(\w+)` for any user attribute).

The `custom` scope type (which calls arbitrary Ruby methods on the AR relation) **cannot be translated** — it is skipped with a logged warning. `ConfigurationValidator` emits a warning if a permission definition uses `scope.type: custom` for an API model.

The translated filters are prepended to any user-provided search filters before calling `lcp_search`.

#### Record Lookup (`set_record`) for API Models

For DB models, `set_record` applies soft-delete scoping before `find`:

```ruby
def set_record
  scope = apply_soft_delete_scope(@model_class)
  @record = scope.find(params[:id])
end
```

For API models, soft delete is not supported, so the lookup is direct:

```ruby
# ApiQueryStrategy
def find_record(id)
  @model_class.find(id) # delegates to lcp_data_source.find(id)
end
```

#### Full Search Pipeline for API Models

The existing 7-step `apply_advanced_search` pipeline is deeply AR-dependent. For API models, a separate `ApiSearchPipeline` translates each applicable step into portable filters and feeds them into a single `lcp_search` call:

```ruby
class ApiSearchPipeline
  def initialize(model_class, model_definition, presenter, evaluator)
    @model_class = model_class
    @model_definition = model_definition
    @presenter = presenter
    @evaluator = evaluator
  end

  # Returns a SearchResult (already paginated)
  def execute(params, policy_filters: [])
    filters = policy_filters.dup
    sort = extract_sort(params)
    page = [(params[:page] || 1).to_i, 1].max
    per = effective_per_page(params)

    # Step 1: Default scope — not applicable (no AR scopes on API models)
    # ConfigurationValidator warns if presenter defines default_scope for API model.

    # Step 2: Predefined filter — not applicable (no AR scopes)
    # ConfigurationValidator warns if predefined_filters defined for API model.

    # Step 2.5a: Saved filter — translate condition tree to portable filters
    if params[:saved_filter].present? && SavedFilters::Registry.available?
      saved = load_saved_filter(params[:saved_filter])
      if saved
        translated = ApiFilterTranslator.from_condition_tree(saved.conditions)
        filters.concat(translated[:filters])
      end
    end

    # Step 2.5b: Parameterized scopes — not applicable (no AR scopes)
    # ConfigurationValidator warns at boot time.

    # Step 3: Param sanitization — reuse existing pure-Ruby sanitizer
    raw_filter_params = Search::ParamSanitizer.reject_blanks(params[:f]&.to_unsafe_h)

    # Step 4: Custom filter interceptor — not applicable
    # filter_* methods return AR scopes, cannot be used with API models.

    # Step 5: Advanced filter params (?f[...]) — translate to portable format
    if raw_filter_params.present?
      translated = ApiFilterTranslator.from_ransack_params(raw_filter_params)
      filters.concat(translated)
    end

    # Step 6: Quick search (?qs=) — delegate to data source as text query
    if params[:qs].present?
      filters << { field: "_quick_search", operator: "text", value: params[:qs] }
    end

    # Step 7: Custom field filters — not applicable (custom fields not supported)

    @model_class.lcp_search(
      { filters: filters },
      sort: sort,
      page: page,
      per: per
    )
  end
end
```

**Step-by-step mapping from the existing 7-step pipeline:**

| Step | DB model (existing) | API model |
|------|--------------------|-----------|
| 1. Default scope | `scope.send(scope_name)` | Not supported — `ConfigurationValidator` warns |
| 2. Predefined filter | `scope.send(scope_name)` | Not supported — `ConfigurationValidator` warns |
| 2.5a. Saved filter | Ransack condition tree | `ApiFilterTranslator.from_condition_tree` → portable filters |
| 2.5b. Parameterized scopes | `ParameterizedScopeApplicator` | Not supported — `ConfigurationValidator` warns |
| 3. Param sanitization | `ParamSanitizer` (pure Ruby) | Same `ParamSanitizer` (reused) |
| 4. Custom filter interceptor | `Model.filter_*()` methods | Not supported (returns AR scope) |
| 5. Ransack search | `model.ransack(params)` | `ApiFilterTranslator.from_ransack_params` → portable filters |
| 6. Quick search | `QuickSearch.apply()` → SQL LIKE | `_quick_search` pseudo-filter → data source text search |
| 7. Custom field filters | `CustomFieldFilter` → JSON queries | Not applicable (custom fields not supported) |

The data source's `search` method receives the `_quick_search` pseudo-filter and translates it into its backend's text search mechanism (e.g., a `q` query param for REST APIs, a text search method for host providers).

#### Sorting for API Models

`apply_sort` currently calls `@model_class.column_names.include?(field)` and `scope.order(field => direction)` — both AR-only. ActiveModel classes do not have `column_names`. For API models, sort field validation uses `model_definition.fields.map(&:name)` instead, and sort params are passed directly to `lcp_search` as part of the `ApiSearchPipeline`:

```ruby
# ApiQueryStrategy
def valid_sort_field?(field)
  @model_definition.fields.any? { |f| f.name == field.to_s }
end
```

- **Direct field sorting:** Validated against `model_definition.fields`, then passed as `sort: { field: "name", direction: "asc" }` to the data source.
- **Dot-path sorting (e.g., `building.address`):** Not supported for API models — the data source would need to understand association traversal. `ConfigurationValidator` warns if a presenter's `default_sort` uses a dot-path for an API model. The sort dropdown in the UI omits dot-path sort options for API model presenters.
- **Aggregate sorting:** Not supported (no SQL subqueries).

#### Association Select Options for API Targets

When a form field references an API-backed target model (e.g., `building_id` → `external_building`), the `select_options` action and `validate_association_values!` must delegate to the data source instead of building AR queries.

`AssociationOptionsBuilder` detects API targets:

```ruby
def build_select_options_json(assoc, input_options)
  target_class = LcpRuby.registry.model_for(assoc.target_model)
  target_def = LcpRuby.loader.model_definition(assoc.target_model)

  if target_def.api_model?
    label_method = input_options["label_method"] || resolve_default_label_method(assoc)
    target_class.lcp_select_options(
      search: params[:q],
      label_method: label_method,
      limit: input_options["max_options"] || MAX_SELECT_OPTIONS
    )
  else
    # Existing AR query logic unchanged
    depends_on_values = extract_depends_on_from_params(input_options)
    oq = build_options_query(assoc, input_options, ...)
    format_options_for_json(oq, input_options)
  end
end
```

The same check applies in `build_select_options_search` (paginated AJAX search) and `validate_association_values!` (form submission validation). When validating, the allowed IDs are fetched from `lcp_select_options` and compared against submitted values.

**Required pre-change — type-aware ID comparison:** The current `validate_association_values!` and `extract_allowed_ids` methods coerce all IDs to integers via `.to_i`. This breaks for API models where IDs are strings (e.g., `"ABC-123".to_i == 0`). Before implementing API model support, these methods must use **type-aware comparison**:

```ruby
# Current (broken for string IDs):
submitted_ids = Array(submitted_value).map(&:to_i)
ids << o[:value].to_i

# Fixed (type-aware):
submitted_ids = Array(submitted_value).map(&:to_s)
ids << o[:value].to_s
```

Using `.to_s` for comparison is safe for both integer and string IDs because the comparison is equality-based (set membership), not ordering-based. The same fix applies to `extract_allowed_ids`, `resolve_disabled_values`, and `resolve_field_ancestors` (which also calls `.to_i` on `value_id`).

**Full list of `.to_i` call sites requiring type-aware fix:**
- `validate_association_values!` — `Array(submitted_value).map(&:to_i)`
- `extract_allowed_ids` — `o[:value].to_i` (both flat and grouped format)
- `resolve_disabled_values` — `disabled << v.to_i` for static `disabled_values`
- `resolve_field_ancestors` — `current_value = value_id.to_i`

**Limitations for API targets in selects:**

| Feature | Supported | Notes |
|---------|-----------|-------|
| Basic label/value options | Yes | Via `lcp_select_options` |
| Remote search (`search: true`) | Yes | Passed as `search:` param |
| `depends_on` cascade | Limited | Passed as `filter:` param; data source decides |
| `group_by` | No | Requires AR query — `ConfigurationValidator` warns |
| `disabled_scope` / `legacy_scope` | No | Requires AR scopes — `ConfigurationValidator` warns |
| `tree_select` | No | Requires all records + `parent_id` traversal |
| `filter` (raw WHERE) | No | Requires AR — `ConfigurationValidator` warns |

### Search and Filtering

API models do not use Ransack. Instead, the platform translates filter parameters into a generic filter hash and passes it to the data source via `ApiFilterTranslator`.

The filter translation maps Ransack-style params (produced by the existing filter UI) to a portable format:

```ruby
# Input: Ransack-style params from the filter UI
{ "name_cont" => "tower", "status_eq" => "active", "built_year_gteq" => "1990" }

# Output: Portable filter hash for the data source
{
  filters: [
    { field: "name", operator: "cont", value: "tower" },
    { field: "status", operator: "eq", value: "active" },
    { field: "built_year", operator: "gteq", value: 1990 }
  ]
}
```

**Important:** The portable filter format uses the same operator names as `OperatorRegistry` (e.g., `cont`, `gteq`, `start`), not English prose names. This avoids a double-translation layer. The built-in `RestJson` adapter translates these to query parameters for the specific API. The `Host` adapter passes them as-is to the provider class.

#### ApiFilterTranslator

`ApiFilterTranslator` converts Ransack-style filter params (produced by the existing filter UI) and saved filter condition trees into the portable filter format. This is the central translation layer between the existing filter infrastructure and API data sources.

```ruby
module LcpRuby
  class ApiFilterTranslator
    # Known Ransack predicate suffixes, ordered longest-first for greedy matching.
    PREDICATES = %w[
      not_cont not_start not_end not_eq not_in not_null
      cont start end eq in null not_null present blank
      gteq lteq gt lt between
    ].freeze

    SUPPORTED_OPERATORS = %w[
      eq not_eq cont not_cont start not_start end not_end
      lt lteq gt gteq in not_in null not_null present blank between
    ].freeze

    # Translate Ransack-style params from the filter UI.
    # Input: { "name_cont" => "tower", "status_eq" => "active" }
    # Output: [{ field: "name", operator: "cont", value: "tower" }, ...]
    def self.from_ransack_params(params, model_definition: nil)
      field_names = model_definition&.fields&.map(&:name) || []
      filters = []

      params.each do |key, value|
        field, operator = parse_ransack_key(key.to_s, field_names)
        next unless field && operator

        unless SUPPORTED_OPERATORS.include?(operator)
          Rails.logger.warn(
            "[LcpRuby::API] Unsupported filter operator '#{operator}' " \
            "for field '#{field}' — filter skipped"
          )
          next
        end

        filters << { field: field, operator: operator, value: value }
      end

      filters
    end

    # Translate a saved filter condition tree to portable filters.
    # Handles recursive {combinator, children} format from FilterParamBuilder.
    # Returns { filters: [...], warnings: [...] }
    #
    # IMPORTANT LIMITATION: This method flattens compound boolean logic into
    # a flat filter array. The boolean structure (AND/OR/NOT combinators) is
    # LOST in translation:
    #   - { any: [A, B] } (OR)  → [A, B] — data source will likely AND them
    #   - { not: A }            → [A]    — negation is lost
    #   - { all: [A, B] } (AND) → [A, B] — correct (AND is the default)
    #
    # This means saved filters with OR groups or NOT conditions will produce
    # incorrect results for API models. The warnings array will note this.
    # A future version could pass the full tree to data sources that support
    # structured boolean queries.
    def self.from_condition_tree(tree)
      filters = []
      warnings = []

      # Warn about boolean logic loss
      tree_s = tree.is_a?(Hash) ? tree.transform_keys(&:to_s) : {}
      if tree_s.key?("any")
        warnings << "OR combinator flattened to AND — filter results may be broader than expected"
      end
      if tree_s.key?("not")
        warnings << "NOT combinator dropped — negation not preserved in portable filters"
      end

      conditions = extract_leaf_conditions(tree)
      conditions.each do |cond|
        field = cond["field"]
        operator = cond["operator"]

        # Scope conditions (@scope_name) cannot be translated
        if field.to_s.start_with?("@")
          warnings << "Scope condition '#{field}' not supported for API models"
          next
        end

        # Custom field conditions (cf[...]) not supported
        if field.to_s.start_with?("cf[")
          warnings << "Custom field condition '#{field}' not supported for API models"
          next
        end

        unless SUPPORTED_OPERATORS.include?(operator.to_s)
          warnings << "Unsupported operator '#{operator}' for field '#{field}'"
          next
        end

        filters << { field: field, operator: operator.to_s, value: cond["value"] }
      end

      { filters: filters, warnings: warnings }
    end

    # Parse a Ransack-style key into (field_name, operator).
    # Uses field names for disambiguation when a field name contains underscores.
    # Example: "built_year_gteq" with field "built_year" → ["built_year", "gteq"]
    #
    # Limitations:
    # - OR predicates ("name_or_address_cont") are NOT supported — dropped with warning.
    # - Association-path predicates ("company_name_cont") are NOT supported for API models
    #   (would require cross-source filtering). Dropped with warning.
    # - _any/_all suffixes ("status_in_any") are stripped and treated as base operator.
    def self.parse_ransack_key(key, field_names = [])
      # Try field_names first (longest match) for disambiguation
      sorted_names = field_names.sort_by { |n| -n.length }
      sorted_names.each do |name|
        suffix = key.delete_prefix(name)
        next unless suffix.start_with?("_") && suffix.length > 1

        operator = suffix[1..]
        # Strip _any/_all suffixes
        operator = operator.sub(/_(any|all)\z/, "")
        return [name, operator] if PREDICATES.include?(operator)
      end

      # Fallback: try each predicate suffix
      PREDICATES.each do |pred|
        if key.end_with?("_#{pred}")
          field = key[0..-(pred.length + 2)]
          return [field, pred] unless field.empty?
        end
      end

      nil
    end

    private

    def self.extract_leaf_conditions(tree, result = [])
      return result unless tree.is_a?(Hash)

      tree = tree.transform_keys(&:to_s)
      if tree.key?("children")
        Array(tree["children"]).each { |child| extract_leaf_conditions(child, result) }
      elsif tree.key?("all")
        Array(tree["all"]).each { |child| extract_leaf_conditions(child, result) }
      elsif tree.key?("any")
        Array(tree["any"]).each { |child| extract_leaf_conditions(child, result) }
      elsif tree.key?("not")
        extract_leaf_conditions(tree["not"], result)
      elsif tree.key?("field")
        result << tree
      end

      result
    end
  end
end
```

**Key translation rules:**

| Ransack param pattern | Portable filter | Notes |
|-----------------------|----------------|-------|
| `name_cont` → `"tower"` | `{ field: "name", operator: "cont", value: "tower" }` | Standard translation |
| `status_in` → `["a","b"]` | `{ field: "status", operator: "in", value: ["a","b"] }` | Multi-value |
| `built_year_gteq` → `"1990"` | `{ field: "built_year", operator: "gteq", value: "1990" }` | Field name disambiguation via model fields |
| `name_or_address_cont` | Dropped with warning | OR predicates not supported |
| `company_name_cont` | Dropped with warning | Association-path not supported |
| `status_in_any` | `{ operator: "in" }` | `_any`/`_all` suffixes stripped |

Supported filter operators for API models — a subset of `OperatorRegistry::ALL_OPERATORS`:

| Operator | Meaning | Applicable Types |
|----------|---------|-----------------|
| `eq` | Equals | all |
| `not_eq` | Not equals | all |
| `cont` | Contains (substring) | string, text |
| `not_cont` | Does not contain | string, text |
| `start` | Starts with | string |
| `not_start` | Does not start with | string |
| `end` | Ends with | string |
| `not_end` | Does not end with | string |
| `lt`, `lteq`, `gt`, `gteq` | Numeric/date comparisons | integer, float, decimal, date, datetime |
| `in` | Value in list | all except boolean |
| `not_in` | Value not in list | all except boolean |
| `null`, `not_null` | Null checks | all |
| `present`, `blank` | Presence checks | all |
| `between` | Range (two values) | integer, float, decimal, date, datetime |

Operators **not supported** for API models (require SQL or Ransack internals):

- `true`, `not_true`, `false`, `not_false` — boolean-specific Ransack predicates. API models use `eq` with `true`/`false` values instead.
- `last_n_days`, `this_week`, `this_month`, `this_quarter`, `this_year` — relative date operators that are resolved to absolute date ranges at query time. Could be added in a future phase by having `ApiFilterTranslator` expand them to `gteq`/`lteq` pairs before passing to the data source.
- `matches`, `not_matches` — regex operators (require SQL `LIKE` patterns or regex engine).

#### Operator Intersection Logic in FilterMetadataBuilder

`FilterMetadataBuilder` generates the JSON metadata for the visual filter builder. For DB models, it reads operators from `OperatorRegistry.operators_for(base_type)`. For API models, it **intersects** the type-based operator list with the data source's declared `supported_operators`:

```ruby
def resolve_operators(field_name, base_type)
  type_operators = OperatorRegistry.operators_for(base_type)

  if @model_definition.api_model?
    supported = @model_definition.data_source_supported_operators(base_type)
    type_operators & supported  # intersection
  else
    type_operators
  end
end
```

This ensures the filter UI only shows operators the data source can actually handle. If the data source does not declare `supported_operators`, the default API operator set (table above) is used.

If a user submits an unsupported operator (e.g., via URL manipulation), `ApiFilterTranslator` silently drops the filter term and logs a warning.

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

**Cache store requirement:** `CachedWrapper` uses `Rails.cache`. In development, the default `:memory_store` is per-process and not shared between workers — this is fine for development. In production with multiple workers (Puma, Sidekiq), the cache store **must** be a shared store (Redis via `redis_cache_store`, or Memcached via `mem_cache_store`) for consistent caching across processes. The platform does not enforce this — it is a deployment concern documented in the setup guide.

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

The error placeholder uses `method_missing` + `respond_to_missing?` to respond to any field getter with `nil`. This is necessary because renderers and `FieldValueResolver` call `respond_to?(:field_name)` before `public_send(:field_name)` — both must work:

```ruby
class ApiErrorPlaceholder
  attr_reader :id, :model_name, :error

  def initialize(id:, model_name:, error:)
    @id = id
    @model_name = model_name
    @error = error
  end

  def to_label
    "#{model_name.humanize} ##{id} (unavailable)"
  end

  def to_param
    id.to_s
  end

  def persisted?
    true
  end

  def error?
    true
  end

  private

  # NOTE: This catch-all is intentionally permissive — it returns nil for
  # any getter call so renderers and FieldValueResolver don't crash.
  # In development/test, we log access to help detect typos or stale field
  # references that would otherwise silently return nil.
  def method_missing(method_name, *args)
    if args.empty? && !method_name.to_s.end_with?("=")
      if !Rails.env.production?
        Rails.logger.debug(
          "[LcpRuby::API] ApiErrorPlaceholder##{method_name} called " \
          "on unavailable #{model_name} ##{id}"
        )
      end
      return nil
    end
    super
  end

  def respond_to_missing?(method_name, include_private = false)
    !method_name.to_s.end_with?("=") || super
  end
end
```

Renderers can detect the placeholder via `record.respond_to?(:error?) && record.error?` and display an appropriate indicator.

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
| Permissions (record_rules) | Yes | Yes | ConditionEvaluator works on in-memory attributes. **Caveat:** dot-path conditions (e.g., `building.status`) trigger lazy accessor API calls — potential N+1 on index pages. Batch preloading mitigates this for display, but record_rules evaluation happens per-record in `ActionSet#action_permitted_for_record?` |
| Permissions (scope) | Yes | Subset | `field_match`, `where`, `association` translated; `custom` not supported |
| Display renderers | Yes | Yes | Renderers work on field values |
| View slots | Yes | Yes | SlotContext is data-source agnostic |
| Custom actions | Yes | Phase 2 | Need writable data source |
| Events | Yes | Manual only | Dispatcher is agnostic, but AR callbacks don't fire. Host must dispatch explicitly |
| Quick search | Yes | Limited | Delegated to data source via `_quick_search` pseudo-filter |
| Advanced filters | Yes | Subset | Supported operators only, no Ransack |
| Saved filters | Yes | Subset | Condition-based filters work, scope-based do not. OR/NOT combinators in condition trees are flattened to AND — boolean logic is lost |
| Predefined filters | Yes | No | Require named scopes |
| Parameterized scopes | Yes | No | Require AR scopes |
| Default scope (presenter) | Yes | No | Requires AR scope |
| Custom filter interceptors | Yes | No | `filter_*` methods return AR scopes |
| Ransack | Yes | No | Requires ActiveRecord |
| Aggregation (sum/avg) | Yes | No | Requires SQL |
| Summary columns | Yes | No | Requires SQL aggregate functions |
| Summary bar | Yes | No | Requires SQL aggregate functions |
| Sorting (direct field) | Yes | Yes | Passed to data source |
| Sorting (dot-path) | Yes | No | Requires SQL JOIN |
| Sorting (aggregate) | Yes | No | Requires SQL subquery alias |
| Tree structures | Yes | No | Requires recursive CTE |
| Positioning | Yes | No | Requires DB updates |
| Soft delete | Yes | No | Requires DB column |
| Auditing | Yes | No | Requires AR callbacks |
| Custom fields | Yes | No | Requires JSON column |
| Userstamps | Yes | No | Requires DB columns |
| Attachments | Yes | No | Requires Active Storage |
| Bulk operations | Yes | No | Requires `update_all` |
| Sequences | Yes | No | Requires counter table + before_create |
| Computed fields | Yes | No | Requires before_save callback |
| Named scopes | Yes | No | Requires AR relation |
| Indexes | Yes | No | No database table |
| Nested attributes | Yes | No | Requires AR transaction |
| Associations (as target of belongs_to) | Yes | Yes | Lazy accessor + batch preload |
| Associations (as source of belongs_to) | Yes | Limited | FK fields work, no JOINs |
| Reverse associations (API has_many DB) | Yes | Yes | Query-based accessor, returns AR relation |
| Reverse associations (API has_many API) | Yes | No | Future extension |
| Association select (API target) | Yes | Yes | Via `lcp_select_options` |
| Association select: `group_by` | Yes | No | Requires AR query |
| Association select: `tree_select` | Yes | No | Requires all records + parent_id |
| Association select: `disabled_scope` | Yes | No | Requires AR scope |

#### ConfigurationValidator Enforcement

**Implementation prerequisite:** The `ConfigurationValidator` changes below must be implemented **before or simultaneously** with the model building changes. Without validation, API models with incompatible features (e.g., `auditing: true`) would crash at boot when the builder tries to skip unsupported applicators.

The validator adds a new `validate_api_model(model)` method called from `validate_models` when `model.api_model?` is true. It also adds a new branch for `id_field` / `field_mapping` conflict detection.

`ConfigurationValidator` enforces these constraints at boot time. For API models (`data_source_type != :db`), the following produce **errors**:

| YAML key | Reason |
|----------|--------|
| `options.auditing: true` | Requires AR callbacks |
| `options.soft_delete: true` | Requires DB column |
| `options.userstamps: true` | Requires DB columns + before_save |
| `options.tree: true` | Requires recursive CTE + parent_id column |
| `options.custom_fields: true` | Requires `custom_data` JSON column |
| `positioning:` (any value) | Requires `positioning` gem + DB column |
| `indexes:` (any value) | No database table |
| `scopes:` with `where`/`where_not` | Requires AR relation |
| `scopes:` with `type: parameterized` | Requires AR scope |
| `fields` with `type: attachment` / `type: file` | Requires Active Storage (DB-backed) |
| `fields` with `gapfree_sequence` | Requires counter table + before_create |
| `aggregates:` (any value) | Requires SQL subqueries |
| `fields` with `computed:` | Requires before_save callback |
| `associations` with `nested_attributes` | Requires AR `accepts_nested_attributes_for` |
| `data_source` with both `id_field` and `field_mapping` → `id` | Ambiguous PK mapping — use one or the other |
| `data_source: {}` (empty hash, no `type` key) | Probably a mistake — `type` defaults to `db` but the presence of `data_source` key suggests API intent |

The following produce **warnings**:

| Config | Reason |
|--------|--------|
| Permission `scope.type: custom` for this model | Cannot translate arbitrary Ruby to API filters |
| Presenter `search.default_scope` | Named scope not available |
| Presenter `search.predefined_filters` | Named scopes not available |
| Presenter `default_sort` with dot-path | Cross-association sort not supported |
| Presenter `summary` columns | SQL aggregates not available |
| Presenter `summary_bar` | SQL aggregates not available |
| Presenter `reorderable: true` | Requires positioning |
| Presenter association select with `group_by` | Requires AR query |
| Presenter association select with `disabled_scope`/`legacy_scope` | Requires AR scope |
| Presenter association select with `filter` (raw WHERE) | Requires AR |
| Presenter association select with `tree_select` | Requires all records + parent_id |
| `events` with lifecycle callbacks | AR callbacks don't fire; host must dispatch manually |
| Saved filters with OR/NOT combinators | Boolean logic flattened to AND in `ApiFilterTranslator` — results may differ |

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

  # Override do_search (not search) — Base#search auto-injects model_name
  def do_search(params, sort:, page:, per:)
    query = { offset: (page - 1) * per, limit: per }
    query[:sort] = "#{sort[:field]}:#{sort[:direction]}" if sort
    params[:filters]&.each { |f| query[f[:field]] = f[:value] }

    json = ErpClient.get("/products", query: query)
    LcpRuby::SearchResult.new(
      records: json["items"].map { |p| hydrate(p) },
      total_count: json["total"],
      current_page: page,
      per_page: per,
      model_name: model_class.model_name
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

1. `Metadata::Loader` parses YAML — `data_source` key is parsed into `ModelDefinition.data_source_config` as a first-class attribute (not a lazy `raw_hash` lookup).
2. `ConfigurationValidator` runs — validates API model constraints (see Applicator Compatibility Matrix and ConfigurationValidator Enforcement). **Must run before builder** to catch errors early.
3. `ModelFactory::Builder.build(model_definition)`:
   - If `api_model? == false` → current flow (AR class, SchemaManager, all applicators).
   - If `api_model? == true` → new flow: build ActiveModel class, skip incompatible applicators (see Applicator Compatibility Matrix), apply compatible applicators only.
4. `LcpRuby.registry.register(name, model_class)` — no changes, registry stores both AR and API model classes.
5. New: `DataSource::Setup.apply!(loader)` — instantiates and attaches data source adapters, wraps with cache/resilient decorators.
6. Existing subsystems (`Presenter::Resolver`, `Authorization::PolicyFactory`, etc.) work unchanged — they read from the registry and metadata, not from AR directly.

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
| DB | API | `has_many` | Lazy accessor calling target's `lcp_data_source.search(filter: {fk: id})` — returns `SearchResult`. **Note:** The `_association_list.html.erb` partial calls `.reorder()` and `.limit()` in the scoped branch, which won't work on `SearchResult`. The partial must use the non-scoped branch (in-memory sort/limit via `.to_a`) for this case. `ConfigurationValidator` warns if `association_list` section has `scope:` for a DB → API has_many |
| API | API | `belongs_to` | Lazy accessor calling target's `find(fk_value)` via data source |
| API | API | `has_many` | Not supported in Phase 1 |

The **API → DB `has_many`** case is particularly clean because the accessor returns a real AR relation. The existing `association_list` partial works unchanged — it can call `.reorder()`, `.limit()`, `.public_send(scope_name)` on the result. There is no N+1 concern because show pages have a single parent record.

### Controller Branching Strategy

The controller branching strategy is detailed in the [Controller Integration](#controller-integration) section above. The key design: a `QueryStrategy` object encapsulates all data-access divergence (`policy_scope`, `find_record`, `apply_advanced_search`, `apply_sort`, `paginate`, `select_options`). The controller delegates to the strategy and receives either an AR relation (DB models) or a `SearchResult` (API models) — both respond to `each`, `total_count`, `current_page`, etc.

### Phase 2: CRUD Extension Points

The architecture is designed so that adding write operations requires:

1. Data source classes override `save(record)` and `destroy(record)`, set `writable? = true`.
2. Controller's create/update/destroy actions check `api_model?` and delegate to data source.
3. Presenter adds `edit`, `create`, `destroy` actions.
4. Validation errors from the API are mapped to `ActiveModel::Errors` on the record.

No architectural changes are needed — only filling in the method implementations.

## Decisions

1. **Virtual model approach (ActiveModel, not AR facade).** API models are ActiveModel classes, not ActiveRecord subclasses pretending to talk to a database. This avoids the fragility of simulating AR internals and makes the boundary explicit. The tradeoff — some features (Ransack, Kaminari, aggregation) require separate handling — is acceptable because those features fundamentally depend on SQL.

2. **Localized controller branching with mandatory runtime guards.** The controller branches at ~12 specific points (see Points of Divergence table) via a strategy object. Even though `ConfigurationValidator` warns about unsupported features at boot time, runtime guards (`return if api_model?`) are mandatory at each branching point to protect against misconfigured YAML. The cost is a single boolean check per action — negligible compared to the risk of a 500 error.

3. **Cross-source associations via lazy accessors, not AR macros.** When a DB model references an API model, the platform generates method-based accessors with instance caching and batch preloading support, rather than trying to make AR `belongs_to` work without a SQL table.

4. **Cache as a decorator, not embedded in the adapter.** Caching wraps the data source transparently. The adapter itself is pure I/O. This keeps adapters simple and makes caching behavior consistent across adapter types.

5. **No boot-time schema validation.** The platform trusts the YAML configuration and does not call external APIs during boot. Runtime warnings and a rake task provide schema drift detection without risking boot failures.

6. **Readonly MVP with CRUD-ready contract.** The data source contract includes `save` and `destroy` methods that raise `ReadonlyError` by default. Phase 2 only requires overriding these methods — no contract changes.

7. **Filter operators defined at model level, not presenter level.** The model (via its `data_source` config) declares which filter operators it supports — because the model knows its data source capabilities. The presenter only controls which fields appear in the filter UI. `FilterMetadataBuilder` reads operators from the model definition and the filter UI disables unsupported operators automatically.

    **Note:** `ApiFilterTranslator` is defined with explicit handling for Ransack param parsing (field/operator disambiguation using model field names), condition tree translation, and unsupported-operator dropping. OR predicates and association-path predicates are explicitly unsupported and dropped with warnings.

8. **Best-effort compensation for cross-source writes (Phase 2).** When a DB transaction includes API calls, the platform attempts to roll back DB changes if the API call fails. The compensation code re-raises `ConnectionError` after `ActiveRecord::Rollback` (which itself silently swallows the error) so the controller can display an error. This is explicitly documented as best-effort, not guaranteed — if the DB commit succeeds before an API failure is detected (e.g., in `after_commit`), the DB change persists. For strict consistency, host providers should implement their own saga/compensation logic.

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

The platform generates a **query-based accessor** on the API model class. The FK field name comes from the `AssociationDefinition`, not hardcoded — this handles non-conventional FK names:

```ruby
# Generated on LcpRuby::Dynamic::ExternalBuilding
# assoc_def.name = "work_orders", assoc_def.target_model = "work_order",
# assoc_def.foreign_key = "building_id"
fk_field = assoc_def.foreign_key
target_model_name = assoc_def.target_model

define_method(assoc_def.name) do
  target_class = LcpRuby.registry.model_for(target_model_name)
  target_class.where(fk_field => id)
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
- DB models: all operators from `OperatorRegistry::OPERATORS_BY_TYPE` are supported (Ransack handles them)
- API models with `rest_json`: the default API operator set is supported (see the [Search and Filtering](#search-and-filtering) section for the full table: `eq`, `not_eq`, `cont`, `not_cont`, `start`, `not_start`, `end`, `not_end`, `lt`, `lteq`, `gt`, `gteq`, `in`, `not_in`, `null`, `not_null`, `present`, `blank`, `between`)
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

`FilterMetadataBuilder` (which generates the JSON metadata for the visual filter builder) reads operators from the model definition. For DB models, the existing `OperatorRegistry` type-to-operator mapping is used unchanged. For API models, the intersection logic is described in the [Search and Filtering](#search-and-filtering) section: `FilterMetadataBuilder` computes `OperatorRegistry.operators_for(base_type) & model_definition.data_source_supported_operators(base_type)`.

All operator names in the portable filter format match `OperatorRegistry` names exactly (e.g., `cont`, `gteq`, `start`), avoiding a double-translation layer.

The filter UI disables operators that are not in the intersection set. If a user somehow submits an unsupported operator (e.g., via URL manipulation), `ApiFilterTranslator` silently drops the filter term and logs a warning.

### Multi-Source Transactions (Phase 2)

When Phase 2 enables writes, cross-source operations (e.g., creating a DB record with an FK to an API record, or updating a DB record and then pushing changes to an API) are **not atomic**. The platform uses **best-effort compensation**:

```ruby
# Conceptual flow for create with cross-source association
def create_with_compensation(record, api_operations)
  api_error = nil

  ActiveRecord::Base.transaction do
    record.save!

    api_operations.each do |op|
      begin
        op.execute!
      rescue LcpRuby::DataSource::ConnectionError => e
        # API failed — roll back DB transaction.
        # IMPORTANT: raise ActiveRecord::Rollback silently rolls back the
        # transaction but does NOT re-raise — code after the transaction
        # block continues as if nothing happened. We must track the error
        # separately and re-raise after the block.
        Rails.logger.error(
          "[LcpRuby::API] Cross-source write failed, rolling back: #{e.message}"
        )
        api_error = e
        raise ActiveRecord::Rollback
      end
    end
  end

  # Re-raise after the transaction block so the controller can handle it.
  # At this point the DB transaction has been rolled back.
  if api_error
    raise LcpRuby::DataSource::ConnectionError,
          "Cross-source write failed: #{api_error.message}"
  end
end
```

**Behavior:**
- DB operations happen inside an AR transaction
- API operations happen sequentially after DB save but inside the transaction block
- If an API call fails, the DB transaction is rolled back and a `ConnectionError` is re-raised so the controller can display an error to the user
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
