# API contract: frontend ↔ backend

Implemented in `app/main.py`. Rules are in `app/analytics.py`. `tests/test_api.py` checks the API returns
exactly what the sample files hold. The dashboard needs these five endpoints. The sample files in `frontend/sample/` follow these
shapes exactly, so if the API returns the same JSON the frontend switches over with no code changes.

To regenerate the sample files: `python3 scripts/build_sample_data.py`.
The page uses the API by default. Open it with `?mode=sample` to use the files instead.

All endpoints are `GET` unless marked, return JSON, and are served from the same origin as the page.
On any error, return a non-2xx status. The page shows the status and message on screen.

## Issue types

`too_small`, `too_large`, `colour_mismatch`, `quality`, `damaged`, `wrong_item`, `changed_mind`,
`delivery_late`, `unclear`, `failed`. These match `classified_returns.issue_type`.

## `GET /api/summary`

Everything above the trend chart. Scope: the current 12-month window (`meta.window`).

```jsonc
{
  "meta": {
    "data_mode": "live",            // "sample" in the sample files
    "synthetic": true,              // true while the database holds synthetic data → shows the "Test data" banner
    "generated_at": "2026-10-03T09:20:00+00:00",
    "window": { "from": "2025-10-01", "to": "2026-09-30", "label": "Oct 2025 – Sep 2026" },
    "confidence_threshold": 0.7,    // from settings
    "min_returns_per_hotspot": 20,  // from settings
    "classifier_note": null,        // optional one-liner shown in the banner
    "corrections_storage": "permanent"  // "temporary" on SQLite: the page says marks last until a restart
  },
  "headline": {
    "returns": 3675,
    "known_reason_before": 0.553,   // share with a dropdown reason other than "Other"
    "known_reason_after": 0.863,    // share whose issue_type is not unclear/failed
    "other_comments": 1643,         // returns whose dropdown was "Other"
    "unclear": 476,
    "failed": 28
  },
  "drivers": [                      // one row per issue type, including unclear and failed (count may be 0)
    { "issue": "too_small", "label": "Too small", "count": 880, "share": 0.2395 }
  ],
  "hotspots": [                     // already ranked, most important first
    {
      "id": "V07|Kurti",
      "vendor_id": "V07", "vendor_name": "Rangrez Studio",
      "subcategory": "Kurti",
      "size": "L, M",               // or "All sizes"
      "size_breakdown": { "L": 30, "M": 24 },   // counts of the top issue by size (shown on hover)
      "returns": 172,
      "top_issue": "too_small", "top_issue_label": "Too small",
      "top_issue_count": 103, "top_issue_share": 0.5988,
      "baseline_share": 0.2395,     // share of this issue across all returns
      "unclear_or_failed": 20
    }
  ],
  "locations": [                    // already ranked
    {
      "city": "Guwahati", "state": "Assam", "returns": 118,
      "top_issue": "damaged", "top_issue_label": "Damaged",
      "top_issue_count": 18, "top_issue_share": 0.1525, "baseline_share": 0.0656
    }
  ]
}
```

These are the rules the sample builder uses. Copy them, or change them and tell the frontend owner:

- **Hotspot** = vendor × product type with at least `min_returns_per_hotspot` returns. Its top issue is
  the one most over-represented against `baseline_share`. It is listed only when that issue is at least
  5 points above baseline. `size` names the top one or two sizes when they hold at least half of the top
  issue's returns *and* there are at least 20 of them; otherwise it's `"All sizes"`.
- **Location** = city with at least 40 returns. It gets the same "most over-represented" and "at least
  5 points above baseline" tests.
- **Shares** use all of the group's returns as the denominator, including unclear and failed.

## `GET /api/trend?issue=too_small`

```jsonc
{
  "issue": "too_small", "label": "Too small",
  "months": ["Oct", "Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep"],
  "series": [
    { "key": "last_year", "label": "Oct 2024 – Sep 2025", "counts": [59, 77, 59, 59, 52, 65, 54, 35, 63, 53, 53, 47] },
    { "key": "this_year", "label": "Oct 2025 – Sep 2026", "counts": [95, 83, 71, 63, 57, 88, 75, 71, 63, 84, 75, 55] }
  ]
}
```

Both `key`s are required. Each `counts` array has exactly 12 numbers, aligned with `months`.

## `GET /api/returns?vendor_id=&subcategory=&city=&issue_type=`

The rows behind a hotspot, a city, or the unclear/failed views. Every filter is optional, and they
combine with AND. Scope: the same window as the summary.

```jsonc
{
  "total": 172,
  "returns": [
    {
      "return_id": "RT000139", "return_date": "2026-06-16",
      "sku": "DH-KUR-00012", "product_name": "Office Wear Kurti",
      "subcategory": "Kurti", "department": "Womenswear",
      "vendor_id": "V07", "vendor_name": "Rangrez Studio",
      "size": "XL", "city": "Hubballi", "state": "Karnataka",
      "reason_dropdown": "Other",
      "comment": "SIZE M BAHUT TIGHT HAI, L LENA PADEGA",   // null when the dropdown was used
      "issue_type": "too_small",
      "confidence": 0.86,           // null for gate/failed
      "evidence_phrase": "tight",   // highlighted in the comment; must be a substring of it, or null
      "source": "cheap_model",      // dropdown | gate | cheap_model | strong_model (sample_stub* or pipeline before/without the pipeline)
      "model_name": "…",
      "error": null                 // short reason when issue_type = "failed", shown on screen
    }
  ]
}
```

The ✓ / ✗ buttons appear on every row except `source = "dropdown"` and `issue_type = "failed"`.

## `GET /api/corrections`

```jsonc
{
  "corrections": { "RT000139": { "is_correct": true, "corrected_issue": null } },
  "accuracy": { "reviewed": 2, "correct": 1 }
}
```

`accuracy` counts the latest mark per `return_id`.

## `POST /api/corrections`

Body:

```json
{ "return_id": "RT000556", "model_issue_type": "too_small", "is_correct": false, "corrected_issue": "too_large" }
```

`corrected_issue` is optional (null). Neha may send the same `return_id` again to change her mark, and
the latest one wins. Response:

```json
{ "ok": true, "accuracy": { "reviewed": 2, "correct": 1 } }
```

Write to the `corrections` table. Neha's id is `corrected_by` = `'neha'` (the table default) until there's a login.

## `GET /health`

Used by the deploy workflow and the keep-alive ping. Returns 200 with `status: "ok"`, the table counts,
`labels_from` (`sample_stub` or `pipeline`), `corrections_storage` and `build` (the deployed commit). Returns
503 with an `error` sentence when the data can't be served.
