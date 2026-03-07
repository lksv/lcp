# API-Backed Models Reference

API-backed models read data from external REST APIs or host-provided adapters instead of the database. They use the same field/presenter/permission structure as DB models, but are built with `ActiveModel` instead of `ActiveRecord`.

**Phase 1 (current):** Read-only access (index, show). Write operations return 404.

## Model YAML Configuration

### `data_source`

| | |
|---|---|
| **Required** | yes (for API models) |
| **Type** | hash |

The `data_source` key marks a model as API-backed. Models without `data_source` (or with `data_source.type: db`) are standard ActiveRecord models.

```yaml
model:
  name: external_building
  data_source:
    type: rest_json
    base_url: "https://gis.example.com/api/v2"
    resource: "/buildings"
    auth:
      type: bearer
      token_env: "GIS_API_TOKEN"
    pagination:
      style: offset_limit
    timeout: 10
    cache:
      enabled: true
      ttl: 300
      list_ttl: 60
      stale_on_error: true
    field_mapping:
      buildingNumber: number
      streetAddress: address
    supported_operators:
      default: [eq, not_eq, cont, in, null, not_null]
      string: [eq, not_eq, cont, start, end, in, null, not_null]
      integer: [eq, not_eq, lt, lteq, gt, gteq, in, null, not_null]
  fields:
    - name: number
      type: string
    - name: address
      type: string
    - name: floors
      type: integer
```

### `data_source.type`

| | |
|---|---|
| **Required** | yes |
| **Type** | string |
| **Values** | `rest_json`, `host` |

| Type | Description |
|------|-------------|
| `rest_json` | Built-in REST/JSON adapter with configurable endpoints, auth, and pagination |
| `host` | Host application provides a Ruby class implementing the data source contract |

### `data_source.base_url`

| | |
|---|---|
| **Required** | yes (for `rest_json`) |
| **Type** | string |

Base URL for the external API. The `resource` path is appended to this.

### `data_source.resource`

| | |
|---|---|
| **Required** | no |
| **Default** | `"/"` |
| **Type** | string |

Resource path appended to `base_url` for REST endpoints.

### `data_source.provider`

| | |
|---|---|
| **Required** | yes (for `host`) |
| **Type** | string (Ruby class name) |

Fully qualified class name of the host-provided data source. Must inherit from `LcpRuby::DataSource::Base`.

```yaml
data_source:
  type: host
  provider: "Erp::ProductDataSource"
```

### `data_source.auth`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Authentication configuration for the REST adapter. Three modes:

```yaml
# Bearer token
auth:
  type: bearer
  token_env: "API_TOKEN"        # reads from ENV

# Basic auth
auth:
  type: basic
  username_env: "API_USER"
  password_env: "API_PASS"

# Custom header
auth:
  type: header
  header_name: "X-Api-Key"
  value_env: "API_KEY"
```

### `data_source.pagination`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Pagination configuration for the REST adapter.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `style` | string | `offset_limit` | Pagination style: `offset_limit`, `page_number`, `cursor` |
| `default_per_page` | integer | 25 | Default page size |
| `max_per_page` | integer | 100 | Maximum page size |
| `params` | hash | | Map LCP params to API params (e.g., `page: "offset"`) |
| `response` | hash | | Map API response paths (e.g., `records: "data.items"`) |

### `data_source.timeout`

| | |
|---|---|
| **Required** | no |
| **Default** | 10 |
| **Type** | integer (seconds) |

HTTP request timeout for the REST adapter.

### `data_source.id_field`

| | |
|---|---|
| **Required** | no |
| **Default** | `"id"` |
| **Type** | string |

Which field in the API response is the primary key.

### `data_source.cache`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Caching configuration using `Rails.cache`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `enabled` | boolean | false | Enable caching |
| `ttl` | integer | 300 | TTL for individual record cache (seconds) |
| `list_ttl` | integer | 60 | TTL for search/list result cache (seconds) |
| `stale_on_error` | boolean | false | Serve expired cache when API is unreachable |

Cache keys: `lcp_ruby/api/{model_name}/record/{id}` and `lcp_ruby/api/{model_name}/search/{params_hash}`.

### `data_source.field_mapping`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Maps remote field names to local field names.

```yaml
field_mapping:
  buildingNumber: number      # remote "buildingNumber" → local "number"
  streetAddress: address
```

### `data_source.supported_operators`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Filter operators supported by this data source, keyed by field type. The filter UI disables unsupported operators. For `host` adapters, operators can also be declared programmatically via `supported_operators` method.

Default operators for `rest_json`: `eq`, `not_eq`, `cont`, `lt`, `lteq`, `gt`, `gteq`, `in`, `null`, `not_null`, `start`, `end`.

```yaml
supported_operators:
  default: [eq, not_eq, cont, in, null, not_null]
  string: [eq, not_eq, cont, start, end, in, null, not_null]
  integer: [eq, not_eq, lt, lteq, gt, gteq, in, null, not_null]
  enum: [eq, not_eq, in, null, not_null]
```

### `data_source.endpoints`

| | |
|---|---|
| **Required** | no |
| **Type** | hash |

Custom endpoint paths for the REST adapter. Defaults to REST conventions.

```yaml
endpoints:
  show: "/buildings/:id"
  search: "/buildings"
  batch: "/buildings/batch"
```

## DSL Configuration

```ruby
LcpRuby.define_model :external_building do
  data_source type: :rest_json,
              base_url: "https://gis.example.com/api/v2",
              resource: "/buildings",
              auth: { type: "bearer", token_env: "GIS_API_TOKEN" },
              cache: { enabled: true, ttl: 300 }

  field :number, :string
  field :address, :string
  field :floors, :integer
end
```

## Data Source Contract

Host-provided data sources must inherit from `LcpRuby::DataSource::Base` and implement:

| Method | Required | Returns | Description |
|--------|----------|---------|-------------|
| `find(id)` | yes | model instance | Fetch a single record by ID |
| `search(params, sort:, page:, per:)` | yes | `SearchResult` | Search/filter/paginate records |
| `find_many(ids)` | no | array | Batch fetch by IDs (default: sequential `find` calls) |
| `select_options(search:, filter:, sort:, label_method:, limit:)` | no | array of hashes | Options for association select dropdowns |
| `count(params)` | no | integer | Count matching records (default: calls `search`) |
| `supported_operators` | no | hash | Filter operators supported by this adapter |
| `writable?` | no | boolean | Whether write operations are supported (default: false) |

```ruby
class Erp::ProductDataSource < LcpRuby::DataSource::Base
  def find(id)
    json = ErpClient.get("/products/#{id}")
    hydrate(json)
  end

  def search(params, sort:, page:, per:)
    json = ErpClient.get("/products", query: build_query(params, sort, page, per))
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
    json = ErpClient.get("/products", query: { q: search, limit: limit }.compact)
    json["items"].map do |p|
      record = hydrate(p)
      { value: record.id, label: record.public_send(label_method) }
    end
  end

  private

  def hydrate(json)
    model_class.new(
      id: json["productId"],
      name: json["productName"],
      unit_price: json["unitPrice"]
    )
  end
end
```

## SearchResult

All API searches return a `LcpRuby::SearchResult` — a Kaminari-compatible value object:

| Attribute | Type | Description |
|-----------|------|-------------|
| `records` | array | The fetched records |
| `total_count` | integer | Total number of matching records |
| `current_page` | integer | Current page number (1-based) |
| `per_page` | integer | Records per page |
| `error` | object | Error object if the request failed |
| `message` | string | Human-readable error/status message |
| `stale` | boolean | Whether the data is from an expired cache |

Methods: `each`, `size`, `empty?`, `to_a`, `total_pages`, `limit_value`, `first_page?`, `last_page?`, `error?`, `stale?`.

## Cross-Source Associations

DB models can reference API models via foreign keys. The platform generates lazy accessors instead of AR `belongs_to`.

```yaml
# work_order.yml (DB model)
model:
  name: work_order
  fields:
    - name: title
      type: string
    - name: external_building_id
      type: string
  associations:
    - name: external_building
      type: belongs_to
      target_model: external_building    # API model
```

### Association Strategies

| Source | Target | Type | Strategy |
|--------|--------|------|----------|
| DB | API | `belongs_to` | Lazy accessor with instance cache, batch preload on index |
| API | DB | `belongs_to` | Lazy accessor calling AR `find` |
| API | DB | `has_many` | Query-based accessor returning AR relation |
| DB | API | `has_many` | Lazy accessor calling target's `search` |

### Batch Preloading

On index pages, the `IncludesResolver` detects cross-source associations and uses `ApiPreloader` to batch-load API records in a single `find_many` call instead of N+1 individual calls.

### Association Select in Forms

When a form field references an API model (`input_type: association_select`), the platform automatically uses remote search mode. The `select_options` controller action delegates to `lcp_select_options` on the target model's data source.

## Error Handling

Three levels of graceful degradation:

1. **Data source level:** `ResilientWrapper` catches connection errors and returns error-flagged `SearchResult` objects instead of raising.

2. **Association level:** When a lazy accessor fails to fetch an API record, it returns an `ApiErrorPlaceholder` that responds to `to_label` with `"ModelName #id (unavailable)"` and to any field getter with `nil`.

3. **View level:** Templates check for error/stale state and display a warning banner while rendering the rest of the page normally.

## Incompatible Features

These features are not available for API models. `ConfigurationValidator` reports an error if enabled:

| Feature | Reason |
|---------|--------|
| `soft_delete` | Requires DB column |
| `auditing` | Requires AR callbacks |
| `userstamps` | Requires DB columns |
| `tree` | Requires recursive CTE |
| `positioning` | Requires DB updates |
| `custom_fields` | Requires JSON column |

These features produce warnings:

| Feature | Reason |
|---------|--------|
| Scopes with `where`/`where_not` | Require ActiveRecord |
| SQL aggregates | Require SQL — use `service:` aggregates instead |

## Feature Availability

| Feature | DB model | API model |
|---------|----------|-----------|
| Index view | Yes | Yes |
| Show view | Yes | Yes |
| Create / Edit / Delete | Yes | Phase 2 |
| Permissions (field-level) | Yes | Yes |
| Permissions (record_rules) | Yes | Yes |
| Display renderers | Yes | Yes |
| Quick search | SQL LIKE | Delegated to data source |
| Advanced filters | All operators | Supported operator subset |
| Ransack | Yes | No |
| Aggregation (sum/avg) | Yes | No (service-based only) |
| Associations (as target of belongs_to) | Yes | Yes (lazy accessor + batch preload) |
| Reverse associations (API has_many DB) | Yes | Yes (returns AR relation) |
| Nested attributes | Yes | No |
| Attachments | Yes | No |
| Bulk operations | Yes | No |
