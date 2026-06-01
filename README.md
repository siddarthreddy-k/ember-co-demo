# Ember & Co — D2C Data Infrastructure Demo

> A end-to-end data pipeline built by [Schema Works](https://schemaworks.io) demonstrating how a D2C apparel brand can go from fragmented, siloed data to a single source of truth — with real-time visibility into CAC, revenue, returns, and customer LTV.

---

## The Problem This Solves

Most D2C brands run their reporting across 4–6 disconnected tools — Shopify, Meta Ads Manager, Google Ads, a fulfilment platform, and a spreadsheet someone built 18 months ago. The result:

- CAC figures that don't account for returns or discounts
- Campaigns that run for weeks before anyone notices they're underwater
- A reporting model that lives in one person's head and breaks when they leave

**Ember & Co** is a fictional D2C apparel brand used to demonstrate exactly what Schema Works builds for real clients — a clean, automated data pipeline that surfaces the insights that matter, in real time.

---

## What This Project Demonstrates

| Capability | Detail |
|---|---|
| **Data ingestion** | Python scripts loading raw CSVs into Snowflake |
| **Data modelling** | Staging and mart layers built in SQL |
| **CAC analysis** | Blended CAC across Meta, Google, and TikTok with month-on-month trend |
| **Revenue reporting** | Gross vs net revenue after returns and discounts, by channel |
| **LTV cohorts** | Customer cohorts by acquisition month — cumulative revenue at 30/60/90 days |
| **Live dashboard** | Looker Studio connected directly to Snowflake |

---

## Key Insight in the Data

The Ember & Co dataset is designed to tell a real story:

- **Meta return rate is 31%** vs 9% for organic — Meta-acquired customers look great on gross revenue but erode margin significantly on a net basis
- **Meta CAC inflates ~40% from January to December** — the channel is getting more expensive while the quality of customers it delivers is declining
- **TikTok ROAS degrades from Q3 onwards** — early traction doesn't hold as spend scales
- **One customer cohort that looked like the best performer by order volume is actually the least profitable** once returns and fulfilment costs are factored in

These are the exact blind spots that manual spreadsheet reporting misses — and what a properly built data warehouse surfaces automatically.

---

## Stack

```
Raw Data (CSV)
    └── Python ingestion scripts
            └── Snowflake (RAW → STAGING → MARTS)
                    └── Looker Studio Dashboard
```

| Layer | Tool |
|---|---|
| Data generation | Python (standard library) |
| Data warehouse | Snowflake |
| Transformation | SQL (staging + mart models) |
| Visualisation | Looker Studio |
| Version control | GitHub |

---

## Repo Structure

```
ember-co-demo/
├── data/                   # Generated mock CSVs (12 months, ~10k rows)
│   ├── customers.csv
│   ├── orders.csv
│   ├── ad_spend.csv
│   └── fulfilment.csv
│
├── pipeline/               # Python ingestion scripts
│   ├── generate_mock_data.py   # Generates all mock CSVs
│   └── load_to_snowflake.py    # Loads CSVs into Snowflake RAW schema
│
├── sql/                    # Snowflake SQL models
│   ├── staging/
│   │   ├── stg_orders.sql
│   │   ├── stg_customers.sql
│   │   ├── stg_ad_spend.sql
│   │   └── stg_fulfilment.sql
│   └── marts/
│       ├── mart_cac.sql
│       ├── mart_revenue.sql
│       └── mart_ltv_cohorts.sql
│
├── dashboard/              # Looker Studio screenshots and share link
│   └── README.md
│
└── README.md
```

---

## How to Run It Locally

### 1. Generate mock data

```bash
python pipeline/generate_mock_data.py
```

This writes four CSVs into the `./data/` folder — 3,800 customers, 5,200 orders, 365 days of ad spend, and fulfilment records for every order.

### 2. Load into Snowflake

Set your Snowflake credentials as environment variables:

```bash
export SNOWFLAKE_ACCOUNT=your_account
export SNOWFLAKE_USER=your_user
export SNOWFLAKE_PASSWORD=your_password
export SNOWFLAKE_WAREHOUSE=your_warehouse
```

Then run:

```bash
python pipeline/load_to_snowflake.py
```

This creates the `EMBER_CO_DW` database with `RAW`, `STAGING`, and `MARTS` schemas and loads all raw tables.

### 3. Run SQL models

Execute the SQL files in order:

```
sql/staging/  → run all stg_ files first
sql/marts/    → run all mart_ files after
```

### 4. Connect Looker Studio

Connect Looker Studio to Snowflake using the native connector, pointing at the `MARTS` schema in `EMBER_CO_DW`. The mart tables are pre-modelled for direct use as Looker Studio data sources.

---

## Live Dashboard

🔗 [View the Ember & Co Looker Studio Dashboard](https://datastudio.google.com/reporting/e99f36ac-a4b3-4f94-848d-a989f78d3d6a) ← *link added after build*

![Dashboard Preview](dashboard/preview.png) ← *screenshot added after build*

---

## About Schema Works

[Schema Works](https://schemaworks.io) builds data infrastructure for D2C and e-commerce brands in the US, UK, and EU — automated pipelines, Snowflake warehouses, and multi-channel dashboards, built and kept running on retainer.

If you're a D2C founder and your reporting still lives in spreadsheets, [book a free 30-minute data audit](https://calendly.com/siddarth-reddy-schemaworks) — no pitch, just clarity on where your biggest blind spots are.

---

*Built by [Siddarth Reddy Katangur](https://github.com/siddarthreddy-k) · Founder, Schema Works*