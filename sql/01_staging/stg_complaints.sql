-- Staging: in-scope complaints joined to analysis themes.
-- Source: cfpb.complaints_raw (CFPB download, Oct 14 2026, filtered to 2021+)
-- Scope: checking/savings, money transfer, prepaid card (incl. prepaid sub-products
--        of the pre-Aug-2023 "Credit card or prepaid card" product).

CREATE OR REPLACE TABLE `cfpb.stg_complaints` AS
WITH scoped AS (
  SELECT
    *,
    CASE
      WHEN product = 'Checking or savings account' THEN 'checking_savings'
      WHEN product = 'Money transfer, virtual currency, or money service' THEN 'money_transfer'
      WHEN product = 'Prepaid card' THEN 'prepaid'
      WHEN product = 'Credit card or prepaid card'
       AND sub_product IN ('General-purpose prepaid card', 'Government benefit card',
                           'Gift card', 'Payroll card', 'Student prepaid card')
        THEN 'prepaid'
    END AS product_group
  FROM `cfpb.complaints_raw`
)
SELECT
  s.complaint_id,
  s.date_received,
  DATE_TRUNC(s.date_received, MONTH)  AS month_received,
  EXTRACT(YEAR FROM s.date_received)  AS year_received,
  EXTRACT(YEAR FROM s.date_received) = 2026 AS is_partial_year,
  s.product_group,
  s.product,
  s.sub_product,
  s.issue,
  s.sub_issue,
  COALESCE(m.theme, 'unmapped')            AS theme,
  COALESCE(m.fraud_definition, 'none')     AS fraud_definition,
  TRIM(s.company)                          AS company,
  s.state,
  s.submitted_via,
  s.tags,
  s.company_response,
  s.company_response <> 'In progress'      AS is_closed,
  s.company_response IN ('Closed with monetary relief',
                         'Closed with non-monetary relief') AS is_relief,
  DATE_DIFF(s.date_sent_to_company, s.date_received, DAY) AS days_to_company
FROM scoped AS s
LEFT JOIN `cfpb.issue_theme_map` AS m
  ON  m.product_group = s.product_group
  AND COALESCE(m.issue, '')     = COALESCE(s.issue, '')
  AND COALESCE(m.sub_issue, '') = COALESCE(s.sub_issue, '')
WHERE s.product_group IS NOT NULL;