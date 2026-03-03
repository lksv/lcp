# Routing and URL Mapping — Requirements

Legend: `[x]` = supported, `[~]` = partially supported (requires custom code), `[ ]` = not supported

## Route Definitions from Metadata

- [x] Routes automatically generated from entities and view definitions (without manual configuration) — slug-based routing from presenters
- [x] Convention: `/{module}/{entity}` → list, `/{module}/{entity}/{id}` → detail — `/:lcp_slug`, `/:lcp_slug/:id`
- [ ] Custom routes defined in metadata (overriding convention)
- [ ] Route aliases (multiple URLs lead to same view — e.g., `/customers` and `/clients`)
- [ ] Namespace / prefix per module (`/crm/contacts`, `/eshop/orders`)
- [ ] Namespace per tenant (subdomain or prefix: `tenant1.app.com` or `/t/tenant1/...`)
- [ ] Route versioning (v1/v2 for API, preserving old URLs on refactor)
- [ ] Catch-all / fallback route (custom 404 page)

## URL Structure and Conventions

- [x] RESTful conventions for CRUD:
  - [x] `GET /{entity}` → list view
  - [x] `GET /{entity}/new` → create form
  - [x] `GET /{entity}/{id}` → detail / read view
  - [x] `GET /{entity}/{id}/edit` → edit form
  - [~] `GET /{entity}/{id}/{relation}` → related records (nested resource) — not as URL, but via show page associations
- [x] Slug-based URLs (friendly URLs: `/deals` instead of `/entity/12345`) — presenter slug
- [ ] Slug field configuration per entity (from metadata — typically `name` or `title`)
- [ ] Slug uniqueness (automatic suffix on collision: `red-shirt-2`)
- [ ] Hierarchical URL support (`/category/clothing/shirts/red-shirt`)
- [ ] Composite key support in URL (`/{entity}/{id1}/{id2}`)

## Query Parameters and URL State

- [~] Filters encoded in query parameters (`?status=active&priority=high`) — search query preserved, but no full filter serialization
- [~] Sorting in query parameters (`?sort=created_at&order=desc`) — basic sort params supported
- [x] Pagination in query parameters (`?page=3&per_page=25`) — Kaminari
- [ ] Selected tab / section in URL (`?tab=history` or hash `#history`)
- [x] Search expression in URL (`?q=novak`) — search query param
- [~] Saved filter as named route (`/{entity}?saved_filter=my-urgent`) — `?saved_filter=<id>` URL param supported, SavedFilters::Resolver applies default filter
- [x] All query parameters optional (URL without parameters → default view)
- [ ] Serialization / deserialization of complex filters (nested AND/OR conditions in URL)
- [ ] URL encoding of special characters (diacritics, spaces)

## Navigation and Transitions

- [ ] Client-side routing (SPA — without full page reload)
- [ ] Prefetching (preloading data on link hover)
- [ ] Preserving scroll position on back navigation
- [ ] Preserving form state on back navigation (unsaved changes)
- [ ] Confirmation on leaving unsaved form (dirty state guard)
- [ ] Transition animations between views (configurable)
- [ ] Loading state on transition (skeleton / spinner)

## Deep Linking and Sharing

- [~] Every application state has unique URL (view + filter + sort + page + tab) — partial: page and search, not full state
- [ ] URL sharing between users (recipient sees same view, if authorized)
- [ ] URL shortener for long URLs with many parameters
- [ ] QR code generation for URL (for mobile access)
- [x] Link opening respects permissions (no access → redirect to login or 403) — Pundit authorization
- [ ] Permalink to specific record (stable URL even on slug change)
- [ ] Copy URL to clipboard ("Share link" button)

## Breadcrumbs and Contextual Navigation

- [x] Breadcrumbs automatically generated from route hierarchy — BreadcrumbBuilder
- [ ] Breadcrumbs respect user path (not just static hierarchy)
- [x] Breadcrumbs for nested resources (`Customers > Novak Ltd. > Orders > #1234`) — BreadcrumbPathHelper
- [x] Clickable breadcrumbs (navigation to any level)
- [x] Custom breadcrumb labels from metadata (display record name instead of ID)

## Redirects

- [x] Redirect after successful action (after save → detail, after delete → list)
- [ ] Configurable redirect per action per entity (from metadata)
- [ ] Redirect after login to original URL (return_to parameter)
- [x] Redirect on insufficient permissions (403 → login or dashboard) — Pundit denial handling
- [~] Redirect on non-existent record (404 → list with message) — standard Rails 404
- [ ] Redirect on URL structure change (301 permanent redirect for old URLs)
- [ ] Redirect loop detection (infinite redirect protection)
- [ ] Wildcard redirects (old URL patterns → new patterns)

## Middleware and Guards

- [~] Auth guard (unauthenticated user → redirect to login) — host app responsibility, engine checks `current_user`
- [x] Role guard (insufficient role → 403 or redirect) — Pundit policies
- [ ] Tenant guard (user doesn't have tenant access → 403)
- [ ] Feature flag guard (view available only when feature is enabled)
- [ ] Workflow state guard (edit view available only in certain state)
- [ ] Maintenance mode guard (redirect to maintenance page)
- [ ] Guard chaining (auth → tenant → role → feature flag → view)
- [ ] Custom middleware (logging, analytics tracking, A/B testing)

## Dynamic and Contextual Routes

- [x] Routes conditionally available by role (admin sees `/admin/*`, user doesn't) — menu visibility + presenter permissions
- [ ] Routes conditionally available by record state
- [x] Contextual sub-routes (on record detail: `/edit`, `/custom-fields`) — edit, custom-fields routes
- [ ] Wizard routes (multi-step form: `/new/step-1`, `/new/step-2`, `/new/step-3`)
- [ ] Modal routes (open detail in modal instead of navigation — overlay route)
- [ ] Side panel routes (detail in side panel, list remains visible)

## Special Pages

- [ ] Dashboard / home page (per role — configurable from metadata)
- [ ] Login / registration / password reset pages
- [ ] 403 Forbidden page (custom content, back navigation)
- [ ] 404 Not Found page (with search, similar URL suggestions)
- [ ] 500 Error page (with error ID for support)
- [ ] Maintenance page
- [ ] Onboarding / welcome page (for new users)
- [ ] User profile / settings page
- [ ] Admin panel routes (separate namespace `/admin/*`)

## SEO and Crawlability (for public sections)

- [ ] Server-side rendering / pre-rendering for public pages
- [ ] Meta tags from metadata (title, description, og:image per entity / per record)
- [ ] Canonical URL (duplicate content prevention)
- [ ] Sitemap generation from metadata (for public entities)
- [ ] robots.txt configuration (blocking internal routes)
- [ ] Structured data / JSON-LD (for public entities — products, events...)
- [ ] Hreflang tags (multilingual page versions)

## API Routing

- [ ] API routes automatically generated from entities (`/api/v1/{entity}`)
- [ ] API routes separated from UI routes (different prefix, different middleware stack)
- [ ] API route documentation (OpenAPI / Swagger automatically from metadata)
- [ ] API versioning in URL (`/api/v1/`, `/api/v2/`)
- [ ] Custom API endpoints for business logic (defined in metadata)
- [ ] GraphQL endpoint (`/api/graphql` — one endpoint, schema from metadata)
- [ ] Incoming webhook endpoints (`/api/webhooks/{integration}`)

## Performance and Optimization

- [ ] Route caching (compile route map at startup, not on every request)
- [ ] Code splitting per route (lazy loading JS bundles — load only code for current view)
- [ ] Preloading of next probable routes (predictive prefetch)
- [ ] Route-level caching (entire page cached for anonymous users)
- [ ] ETag / conditional requests (304 Not Modified for unchanged content)

## Monitoring and Analytics

- [ ] Page view tracking per route (most visited pages)
- [ ] Navigation timing (how long transitions between views take)
- [ ] Error tracking per route (which pages generate most errors)
- [ ] Dead link detection (links to non-existent routes)
- [ ] Route usage heatmap (most used application sections)

---

## Key Points

- **Entire state in URL** — if a user shares a URL with a colleague, the colleague must see the exact same view (filter, sorting, page, tab). Without this, users describe verbally "go to orders, filter by approved status, sort by date". This is daily frustration in enterprise environments.
- **Slug + permalink** — slug (`/products/red-shirt`) is nice for readability, but when a user renames the product, the URL changes and old links break. Solution: internal permalink (`/products/_/12345`) as stable fallback.
- **Dirty state guard** — user fills a form for 10 minutes, accidentally clicks a menu link and loses everything. A simple confirm dialog "You have unsaved changes" saves hours of work.
- **Modal and side panel routes** — modern UX pattern. User clicks a record in the list, detail opens in side panel, list remains visible. URL changes (`?detail=123`), so it's deep-linkable.
- **Code splitting per route** — in metadata-driven platforms with dozens of entities, the JS bundle is huge. Without lazy loading per route, the user waits to download code for modules they'll never use.
- **Redirect after login to original URL** — user clicks a shared link, gets redirected to login, after logging in must be returned to the original URL. Without `return_to` parameter they end up on the dashboard and have to find the link again.
- **API vs. UI routing separation** — API and UI have different needs (authentication, middleware, cache). Sharing the route stack leads to compromises on both sides.
