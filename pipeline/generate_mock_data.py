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

# ── Seed for reproducibility 
random.seed(42)

# ── Config 
START_DATE = datetime(2024, 1, 1)
END_DATE   = datetime(2024, 12, 31)
NUM_CUSTOMERS = 3800
NUM_ORDERS    = 5200

CHANNELS = ["meta", "google", "tiktok", "organic", "email", "referral"]

# Acquisition channel weights — Meta dominant early, shifts over time
ACQ_CHANNEL_WEIGHTS = [0.40, 0.20, 0.15, 0.15, 0.06, 0.04]

COUNTRIES = ["GB", "US", "DE", "FR", "AU", "NL", "CA"]
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

# Average order value by category (GBP)
AOV = {
    "tops":        45,
    "bottoms":     65,
    "outerwear":  120,
    "accessories": 35,
    "footwear":    90,
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


# ── 1. Customers 

def generate_customers(n: int) -> list[dict]:
    customers = []
    for i in range(1, n + 1):
        acq_date    = random_date(START_DATE, END_DATE - timedelta(days=30))
        acq_channel = weighted_choice(CHANNELS, ACQ_CHANNEL_WEIGHTS)
        country     = weighted_choice(COUNTRIES, COUNTRY_WEIGHTS)

        customers.append({
            "customer_id":       f"CUST{i:05d}",
            "acquisition_channel": acq_channel,
            "acquisition_date":  acq_date.strftime("%Y-%m-%d"),
            "country":           country,
            "email_subscribed":  random.choice([True, True, True, False]),  # 75% subscribed
        })
    return customers


# ── 2. Orders 

def generate_orders(customers: list[dict], n: int) -> list[dict]:
    orders = []

    for i in range(1, n + 1):
        customer    = random.choice(customers)
        acq_date    = datetime.strptime(customer["acquisition_date"], "%Y-%m-%d")
        order_date  = random_date(acq_date, END_DATE)
        channel     = customer["acquisition_channel"]
        category    = weighted_choice(PRODUCT_CATEGORIES, CATEGORY_WEIGHTS)

        base_aov    = AOV[category]
        revenue     = round(base_aov * random.uniform(0.8, 1.6), 2)

        # Return logic — channel-specific rates
        is_returned = random.random() < RETURN_RATES[channel]

        # Discount — heavier on Meta and TikTok (another margin eroder)
        discount = 0.0
        if channel in ("meta", "tiktok") and random.random() < 0.45:
            discount = round(revenue * random.uniform(0.10, 0.25), 2)

        net_revenue = round(revenue - discount - (revenue * 0.85 if is_returned else 0), 2)

        orders.append({
            "order_id":       f"ORD{i:06d}",
            "customer_id":    customer["customer_id"],
            "order_date":     order_date.strftime("%Y-%m-%d"),
            "channel":        channel,
            "category":       category,
            "country":        customer["country"],
            "gross_revenue":  revenue,
            "discount":       discount,
            "net_revenue":    net_revenue,
            "returned":       is_returned,
            "status":         "returned" if is_returned else "completed",
        })

    return orders


# ── 3. Ad Spend 

def generate_ad_spend() -> list[dict]:
    """
    Story baked in:
    - Meta CAC rises ~40% from Jan to Dec (CPMs up, creative fatigue)
    - TikTok spend scales fast but ROAS drops Q3 onwards
    - Google remains the most stable channel
    """
    spend_rows = []

    # Base daily spend by channel (GBP)
    base_spend = {
        "meta":   320,
        "google": 180,
        "tiktok": 120,
    }

    for day in date_range(START_DATE, END_DATE):
        month_index = (day.month - 1)  # 0–11

        for channel, base in base_spend.items():
            # Seasonal multiplier — Q4 peak
            seasonal = 1.0
            if day.month in (11, 12):
                seasonal = 1.6
            elif day.month in (6, 7):
                seasonal = 1.2

            # Channel-specific drift (CAC inflation story)
            if channel == "meta":
                drift = 1 + (month_index * 0.035)   # +3.5% per month → ~40% by Dec
            elif channel == "tiktok":
                drift = 1 + (month_index * 0.02)    # Scaling spend
            else:
                drift = 1 + (month_index * 0.005)   # Google — stable

            daily_spend = round(base * seasonal * drift * random.uniform(0.85, 1.15), 2)

            # Impressions and clicks — ROAS degrades on Meta/TikTok later in year
            cpm_base = {"meta": 8.5, "google": 12.0, "tiktok": 5.0}[channel]
            cpm      = cpm_base * (1 + month_index * 0.02)
            impressions = int((daily_spend / cpm) * 1000)
            ctr         = {"meta": 0.018, "google": 0.035, "tiktok": 0.022}[channel]
            # CTR degrades slightly over time
            ctr_adjusted = ctr * (1 - month_index * 0.008)
            clicks       = int(impressions * max(ctr_adjusted, 0.008))

            spend_rows.append({
                "date":        day.strftime("%Y-%m-%d"),
                "channel":     channel,
                "spend_gbp":   daily_spend,
                "impressions": impressions,
                "clicks":      clicks,
            })

    return spend_rows


# ── 4. Fulfilment 

def generate_fulfilment(orders: list[dict]) -> list[dict]:
    fulfilment_rows = []

    for order in orders:
        order_date = datetime.strptime(order["order_date"], "%Y-%m-%d")

        # Shipping delay: 1–4 days
        shipped_at   = order_date + timedelta(days=random.randint(1, 3))
        delivered_at = shipped_at + timedelta(days=random.randint(2, 7))

        return_requested_at = None
        return_completed_at = None

        if order["returned"]:
            # Return requested 3–21 days after delivery
            return_requested_at = delivered_at + timedelta(days=random.randint(3, 21))
            return_completed_at = return_requested_at + timedelta(days=random.randint(5, 14))

        fulfilment_rows.append({
            "order_id":             order["order_id"],
            "shipped_at":           shipped_at.strftime("%Y-%m-%d"),
            "delivered_at":         delivered_at.strftime("%Y-%m-%d"),
            "return_requested_at":  return_requested_at.strftime("%Y-%m-%d") if return_requested_at else None,
            "return_completed_at":  return_completed_at.strftime("%Y-%m-%d") if return_completed_at else None,
            "fulfilment_status":    "returned" if order["returned"] else "delivered",
        })

    return fulfilment_rows


# ── Write CSVs ────────────────────────────────────────────────────────────────

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


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    print("\n🔧 Ember & Co — Mock Data Generator")
    print("=" * 45)

    print("\n[1/4] Generating customers...")
    customers = generate_customers(NUM_CUSTOMERS)
    write_csv("customers.csv", customers)

    print("\n[2/4] Generating orders...")
    orders = generate_orders(customers, NUM_ORDERS)
    write_csv("orders.csv", orders)

    print("\n[3/4] Generating ad spend...")
    ad_spend = generate_ad_spend()
    write_csv("ad_spend.csv", ad_spend)

    print("\n[4/4] Generating fulfilment records...")
    fulfilment = generate_fulfilment(orders)
    write_csv("fulfilment.csv", fulfilment)

    print("\n✅ All done. Files saved to ./data/")
    print("\nKey story in the data:")
    print("  • Meta return rate: ~31% vs organic: ~9%")
    print("  • Meta CAC inflates ~40% Jan → Dec")
    print("  • TikTok ROAS degrades Q3 onwards")
    print("  • Q4 spend spike across all channels")
    print("\nNext step: Load CSVs into Snowflake RAW schema.\n")


if __name__ == "__main__":
    main()