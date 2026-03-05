# Demo Application Design: E-Shop

**Status:** Proposed (Draft)
**Date:** 2026-03-05

## 1. Why E-Shop

| Criterion | E-Shop | HR System | Chess Academy |
|-----------|--------|-----------|---------------|
| Domain universality | Everyone understands shopping | Every company has HR | Niche but visually appealing |
| Dual-perspective UI | Storefront (customer) + Backoffice (admin/operator) | Employee self-service + HR admin | Student + coach |
| Real data availability | DummyJSON API — 194 products with images, reviews, carts | Faker-generated | Lichess API |
| Workflow need | Order lifecycle (pending -> paid -> shipped -> delivered) | Leave approvals | Game status |
| Permission complexity | Customer (own data), operator (orders), manager (full CRUD) | Multi-level org | Coach/student/admin |
| Aggregate showcase | Order totals, product rating averages, revenue sums | Headcount, leave balances | Ratings, win % |
| Tree structures | Category hierarchy (Electronics > Phones > Smartphones) | Departments, positions | Opening repertoire |
| Overlap with existing | None — CRM covers sales pipeline, Todo covers tasks | None | None |
| Attachment diversity | Product images, invoice PDFs | Photos, CVs, contracts | PGN files |
| Custom fields use case | Product attributes vary by category (RAM for laptops, size for clothing) | Employee attributes | Training metadata |

**Recommendation:** E-Shop demonstrates the platform's ability to build a production-grade information system with two distinct user perspectives from shared metadata. The universally understood domain makes the demo immediately relatable.

---

## 2. Data Source

### Primary: DummyJSON API

**URL:** `https://dummyjson.com/products?limit=0`

194 products with rich metadata — seeded via HTTP in `seeds.rb`. Key endpoints:

| Endpoint | Records | Use |
|----------|---------|-----|
| `/products?limit=0` | 194 | Product catalog with images, reviews, dimensions |
| `/users?limit=0` | 208 | Customer data with addresses, roles |
| `/carts?limit=0` | 50 | Shopping carts with product references and quantities |

Advantages:
- Zero setup (public REST API, no auth, no download)
- Real product names, descriptions, images (hosted URLs)
- Nested reviews with ratings, dates, reviewer info
- Categories, brands, tags, SKUs, stock levels
- Carts with product references for order generation

### Supplementary: Olist Brazilian E-Commerce (Kaggle)

~100k real orders from 2016-2018. CSV download (~44 MB). Provides realistic order lifecycle data with statuses, payments, shipments, and reviews that DummyJSON lacks. Could be used as optional extended seed for stress-testing the admin backoffice with large data volumes.

---

## 3. Data Model Overview

### 3.1 Entity Relationship Diagram (conceptual)

```
                    +-------------------+
                    |     Category      |
                    | (tree structure)  |
                    +--------+----------+
                             |
                             | belongs_to (parent)
                             | has_many (children)
                             |
+-------------+    +---------+----------+    +-------------+
|    Brand    |----| Product             |----|  ProductTag |----| Tag |
+-------------+    | price, stock, sku   |    +-------------+    +-----+
                   | discount, weight    |
                   | dimensions (json)   |
                   +----+------+--------+
                        |      |
                        |      | has_many
                        |      v
                        |  +----------+
                        |  |  Review  |
                        |  | rating   |
                        |  | comment  |
                        |  +----------+
                        |
                        | has_many (through OrderItem)
                        v
+-------------+    +----+------+    +-----------+
|  Customer   |----|   Order   |----| Payment   |
| email,phone |    | status    |    | method    |
| address(json|    | total     |    | amount    |
+-------------+    +-----+-----+    +-----------+
                         |
                   +-----+-------+
                   |  OrderItem  |
                   | quantity    |
                   | unit_price  |
                   | line_total  |
                   +-------------+
                         |
                   +-----+-------+
                   |  Shipment   |
                   | carrier     |
                   | tracking_no |
                   | shipped_at  |
                   +-------------+

                   +-------------+
                   |   Coupon    |
                   | code, type  |
                   | discount    |
                   | valid_from  |
                   | valid_to    |
                   +-------------+
```

### 3.2 Model Details

#### Category (tree)
| Field | Type | Notes |
|-------|------|-------|
| name | string | required |
| slug | string | unique, for URL |
| description | text | optional |
| parent_id | integer | self-referential (tree) |
| position | integer | ordering within parent |
| image | attachment | category thumbnail |

**LCP features:** tree structure, positioning, tiles view for storefront browsing.

#### Brand
| Field | Type | Notes |
|-------|------|-------|
| name | string | required, unique |
| website | url | business type |
| logo | attachment | brand image |
| description | text | optional |

#### Product
| Field | Type | Notes |
|-------|------|-------|
| title | string | required |
| description | rich_text | product detail |
| sku | string | unique |
| price | decimal | precision: 10, scale: 2 |
| discount_percentage | decimal | 0-100 |
| stock | integer | default: 0 |
| availability_status | enum | in_stock, low_stock, out_of_stock |
| weight | decimal | kg |
| dimensions | json | {width, height, depth} |
| warranty_info | string | |
| shipping_info | string | |
| return_policy | enum | 30_days, 90_days, no_return |
| minimum_order_quantity | integer | default: 1 |
| barcode | string | EAN/UPC |
| thumbnail | attachment | main image |
| category_id | integer | FK -> Category |
| brand_id | integer | FK -> Brand |

**Computed fields:**
- `discounted_price` — `price * (1 - discount_percentage / 100)`
- `rating_avg` — aggregate AVG from reviews

**LCP features:** currency renderer, percentage renderer, rating renderer, badge renderer (availability), json field (dimensions), computed fields, aggregates.

#### ProductImage
| Field | Type | Notes |
|-------|------|-------|
| product_id | integer | FK -> Product |
| image | attachment | Active Storage |
| position | integer | display order |
| alt_text | string | accessibility |

**LCP features:** positioning, attachment. Note: image gallery renderer does not exist yet (see section 5).

#### Tag
| Field | Type | Notes |
|-------|------|-------|
| name | string | required, unique |
| slug | string | unique |

#### ProductTag (join)
| Field | Type | Notes |
|-------|------|-------|
| product_id | integer | FK -> Product |
| tag_id | integer | FK -> Tag |

**Note:** Ideally tags would use the planned array field type, but has_many :through works as a fallback.

#### Review
| Field | Type | Notes |
|-------|------|-------|
| product_id | integer | FK -> Product |
| customer_id | integer | FK -> Customer |
| rating | integer | 1-5 |
| title | string | optional |
| comment | text | required |

**LCP features:** rating renderer, record_rules (only author can edit), userstamps, conditional rendering.

#### Customer
| Field | Type | Notes |
|-------|------|-------|
| email | email | business type, unique |
| first_name | string | required |
| last_name | string | required |
| phone | phone | business type |
| billing_address | json | {street, city, zip, state, country} |
| shipping_address | json | {street, city, zip, state, country} |
| registration_date | date | |

**Computed fields:**
- `full_name` — template `"{first_name} {last_name}"`
- `order_count` — aggregate COUNT
- `total_spent` — aggregate SUM of orders.total

**LCP features:** email/phone types, json fields, computed fields, aggregates.

#### Order
| Field | Type | Notes |
|-------|------|-------|
| customer_id | integer | FK -> Customer |
| status | enum | pending, confirmed, paid, shipped, delivered, cancelled, refunded |
| total | decimal | precision: 10, scale: 2 |
| notes | text | internal notes for operators |
| coupon_id | integer | FK -> Coupon, optional |
| ordered_at | datetime | |
| confirmed_at | datetime | |
| paid_at | datetime | |
| shipped_at | datetime | |
| delivered_at | datetime | |

**Computed fields:**
- `items_total` — aggregate SUM of order_items.line_total
- `item_count` — aggregate COUNT of order_items

**LCP features:** enum + badge renderer (status), currency renderer (total), auditing (track status changes), soft_delete, conditional rendering (show shipped_at only when status >= shipped), custom actions ("Confirm Order", "Mark as Shipped", "Cancel Order"), record_rules (cannot edit delivered orders).

**Workflow note:** Status transitions should be enforced (e.g., pending -> confirmed -> paid -> shipped -> delivered). Without a built-in workflow engine, this is modeled via custom actions with condition guards. See section 5.

#### OrderItem
| Field | Type | Notes |
|-------|------|-------|
| order_id | integer | FK -> Order |
| product_id | integer | FK -> Product |
| quantity | integer | min: 1 |
| unit_price | decimal | snapshot at order time |
| line_total | decimal | computed: quantity * unit_price |

**LCP features:** nested_fields (inline editing within Order form), computed fields, currency renderer.

#### Payment
| Field | Type | Notes |
|-------|------|-------|
| order_id | integer | FK -> Order |
| method | enum | credit_card, debit_card, bank_transfer, paypal, cash_on_delivery |
| amount | decimal | |
| status | enum | pending, completed, failed, refunded |
| paid_at | datetime | |
| transaction_id | string | external reference |

**LCP features:** enum + badge, currency, conditional rendering (transaction_id visible only when completed).

#### Shipment
| Field | Type | Notes |
|-------|------|-------|
| order_id | integer | FK -> Order |
| carrier | enum | dhl, ups, fedex, czech_post, zasilkovna |
| tracking_number | string | |
| shipped_at | datetime | |
| estimated_delivery | date | |
| delivered_at | datetime | |

**LCP features:** url type (tracking link), datetime fields, conditional rendering.

#### Coupon
| Field | Type | Notes |
|-------|------|-------|
| code | string | unique, required |
| discount_type | enum | percentage, fixed_amount |
| discount_value | decimal | |
| minimum_order | decimal | optional |
| valid_from | date | |
| valid_to | date | |
| usage_limit | integer | optional, max uses |
| usage_count | integer | default: 0 |
| active | boolean | |

**LCP features:** conditional rendering (discount_value label changes based on discount_type), record_rules (cannot edit expired coupons), badge renderer (active/expired).

---

## 4. Presenters

### Storefront Presenters (customer-facing)

| Presenter | Slug | Layout | Key Features |
|-----------|------|--------|--------------|
| Product Catalog | `products` | tiles | Image thumbnail, price with discount, rating stars, availability badge, category filter |
| Product Detail | `products` (show) | sections | Full description, image gallery, dimensions table, reviews list, related products |
| Category Browser | `categories` | tree + tiles | Hierarchical category navigation |
| My Orders | `my-orders` | table | Customer's own orders with status badges, order total |
| My Reviews | `my-reviews` | table | Customer's submitted reviews |

### Backoffice Presenters (operator/manager)

| Presenter | Slug | Layout | Key Features |
|-----------|------|--------|--------------|
| Order Management | `orders` | table | Status filter tabs (predefined scopes), quick search, bulk status update, order total |
| Order Detail | `orders` (show) | sections | Customer info, order items (nested), payment, shipment, status timeline, audit log |
| Product Management | `admin-products` | table | Full CRUD, stock levels, pricing, category/brand filters |
| Customer Management | `customers` | table | Order count aggregate, total spent aggregate, registration date |
| Coupon Management | `coupons` | table | Active/expired filter, usage stats |
| Shipment Tracking | `shipments` | table | Carrier filter, delivery status |
| Revenue Dashboard | `dashboard` | read-only | Total revenue, orders this month, top products, average order value |

### Predefined Scopes (Filter Tabs)

```yaml
# Order scopes
scopes:
  - name: pending
    where: { status: pending }
  - name: needs_shipping
    where: { status: paid }
  - name: in_transit
    where: { status: shipped }
  - name: completed
    where: { status: delivered }
  - name: cancelled
    where: { status: [cancelled, refunded] }

# Product scopes
scopes:
  - name: in_stock
    where_not: { stock: 0 }
  - name: low_stock
    where: { availability_status: low_stock }
  - name: out_of_stock
    where: { stock: 0 }
```

---

## 5. Features Required but Not Yet Implemented

### 5.1 Image Gallery Renderer (High Priority)

**Problem:** Products have multiple images (ProductImage model with positioning). The current `image` renderer shows only a single image. The `attachment_list` renderer shows file links, not visual previews.

**Needed behavior:**
- Thumbnail grid on index pages (show first image only)
- Gallery view on show page: main image + thumbnail strip below
- Lightbox on click for full-size viewing
- Respects positioning order

**Possible approach:** New `gallery` renderer that collects images from a has_many association and renders them as a positioned grid. Lightbox could use a lightweight JS library (e.g., GLightbox) or a Stimulus controller.

### 5.2 Array Field Type (High Priority)

**Problem:** Product tags are naturally an array of strings (`["beauty", "mascara", "cosmetics"]`). Currently modeled as has_many :through join table, which works but adds model/table overhead for simple label lists.

**Design exists:** `docs/design/array_field_type.md`

**Needed for e-shop:**
- Product tags (array of strings)
- Product colors/sizes (array of strings)
- Potentially: search filter values

### 5.3 Workflow / State Machine (Medium Priority)

**Problem:** Order status transitions should be enforced. Currently, an enum field allows any value change. Custom actions can guard individual transitions, but there is no declarative way to define allowed transitions, auto-set timestamps on transition, or show a visual status timeline.

**Design exists:** `docs/design/workflow_and_approvals.md`

**Workaround for demo:**
- Enum field for status display
- Custom actions for each transition ("Confirm", "Mark Paid", "Ship", "Deliver", "Cancel")
- `record_rules` to hide actions based on current status
- `visible_when` to show timestamp fields only after transition

This workaround is functional but verbose. A native workflow engine would reduce the configuration from ~50 lines of custom action definitions to ~10 lines of transition declarations.

### 5.4 CSV/Excel Export (Low Priority)

**Problem:** Admin/operators want to export order lists, customer lists, and product catalogs. No built-in export capability exists.

**Possible approach:** Custom action type `export` that generates CSV/XLSX from the current filtered query. Could be a view slot component (toolbar button) or a custom action.

### 5.5 Dashboard with Charts (Low Priority)

**Problem:** Revenue dashboard needs visual charts (bar chart for monthly revenue, pie chart for order status distribution, line chart for trends). Current dashboard support is read-only aggregate display without graphing.

**Possible approach:** Chart renderer type that integrates Chart.js or similar via a Stimulus controller. Aggregate data could come from existing aggregate query infrastructure.

---

## 6. Permissions

### Roles

| Role | Description |
|------|-------------|
| `customer` | End-user who browses products, places orders, writes reviews |
| `operator` | Backoffice staff managing orders, shipments, customer inquiries |
| `manager` | Full access including products, coupons, reports, and user management |
| `admin` | Manager + custom fields, permission management |

### Permission Matrix

| Model | customer | operator | manager | admin |
|-------|----------|----------|---------|-------|
| Category | read | read | CRUD | CRUD |
| Brand | read | read | CRUD | CRUD |
| Product | read | read | CRUD | CRUD |
| Review | read + create own | read | CRUD | CRUD |
| Customer | read own | read | CRUD | CRUD |
| Order | read own | read + update | CRUD | CRUD |
| OrderItem | read own | read | CRUD | CRUD |
| Payment | read own | read + update | CRUD | CRUD |
| Shipment | read own | read + update | CRUD | CRUD |
| Coupon | — | read | CRUD | CRUD |

### Record Rules

```yaml
# Reviews: only author can edit/delete
record_rules:
  - actions: [edit, destroy]
    condition:
      field: customer_id
      operator: equals
      value: :current_user_id
    except_roles: [manager, admin]

# Orders: cannot edit delivered/cancelled orders
record_rules:
  - actions: [edit]
    deny_when:
      field: status
      operator: in
      value: [delivered, cancelled, refunded]
    except_roles: [admin]
```

### Scoped Access

```yaml
# Customer sees only own orders
scope:
  customer: { customer_id: :current_user_id }
  operator: all
  manager: all
```

---

## 7. Seed Strategy

```ruby
# Simplified seed flow
require "net/http"
require "json"

base = "https://dummyjson.com"

# 1. Fetch and create categories (extract unique from products)
# 2. Fetch and create brands (extract unique from products)
# 3. Fetch products -> create Product records with associations
# 4. Extract reviews from products -> create Review records
# 5. Fetch users -> create Customer records
# 6. Fetch carts -> generate Order + OrderItem + Payment + Shipment records
#    with randomized statuses and timestamps
# 7. Generate Coupons (synthetic)
```

**Volume:** ~194 products, ~20 categories, ~30 brands, ~500 reviews, ~100 customers, ~200 orders with ~600 order items. Enough for a convincing demo without overwhelming the UI.

---

## 8. Usage Examples

### Customer browsing products (tiles view)
- Open `/products` — tiles layout with product images, prices, ratings
- Filter by category using tree select or predefined scope tabs
- Click product — show page with description, gallery, reviews
- Write a review (if logged in)

### Operator processing orders
- Open `/orders` — table with status filter tabs (Pending | Needs Shipping | In Transit)
- Click pending order — see items, customer info, payment status
- Click "Confirm Order" action -> status changes to confirmed, confirmed_at set
- After payment received: "Mark as Paid" -> status changes to paid
- Enter shipment details, click "Ship Order" -> status shipped, tracking number saved
- Audit log tracks every status change with user and timestamp

### Manager viewing dashboard
- Open `/dashboard` — read-only presenter with aggregates
- Total revenue (SUM of completed orders)
- Orders this month (COUNT with date scope)
- Top 5 products by order count
- Average order value

---

## 9. Feature Gap Analysis for E-Shop

### Critical (e-shop looks incomplete without these)

| Feature | Description | Priority | Existing Design |
|---------|-------------|----------|-----------------|
| Image gallery renderer | Display multiple product images (carousel/grid with lightbox). Currently only single `image` renderer exists. | High | — |
| Tags / array field | Product tags, colors, sizes. Workaround: has_many :through, but no tag input UI. | High | `docs/design/array_field_type.md` |
| Workflow / state machine | Order status transitions with enforcement (pending->paid, not pending->delivered). Can be worked around with enum + custom actions + record_rules, but without enforced transitions. | Medium | `docs/design/workflow_and_approvals.md` |
| Import/Export CSV | Bulk product import from seed is OK, but admin wants to export orders to Excel. | Medium | — |

### Useful (improves demo quality)

| Feature | Description | Priority |
|---------|-------------|----------|
| Dashboard with charts | Order overview, monthly revenue, top products. Basic dashboard exists, charting integration (Chart.js) missing. | Medium |
| Multi-image attachment | `has_many_attached :images` works, but no dedicated gallery renderer with preview. | Medium |
| Faceted search | Product filtering with counts (category: Electronics (42), Clothing (18)...). Filter builder exists, but without aggregated counts. | Low |
| Comments/Notes | Internal notes on orders for operators. Solvable as separate model + nested section. | Low |
| Geo/Map renderer | Display customer address on map. Specific, not necessary. | Low |
| Notifications | Email on order status change. Solvable via event handlers + Rails mailer in host app. | Low |

### Solvable with Existing Features

| Need | Solution in LCP Ruby |
|------|---------------------|
| Order status display | enum + `renderer: badge` + custom actions ("Mark as Shipped") + record_rules |
| Order total price | aggregate (SUM) or computed field |
| Product rating | aggregate (AVG of reviews.rating) |
| Category hierarchy | tree structure (already implemented) |
| Shopping cart | Standalone Cart + CartItem models with nested_fields |
| Discount / coupon | Conditional field via `visible_when` |

---

## 10. Open Questions

1. **Product variants (size/color)?** Should products have variants with separate stock tracking (like a real e-shop), or keep it simple with just the base product? Variants would exercise nested_fields and json fields heavily but add significant complexity.

2. **Wishlist / Favorites?** A simple join table (customer_id, product_id) could showcase saved filters or bookmarking. Low effort, nice UX touch.

3. **Search experience?** Should the storefront use quick search + category tree, or implement a more sophisticated search with relevance ranking? Current Ransack-based search works but is not optimized for full-text product search.

4. **Multi-currency?** DummyJSON prices are in USD. Should the demo support currency conversion, or keep single-currency? Single currency is simpler and sufficient for the demo.

5. **Olist data integration?** Worth adding an optional seed script for the Olist dataset (100k orders) to demonstrate large-data performance? Would require CSV parsing and Portuguese-to-English mapping.

6. **Storefront vs. admin as separate mountpoints?** Should the customer-facing presenters and admin presenters be mounted at different paths (e.g., `/shop` and `/admin`), or use the same mountpoint with role-based presenter visibility? The latter is more natural for LCP Ruby but may need view group improvements.
