# Phase 1.5 — Supplier Catalog Design

**Date:** 2026-04-01
**Status:** Approved

## Overview

Scrape the full product catalogs from West Coast Seeds and Metchosin Farm into a local `supplier_products` table. This enables:

1. **Seed enrichment** — existing seeds link to a supplier product and show its care HTML on the detail page
2. **Faster seed entry** — when adding a new seed, pick from a pre-populated supplier catalog instead of entering everything manually

Both suppliers are Shopify stores with a public JSON API (`/products.json`), so no HTML scraping or JS rendering is needed.

---

## Suppliers

| Supplier | Base URL | Catalog endpoint |
|---|---|---|
| West Coast Seeds | `https://www.westcoastseeds.com` | `/products.json?limit=250` |
| Metchosin Farm | `https://metchosinfarm.ca` | `/products.json?limit=250` |

---

## Data Model

### New table: `supplier_products`

```sql
supplier_products
  id                  UUID primary key
  supplier            string        -- "west_coast_seeds" | "metchosin_farm"
  shopify_product_id  integer       -- Shopify numeric ID (used for upsert idempotency)
  handle              string        -- Shopify handle, used to construct product URL
  title               string
  product_type        string
  tags                string        -- comma-separated Shopify tags
  description_html    text          -- body_html from Shopify, rendered as-is in the UI
  url                 string        -- full product URL (base URL + /products/ + handle)
  scraped_at          utc_datetime
  inserted_at         timestamp
  updated_at          timestamp
```

### Seeds table change

Add one nullable foreign key:

```sql
seeds
  supplier_product_id  UUID references supplier_products (nullable)
```

---

## Elixir Structure

New context: `BackyardGarden.SupplierCatalog`

- `SupplierCatalog.SupplierProduct` — Ecto schema
- `SupplierCatalog.list_supplier_products/1` — accepts `%{supplier: _, search: _}` filter map
- `SupplierCatalog.upsert_supplier_product/1` — upsert keyed on `supplier` + `shopify_product_id`
- `SupplierCatalog.find_match_for_seed/1` — fuzzy match a seed name against supplier product titles

Scraper modules (called by Mix tasks, not exposed in the context):

- `SupplierCatalog.Scrapers.WestCoastSeeds`
- `SupplierCatalog.Scrapers.MetchosinFarm`

Each scraper handles pagination and returns a list of product maps ready for `upsert_supplier_product/1`.

---

## Mix Tasks

### `mix supplier.scrape`

Fetches the full paginated catalog from both suppliers via their Shopify JSON API. Upserts all products into `supplier_products`. Safe to re-run.

Output:
```
Scraping West Coast Seeds... 312 products upserted.
Scraping Metchosin Farm... 89 products upserted.
Done.
```

### `mix supplier.match`

Fuzzy-matches each seed's `name` against `supplier_products.title` using `String.jaro_distance/2`.

Matching rules:
- Score ≥ 0.90 → auto-link: sets `supplier_product_id` on the seed silently
- Score 0.75–0.89 → printed review list, no automatic update
- Score < 0.75 → skipped, seed stays unlinked

Output:
```
Auto-linked 38 seeds.

Review needed (run mix supplier.link to confirm):
  "Bush Beans - Mix"  →  "Bush Bean Mix"  (Metchosin Farm, 0.82)
  "Beets - Boro"      →  "Boro Beet"      (West Coast Seeds, 0.79)
  ...

Unmatched seeds (9): Calendula, Echinacea, ...
```

### `mix supplier.link <seed_id> <supplier_product_id>`

Manually sets `supplier_product_id` on a single seed. Used to confirm borderline matches from the review list.

---

## UI Changes

### Seed detail page (`/seeds/:id`)

When `seed.supplier_product_id` is set, render a "From the Supplier" section below the existing seed fields:

- Supplier product title as heading
- `description_html` rendered via Phoenix's `raw/1` (trusted source — our own scrape of known Shopify stores)
- "View on supplier site →" link (opens `supplier_product.url` in a new tab)

### Add seed form (Phase 2, designed now)

Optional supplier picker step added to the new seed form:

1. Choose supplier: West Coast Seeds / Metchosin Farm / None
2. If chosen: live search box filters `supplier_products` by title (LiveView, debounced)
3. Selecting a product pre-fills: `name`, `type`, `cycle` (from tags), and sets `supplier_product_id`
4. All fields remain editable before saving

---

## Future Considerations

- **Periodic catalog refresh:** An Oban job running `supplier.scrape` on a weekly schedule would keep the catalog current with new product listings. Upsert logic ensures existing seed links are preserved.
- **Auto-match on new seeds:** A follow-up Oban job could run `supplier.match` after each scrape to auto-link any seeds added since the last run.
- **Additional suppliers:** The scraper module pattern is designed to be extended. Any Shopify-based seed supplier can be added with a new scraper module and a row in the supplier enum.

---

## Implementation Phases

This becomes **Phase 1.5** in the plan, inserted between Phase 1 (Foundation) and Phase 2 (Garden & Planting Tracking).

| Task | Description |
|---|---|
| 1.5.1 | Migration: create `supplier_products` table |
| 1.5.2 | Migration: add `supplier_product_id` to `seeds` |
| 1.5.3 | `SupplierCatalog` context + `SupplierProduct` schema |
| 1.5.4 | Scraper modules for West Coast Seeds and Metchosin Farm |
| 1.5.5 | `mix supplier.scrape` Mix task |
| 1.5.6 | `mix supplier.match` Mix task |
| 1.5.7 | `mix supplier.link` Mix task |
| 1.5.8 | Seed detail page: render supplier `description_html` |
