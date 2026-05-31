-- Code: A12 | Source: team | Predicate: Strict detection beyond the relist_count metadata field — same seller_account_id + same image_hash + earlier listing status SOLD/EXPIRED + later listing ACTIVE.
-- Returns three figures: (a) explicit relist_count > 0 = 1, (b) image-hash strict join within 30-day window = 3, (c) image-hash strict join unbounded = 3. (30d and unbounded match because the cluster is tight in August. Earlier docs/this comment said "2 in 30d" — confirmed off-by-one on 2026-05-25.)
WITH sold AS (
    SELECT listing_id, seller_account_id, image_hash, updated_at AS sold_ts
    FROM nl_listings
    WHERE status_code IN ('SOLD', 'EXPIRED')
      AND image_hash IS NOT NULL
),
relist AS (
    SELECT listing_id, seller_account_id, image_hash, created_at AS relist_ts
    FROM nl_listings
    WHERE status_code = 'ACTIVE'
      AND image_hash IS NOT NULL
)
SELECT
    (SELECT COUNT(*) FROM nl_listings WHERE relist_count > 0)              AS metadata_relist_count,
    (SELECT COUNT(*) FROM sold s JOIN relist r
        ON r.seller_account_id = s.seller_account_id
       AND r.image_hash = s.image_hash
       AND r.listing_id <> s.listing_id
       AND r.relist_ts > s.sold_ts
       AND julianday(r.relist_ts) - julianday(s.sold_ts) <= 30)            AS strict_image_hash_30d,
    (SELECT COUNT(*) FROM sold s JOIN relist r
        ON r.seller_account_id = s.seller_account_id
       AND r.image_hash = s.image_hash
       AND r.listing_id <> s.listing_id
       AND r.relist_ts > s.sold_ts)                                        AS strict_image_hash_unbounded,
    (SELECT COUNT(*) FROM nl_listings WHERE relist_count > 0)              AS affected_rows;
