# Shopping Backends

Load this file only when you need backend-specific filters.

## Meta Catalog Search

Base command:

```sh
CATALOG_RESULTS_JSON=$(mktemp "${TMPDIR:-/tmp}/meta-catalog-search.XXXXXX")
meta-catalog-search --query "<q1>" --query "<q2>" -n <N> --out "$CATALOG_RESULTS_JSON"
```

Useful flags:
- `--category`, `--gender` for hard constraints
- `--brand` for brand or retailer/domain matching; verify results because backend matching is boosted, not guaranteed
- `--currency` with `--min-price` / `--max-price` (values are cents)
- `--color`, `--material`, `--style`, `--prefer-brand` for soft preferences
The tool prints metadata-only summary output; product details live in the JSON file written with `--out`. Use `jq` to scan and filter the JSON file instead of reading the full file at once:

```sh
# Count products without reading every product
jq '.count' "$CATALOG_RESULTS_JSON"

# Preview the first five products with display fields only
jq '.products[0:5] | map({rank, name, brand, price, sale_price, url, image_url})' "$CATALOG_RESULTS_JSON"

# Stream matching-brand products with display fields only
jq '.products[] | select((.brand // "") == "<brand>") | {rank, name, price, url, image_url}' "$CATALOG_RESULTS_JSON"
```

## Facebook Marketplace

Use for local, secondhand, pickup, strict-budget, and deal-hunting requests.

Base search flow:

```sh
MARKETPLACE_RESULTS_JSON=$(mktemp "${TMPDIR:-/tmp}/facebook-marketplace-search.XXXXXX")

facebook-cli marketplace search --query "<item>" --limit <N> > "$MARKETPLACE_RESULTS_JSON"
```

Useful flags:
- `--max-price`, `--min-price` in dollars
- `--latitude` and `--longitude="<lng>"` together for location search; quote negative coordinates with `=`
- `--radius-in-miles` for local distance
- `--sort-by best_match|price_ascend|price_descend|creation_time_descend|distance_ascend`
- `--allowed-item-conditions new,refurbished,used` for condition filtering
- `--delivery-method local_pickup_only|shipping_only|pickup_and_shipping`
- `--max-listing-age-in-days` for recency
- `--limit <N>` for page size (default and max 20; higher values are capped)
- `--after <cursor>` to continue a search — pass the `paging.cursors.after` value from the previous response (absent `paging` means no more results)

Inspect search results and present selected `listing_id` values:

```sh
jq '
  [
    .data[]
    | select((.listing_id // "") != "" and (.title // "") != "" and (.product_url // "") != "" and (.image_url // "") != "")
    | {listing_id, title, description, price, condition, location, distance, product_url, image_url}
  ][0:50]
' "$MARKETPLACE_RESULTS_JSON"

Call `shopping.resolve_results`:

```json
{
  "result_paths": ["<MARKETPLACE_RESULTS_JSON>"],
  "selected_ids": ["listing-id-1", "listing-id-2"]
}
```

The resolver maps Marketplace `listing_id` values into shopping result cards.
Present the returned `path` with `widget.create` using
`kind: "shopping_results"` and `data.path`.

To present catalog and Marketplace picks together:

```json
{
  "result_paths": ["<CATALOG_RESULTS_JSON>", "<MARKETPLACE_RESULTS_JSON>"],
  "selected_ids": ["catalog-id-1", "listing-id-1"]
}
```

Present the returned `path` with `widget.create` using
`kind: "shopping_results"` and `data.path`.
