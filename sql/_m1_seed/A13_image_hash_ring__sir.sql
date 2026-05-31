-- Code: A13 | Source: sir | Predicate: Accounts 351-356 created Aug 5-6 in bulk; 6 accounts / 18 listings / 255 phone reveals. Sir's framing is by account-id range.
SELECT
    (SELECT COUNT(*) FROM nl_user_accounts  WHERE account_id BETWEEN 351 AND 356)                                                          AS fraud_accounts,
    (SELECT COUNT(*) FROM nl_listings       WHERE seller_account_id BETWEEN 351 AND 356)                                                   AS fraud_listings,
    (SELECT COUNT(*) FROM nl_listing_events e JOIN nl_listings l ON l.listing_id = e.listing_id
        WHERE l.seller_account_id BETWEEN 351 AND 356 AND e.event_type_code = 'PHN_REVEAL')                                                AS phone_reveals,
    (SELECT COUNT(*) FROM nl_user_accounts  WHERE account_id BETWEEN 351 AND 356)                                                          AS affected_rows;
