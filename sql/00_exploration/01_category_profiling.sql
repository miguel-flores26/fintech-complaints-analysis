-- Exploration queries used to design the product scope and issue-theme mapping.
-- Run against the project's own table `cfpb.complaints_raw` (loaded Oct 2026).

-- 1. Row count and date range after loading
SELECT COUNT(*) AS n, MIN(date_received) AS first_date, MAX(date_received) AS last_date
FROM `cfpb.complaints_raw`;

-- 2. Sub-products in the card products (shows the Aug 2023 split of
--    "Credit card or prepaid card" into separate products)
SELECT product, sub_product, COUNT(*) AS n,
       MIN(date_received) AS first_seen, MAX(date_received) AS last_seen
FROM `cfpb.complaints_raw`
WHERE product IN ('Credit card or prepaid card', 'Prepaid card')
GROUP BY product, sub_product
ORDER BY product, n DESC;

-- 3. Issue / sub-issue combinations in scope (input to seeds/issue_theme_map.csv)
SELECT product, issue, sub_issue, COUNT(*) AS n,
       MIN(date_received) AS first_seen, MAX(date_received) AS last_seen
FROM `cfpb.complaints_raw`
WHERE product IN ('Checking or savings account',
                  'Money transfer, virtual currency, or money service',
                  'Prepaid card')
   OR (product = 'Credit card or prepaid card'
       AND sub_product IN ('General-purpose prepaid card', 'Government benefit card',
                           'Gift card', 'Payroll card', 'Student prepaid card'))
GROUP BY product, issue, sub_issue
ORDER BY product, n DESC;