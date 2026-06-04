"""
Ember & Co — Mock Data Generator
Schema Works Demo Project 1
Generates 12 months of realistic D2C e-commerce data

Tables generated:
- customers.csv
- orders.csv
- ad_spend.csv
- fulfilment.csv

Run: python generate_mock_data.py
Output: ./data/ folder
"""

import csv
import os
import random
from datetime import datetime, timedelta
from collections import defaultdict

# ── Seed for reproducibility
random.seed(42)

# ── Config
START_DATE = datetime(2024, 1, 1)
END_DATE   = datetime(2024, 12, 31)

CHANNELS      = ["meta", "google", "tiktok", "organic", "email", "referral"]
PAID_CHANNELS = ["meta", "google", "tiktok"]

COUNTRIES      = ["GB", "US", "DE", "FR", "AU", "NL", "CA"]
COUNTRY_WEIGHTS = [0.35, 0.30, 0.10, 0.08, 0.07, 0.05, 0.05]

PRODUCT_CATEGORIES = ["tops", "bottoms", "outerwear", "accessories", "footwear"]
CATEGORY_WEIGHTS   = [0.30, 0.25, 0.20, 0.15, 0.10]

# Return rates by channel — Meta significantly higher (story hook)
RETURN_RATES = {
    "meta":     0.31,
    "google":   0.14,
    "tiktok":   0.22,
    "organic":  0.09,
    "email":    0.07,
    "referral": 0.08,
}

# Repeat purchase weights by channel
# Meta customers churn faster — fewer repeat orders
# Organic and email customers are most loyal
# Story: Meta looks ok at 30D but falls behind at 90D and 180D
REPEAT_ORDER_WEIGHTS = {
    "meta":     [0.75, 0.20, 0.05],  # 75% buy once — low loyalty
    "google":   [0.62, 0.27, 0.11],  # moderate loyalty
    "tiktok":   [0.72, 0.22, 0.06],  # similar to meta
    "organic":  [0.48, 0.36, 0.16],  # high loyalty — keeps coming back
    "email":    [0.43, 0.38, 0.19],  # highest loyalty channel
    "referral": [0.53, 0.32, 0.15],  # good loyalty via word of mouth
}

# Average order value by category (GBP)
AOV = {
    "tops":        45,
    "bottoms":     65,
    "outerwear":  120,
    "accessories": 35,
    "footwear":    90,
}

# Target CAC in January (GBP) — starting point per channel
BASE_CAC = {
    "meta":   85.0,
    "google": 65.0,
    "tiktok": 70.0,
}

# Monthly CAC inflation rate per channel
# Meta inflates fastest — creative fatigue + CPM increases
CAC_INFLATION = {
    "meta":   0.038,   # +3.8%/month → ~55% by Dec
    "google": 0.008,   # +0.8%/month → ~9% by Dec — very stable
    "tiktok": 0.018,   # +1.8%/month → ~23% by Dec — moderate
}

OUTPUT_DIR = "./data"


# ── Common Functions

def random_date(start: datetime, end: datetime) -> datetime:
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def weighted_choice(options, weights):
    r = random.random()
    cumulative = 0
    for opt, w in zip(options, weights):
        cumulative += w
        if r <= cumulative:
            return opt
    return options[-1]


def date_range(start: datetime, end: datetime):
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def get_month_key(dt: datetime) -> str:
    return dt.strftime("%Y-%m")


# ── 1. Ad Spend (generated first — drives everything else)

def generate_ad_spend() -> tuple[list[dict], dict]:
    """
    Generates daily ad spend per channel.
    Returns spend_rows for CSV and monthly_spend dict
    used to derive customer counts.

    Story baked in:
    - Meta spend grows fastest (+3.5%/month drift)
    - Google stable (+0.5%/month)
    - TikTok moderate (+2%/month)
    - Q4 seasonal spike x1.6 across all channels
    """
    spend_rows    = []
    monthly_spend = defaultdict(lambda: defaultdict(float))

    base_spend = {
        "meta":   320.0,
        "google": 180.0,
        "tiktok": 120.0,
    }

    for day in date_range(START_DATE, END_DATE):
        month_index = day.month - 1
        month_key   = get_month_key(day)

        for channel, base in base_spend.items():
            # Seasonal multiplier
            seasonal = 1.0
            if day.month in (11, 12):
                seasonal = 1.6
            elif day.month in (6, 7):
                seasonal = 1.2

            # Spend drift per channel
            if channel == "meta":
                drift = 1 + (month_index * 0.035)
            elif channel == "tiktok":
                drift = 1 + (month_index * 0.020)
            else:
                drift = 1 + (month_index * 0.005)

            daily_spend = round(
                base * seasonal * drift * random.uniform(0.85, 1.15), 2
            )

            # Impressions and clicks — CTR degrades over time
            cpm_base    = {"meta": 8.5, "google": 12.0, "tiktok": 5.0}[channel]
            cpm         = cpm_base * (1 + month_index * 0.02)
            impressions = int((daily_spend / cpm) * 1000)
            ctr         = {"meta": 0.018, "google": 0.035, "tiktok": 0.022}[channel]
            ctr_adj     = ctr * (1 - month_index * 0.008)
            clicks      = int(impressions * max(ctr_adj, 0.008))

            spend_rows.append({
                "date":        day.strftime("%Y-%m-%d"),
                "channel":     channel,
                "spend_gbp":   daily_spend,
                "impressions": impressions,
                "clicks":      clicks,
            })

            monthly_spend[month_key][channel] += daily_spend

    return spend_rows, monthly_spend


# ── 2. Customers (derived from ad spend via target CAC)

def generate_customers(monthly_spend: dict) -> tuple[list[dict], dict]:
    """
    Derives number of paid customers acquired each month from:
        new_customers = monthly_spend / target_CAC

    Target CAC inflates each month per channel — baking in
    the CAC inflation story mathematically.

    Organic, email, and referral customers added on top
    as a proportion of paid volume.
    """
    customers              = []
    paid_customers_by_month = defaultdict(lambda: defaultdict(list))
    customer_id            = 1

    for month_key, channel_spend in sorted(monthly_spend.items()):
        month_dt    = datetime.strptime(month_key, "%Y-%m")
        month_index = month_dt.month - 1
        month_end   = (
            (month_dt.replace(day=28) + timedelta(days=4)).replace(day=1)
            - timedelta(days=1)
        )
        month_end = min(month_end, END_DATE - timedelta(days=1))

        for channel in PAID_CHANNELS:
            total_spend = channel_spend.get(channel, 0)

            # CAC inflates compounding each month
            target_cac  = BASE_CAC[channel] * (
                (1 + CAC_INFLATION[channel]) ** month_index
            )

            # New customers = spend / CAC with small noise
            n_customers = max(
                1, int(total_spend / target_cac * random.uniform(0.92, 1.08))
            )

            for _ in range(n_customers):
                cust_id  = f"CUST{customer_id:05d}"
                acq_date = random_date(month_dt, month_end)
                country  = weighted_choice(COUNTRIES, COUNTRY_WEIGHTS)

                customers.append({
                    "customer_id":           cust_id,
                    "acquisition_channel":   channel,
                    "acquisition_date":      acq_date.strftime("%Y-%m-%d"),
                    "country":               country,
                    "email_subscribed":      random.choice(
                                                [True, True, True, False]
                                             ),
                })

                paid_customers_by_month[month_key][channel].append({
                    "customer_id":    cust_id,
                    "acquisition_date": acq_date,
                    "country":        country,
                })

                customer_id += 1

        # Organic, email, referral — proportional to paid volume
        total_paid = sum(
            len(paid_customers_by_month[month_key][ch])
            for ch in PAID_CHANNELS
        )
        organic_n  = max(1, int(total_paid * random.uniform(0.20, 0.30)))
        email_n    = max(1, int(total_paid * random.uniform(0.08, 0.14)))
        referral_n = max(1, int(total_paid * random.uniform(0.03, 0.06)))

        for channel, n in [
            ("organic",  organic_n),
            ("email",    email_n),
            ("referral", referral_n),
        ]:
            for _ in range(n):
                cust_id  = f"CUST{customer_id:05d}"
                acq_date = random_date(month_dt, month_end)
                country  = weighted_choice(COUNTRIES, COUNTRY_WEIGHTS)

                customers.append({
                    "customer_id":           cust_id,
                    "acquisition_channel":   channel,
                    "acquisition_date":      acq_date.strftime("%Y-%m-%d"),
                    "country":               country,
                    "email_subscribed":      random.choice(
                                                [True, True, True, False]
                                             ),
                })
                customer_id += 1

    return customers, paid_customers_by_month


# ── 3. Orders (derived from customers)

def generate_orders(customers: list[dict]) -> list[dict]:
    """
    Generates orders for each customer.

    Key story baked in:
    - Meta first order return rate halved (15%) — first purchase is considered
    - Meta repeat order return rate stays high (31%) — impulse returns on repeat buys
    - Meta customers churn faster (75% single purchase) — low loyalty
    - Organic and email customers are loyal (50%+ repeat buyers)
    - Result: Meta LTV looks competitive at 30D but falls behind at 90D and 180D
    - Meta and TikTok receive heavier discounts (45% of orders)
    """
    orders   = []
    order_id = 1

    for customer in customers:
        acq_date = datetime.strptime(
            customer["acquisition_date"], "%Y-%m-%d"
        )
        channel = customer["acquisition_channel"]

        # Channel-specific repeat purchase rate
        n_orders = random.choices(
            [1, 2, 3],
            weights=REPEAT_ORDER_WEIGHTS.get(channel, [0.65, 0.25, 0.10])
        )[0]

        for order_num in range(n_orders):

            # ── Order date logic
            if order_num == 0:
                # First purchase within 14 days of acquisition
                max_first_order = min(
                    acq_date + timedelta(days=14), END_DATE
                )
                if max_first_order <= acq_date:
                    order_date = acq_date
                else:
                    order_date = random_date(acq_date, max_first_order)
            else:
                # Repeat purchases spread across remaining year
                repeat_start = acq_date + timedelta(days=15)
                if repeat_start >= END_DATE:
                    break  # No room for repeat orders — skip
                order_date = random_date(repeat_start, END_DATE)

            # ── Category and revenue
            # Channel-specific AOV multiplier — organic/email buyers spend more
            # Meta/TikTok are impulse buyers — lower basket size
            AOV_MULTIPLIER = {
                "meta":     0.85,
                "google":   1.00,
                "tiktok":   0.80,
                "organic":  1.15,
                "email":    1.20,
                "referral": 1.10,
            }
            category = weighted_choice(PRODUCT_CATEGORIES, CATEGORY_WEIGHTS)
            base_aov = AOV[category]
            revenue  = round(
                base_aov * AOV_MULTIPLIER.get(channel, 1.0) * random.uniform(0.8, 1.6),
                2
            )

            # ── Return logic — full channel return rate on all orders
            is_returned = random.random() < RETURN_RATES[channel]

            # ── Discount — heavier on Meta and TikTok
            discount = 0.0
            if channel in ("meta", "tiktok") and random.random() < 0.45:
                discount = round(revenue * random.uniform(0.10, 0.25), 2)

            # ── Net revenue
            net_revenue = round(
                revenue - discount - (revenue * 0.85 if is_returned else 0),
                2,
            )

            orders.append({
                "order_id":      f"ORD{order_id:06d}",
                "customer_id":   customer["customer_id"],
                "order_date":    order_date.strftime("%Y-%m-%d"),
                "channel":       channel,
                "category":      category,
                "country":       customer["country"],
                "gross_revenue": revenue,
                "discount":      discount,
                "net_revenue":   net_revenue,
                "returned":      is_returned,
                "status":        "returned" if is_returned else "completed",
            })
            order_id += 1

    return orders


# ── 4. Fulfilment

def generate_fulfilment(orders: list[dict]) -> list[dict]:
    fulfilment_rows = []

    for order in orders:
        order_date   = datetime.strptime(order["order_date"], "%Y-%m-%d")
        shipped_at   = order_date + timedelta(days=random.randint(1, 3))
        delivered_at = shipped_at + timedelta(days=random.randint(2, 7))

        return_requested_at = None
        return_completed_at = None

        if order["returned"]:
            return_requested_at = delivered_at + timedelta(
                days=random.randint(3, 21)
            )
            return_completed_at = return_requested_at + timedelta(
                days=random.randint(5, 14)
            )

        fulfilment_rows.append({
            "order_id":            order["order_id"],
            "shipped_at":          shipped_at.strftime("%Y-%m-%d"),
            "delivered_at":        delivered_at.strftime("%Y-%m-%d"),
            "return_requested_at": (
                return_requested_at.strftime("%Y-%m-%d")
                if return_requested_at else None
            ),
            "return_completed_at": (
                return_completed_at.strftime("%Y-%m-%d")
                if return_completed_at else None
            ),
            "fulfilment_status":   "returned" if order["returned"] else "delivered",
        })

    return fulfilment_rows


# ── Write CSVs

def write_csv(filename: str, rows: list[dict]):
    if not rows:
        print(f"  ⚠ No data for {filename}")
        return
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"  ✓ {filename} — {len(rows):,} rows written to {filepath}")


# ── Main

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("\n🔧 Ember & Co — Mock Data Generator")
    print("=" * 45)

    print("\n[1/4] Generating ad spend...")
    ad_spend, monthly_spend = generate_ad_spend()
    write_csv("ad_spend.csv", ad_spend)

    print("\n[2/4] Generating customers from spend + target CAC...")
    customers, _ = generate_customers(monthly_spend)
    write_csv("customers.csv", customers)

    print("\n[3/4] Generating orders from customers...")
    orders = generate_orders(customers)
    write_csv("orders.csv", orders)

    print("\n[4/4] Generating fulfilment records...")
    fulfilment = generate_fulfilment(orders)
    write_csv("fulfilment.csv", fulfilment)

    print("\n✅ All done. Files saved to ./data/")
    print("\nKey story in the data:")
    print("  • Meta CAC inflates ~55% Jan → Dec (spend up, efficiency down)")
    print("  • Google CAC nearly flat — most efficient paid channel")
    print("  • TikTok CAC inflates ~23% — moderate degradation")
    print("  • Meta return rate ~31% vs organic ~9% — net revenue gap")
    print("  • Meta customers churn faster — LTV falls behind at 90D and 180D")
    print("  • Organic and email customers most loyal — highest long-term LTV")
    print("  • Q4 spend spike across all channels")
    print("\nNext step: Load CSVs into Snowflake RAW schema.\n")


if __name__ == "__main__":
    main()