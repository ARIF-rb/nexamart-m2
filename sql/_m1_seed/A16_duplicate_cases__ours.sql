-- Code: A16 | Source: team | Predicate: Identical — 7 cases flagged is_duplicate_flag=1 collapsing onto 6 distinct canonical_case_ref values.
SELECT
    COUNT(*)                                  AS affected_rows,
    COUNT(DISTINCT canonical_case_ref)        AS distinct_canonical_refs
FROM cs_cases
WHERE is_duplicate_flag = 1;
