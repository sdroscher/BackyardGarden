# Brother Nature Supplier Scraper — Design

**Date:** 2026-04-16
**Branch:** brother-nature

## Overview

Add brothernature.ca as a third supplier in the BackyardGarden supplier catalog. The site runs on Shopify, so the scraper follows the same pattern as `WestCoastSeeds` and `MetchosinFarm`, with the addition of per-product care HTML scraping.

## Site Profile

- **URL:** https://brothernature.ca
- **Platform:** Shopify (public `/products.json` API available)
- **Catalog size:** ~290 products across 2 pages (limit=250)
- **Product types:** Annual, Vegetable, Herb, Perennial, Salad Greens, Tomatoes, Fruit, Gift Cards, and blank — all are seeds except Gift Cards and blank

## New File

`lib/backyard_garden/supplier_catalog/scrapers/brother_nature.ex`

### Constants

```
@supplier "brother_nature"
@base_url "https://brothernature.ca"
```

### Public API

- `fetch_all_products/0` — paginates `/products.json?limit=250&page=N`, stops on empty page; filters out products with blank or `"Gift Cards"` product type; fetches care HTML per product via `Task.async_stream` at `max_concurrency: 2`
- `fetch_product/1` — fetches a single product by handle (for manual/admin use), includes care HTML

### Care HTML Scraping

`fetch_care_html/1` GETs `#{@base_url}/products/#{handle}`, parses with Floki, finds all `div.seed-details` elements, and joins their raw HTML. Returns `nil` if none found. Both "Seed Details" and "Instructions" sections on product pages use this class.

### Rate Limiting

- 3s `Process.sleep` between paginated pages
- `max_concurrency: 2` on per-product async fetches
- Same Chrome browser headers as existing scrapers (`sec-ch-ua`, `sec-fetch-*`, etc.)

### `to_attrs/1` shape

```elixir
%{
  supplier: "brother_nature",
  shopify_product_id: product["id"],
  handle: product["handle"],
  title: product["title"],
  product_type: product["product_type"],
  tags: normalize_tags(product["tags"]),
  description_html: product["body_html"],
  url: "#{@base_url}/products/#{product["handle"]}",
  care_html: <scraped from product page>,
  scraped_at: DateTime.utc_now() |> DateTime.truncate(:second)
}
```

## Registration

Add `"brother_nature"` to the scraper dispatch in `BackyardGarden.SupplierCatalog` (wherever `"west_coast_seeds"` and `"metchosin_farm"` are mapped to their modules).

## Out of Scope

- No variant/price tracking (consistent with existing scrapers)
- No image scraping
