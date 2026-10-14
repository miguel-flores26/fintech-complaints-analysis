"""
Filter the raw CFPB complaint file down to the project scope.
Keeps: complaints received 2021-01-01 onward, excluding credit reporting products.
Renames columns to snake_case for BigQuery and writes a Parquet file.
"""
import os
import duckdb

RAW = "data/raw/complaints.csv"
OUT_DIR = "data/processed"
OUT = f"{OUT_DIR}/complaints_2021plus.parquet"
os.makedirs(OUT_DIR, exist_ok=True)

con = duckdb.connect()
con.execute("SET preserve_insertion_order = false")  # lowers memory use

# Read every column as text first so odd values (e.g. masked ZIPs) don't break parsing
src = f"read_csv('{RAW}', header = true, all_varchar = true)"

raw_rows = con.execute(f"SELECT COUNT(*) FROM {src}").fetchone()[0]
print(f"Raw rows in file: {raw_rows:,}")

con.execute(f"""
CREATE TABLE filtered AS
SELECT
    TRY_CAST("Date received" AS DATE)        AS date_received,
    "Product"                                AS product,
    "Sub-product"                            AS sub_product,
    "Issue"                                  AS issue,
    "Sub-issue"                              AS sub_issue,
    "Company public response"                AS company_public_response,
    "Company"                                AS company,
    "State"                                  AS state,
    "ZIP code"                               AS zip_code,
    "Tags"                                   AS tags,
    "Submitted via"                          AS submitted_via,
    TRY_CAST("Date sent to company" AS DATE) AS date_sent_to_company,
    "Company response to consumer"           AS company_response,
    "Timely response?"                       AS timely_response,
    TRY_CAST("Complaint ID" AS BIGINT)       AS complaint_id
FROM {src}
WHERE TRY_CAST("Date received" AS DATE) >= DATE '2021-01-01'
  AND LOWER("Product") NOT LIKE 'credit reporting%'
""")

kept, min_d, max_d, ids, null_dates = con.execute("""
    SELECT COUNT(*), MIN(date_received), MAX(date_received),
           COUNT(DISTINCT complaint_id),
           COUNTIF(date_sent_to_company IS NULL)
    FROM filtered
""").fetchone()
print(f"Rows kept: {kept:,}  |  date range: {min_d} to {max_d}")
print(f"Distinct complaint IDs: {ids:,}  (should equal rows kept)")
print(f"Rows with missing 'date sent to company': {null_dates:,}")

print("\nComplaints by product and year:")
print(con.execute("""
    SELECT product, EXTRACT(YEAR FROM date_received) AS yr, COUNT(*) AS n
    FROM filtered
    GROUP BY product, yr
    ORDER BY product, yr
""").fetchdf().to_string(index=False))

con.execute(f"COPY filtered TO '{OUT}' (FORMAT PARQUET)")
print(f"\nWrote {OUT} ({os.path.getsize(OUT) / 1e6:.0f} MB)")