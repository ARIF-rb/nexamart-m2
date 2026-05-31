-- Code: A13 | Source: team | Predicate: Detection by reused image_hash (not by account-id range) — three rings: bb3c1fe6f8208d59f5bd (5 sellers/8 listings), acebc25ee9506c71a8fe (4/5), 76537d72e075b201aa1d (4/5). Ours surfaces the *detection criterion*, sir's number is the *consequence count*.
SELECT image_hash,
       COUNT(DISTINCT seller_account_id) AS distinct_sellers,
       COUNT(*)                          AS listing_count
FROM nl_listings
WHERE image_hash IS NOT NULL
GROUP BY image_hash
HAVING COUNT(DISTINCT seller_account_id) >= 2
ORDER BY distinct_sellers DESC, listing_count DESC;
-- The detection contract yields 3 rings; the affected scope (6 accounts/18 listings/255 reveals) matches sir verbatim.
