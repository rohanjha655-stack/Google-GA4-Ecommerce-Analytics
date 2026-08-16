-- Google GA4 E-commerce Analysis
-- Public dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*
-- BigQuery Standard SQL

-- ============================================================
-- Query 01: Dataset Overview
-- ============================================================
SELECT
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNT(DISTINCT event_date) AS total_days,
  MIN(PARSE_DATE('%Y%m%d', event_date)) AS start_date,
  MAX(PARSE_DATE('%Y%m%d', event_date)) AS end_date
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`;


-- ============================================================
-- Query 02: Event-wise Analysis
-- ============================================================
SELECT
  event_name,
  COUNT(*) AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  ROUND(
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
    2
  ) AS event_percentage
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
  event_name
ORDER BY
  event_count DESC;


-- ============================================================
-- Query 03: Daily Traffic Trend
-- ============================================================
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS activity_date,
  COUNT(*) AS total_events,
  COUNT(DISTINCT user_pseudo_id) AS unique_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  ROUND(
    SAFE_DIVIDE(COUNT(*), COUNT(DISTINCT user_pseudo_id)),
    2
  ) AS events_per_user
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
  activity_date
ORDER BY
  activity_date;


-- ============================================================
-- Query 04: New vs Returning Users
-- ============================================================
WITH user_type AS (
  SELECT
    user_pseudo_id,
    MAX(
      CASE
        WHEN event_name = 'first_visit' THEN 1
        ELSE 0
      END
    ) AS is_new_user
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY
    user_pseudo_id
)
SELECT
  CASE
    WHEN is_new_user = 1 THEN 'New User'
    ELSE 'Returning User'
  END AS user_category,
  COUNT(*) AS total_users,
  ROUND(
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
    2
  ) AS user_percentage
FROM
  user_type
GROUP BY
  user_category
ORDER BY
  total_users DESC;


-- ============================================================
-- Query 05: Device-wise Performance
-- ============================================================
SELECT
  device.category AS device_category,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  COUNTIF(event_name = 'purchase') AS total_purchases,
  COUNT(DISTINCT IF(
    event_name = 'purchase',
    user_pseudo_id,
    NULL
  )) AS purchasing_users,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)),
      COUNT(DISTINCT user_pseudo_id)
    ) * 100,
    2
  ) AS user_conversion_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
  device_category
ORDER BY
  total_users DESC;


-- ============================================================
-- Query 06: Top 10 Countries by Users and Conversion
-- ============================================================
SELECT
  geo.country AS country,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  COUNTIF(event_name = 'purchase') AS total_purchases,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)),
      COUNT(DISTINCT user_pseudo_id)
    ) * 100,
    2
  ) AS user_conversion_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  geo.country IS NOT NULL
GROUP BY
  country
ORDER BY
  total_users DESC
LIMIT 10;


-- ============================================================
-- Query 07: Traffic-source Performance
-- ============================================================
SELECT
  traffic_source.source AS traffic_source,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  COUNTIF(event_name = 'purchase') AS total_purchases,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL)),
      COUNT(DISTINCT user_pseudo_id)
    ) * 100,
    2
  ) AS user_conversion_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  traffic_source.source IS NOT NULL
GROUP BY
  traffic_source
ORDER BY
  total_users DESC
LIMIT 10;


-- ============================================================
-- Query 08: Monthly Revenue and Average Order Value
-- ============================================================
SELECT
  FORMAT_DATE(
    '%Y-%m',
    PARSE_DATE('%Y%m%d', event_date)
  ) AS month,
  COUNT(DISTINCT ecommerce.transaction_id) AS total_orders,
  ROUND(SUM(ecommerce.purchase_revenue), 2) AS total_revenue,
  ROUND(
    SAFE_DIVIDE(
      SUM(ecommerce.purchase_revenue),
      COUNT(DISTINCT ecommerce.transaction_id)
    ),
    2
  ) AS average_order_value
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  event_name = 'purchase'
GROUP BY
  month
ORDER BY
  month;


-- ============================================================
-- Query 09: Top 10 Products by Revenue
-- ============================================================
SELECT
  item.item_name AS product_name,
  COUNT(DISTINCT ecommerce.transaction_id) AS total_orders,
  SUM(item.quantity) AS units_sold,
  ROUND(SUM(item.item_revenue), 2) AS product_revenue
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
CROSS JOIN
  UNNEST(items) AS item
WHERE
  event_name = 'purchase'
  AND item.item_name IS NOT NULL
GROUP BY
  product_name
ORDER BY
  product_revenue DESC
LIMIT 10;


-- ============================================================
-- Query 10: Overall E-commerce Funnel
-- ============================================================
WITH funnel AS (
  SELECT
    COUNT(DISTINCT IF(event_name = 'view_item', user_pseudo_id, NULL))
      AS viewed_product,
    COUNT(DISTINCT IF(event_name = 'add_to_cart', user_pseudo_id, NULL))
      AS added_to_cart,
    COUNT(DISTINCT IF(event_name = 'begin_checkout', user_pseudo_id, NULL))
      AS began_checkout,
    COUNT(DISTINCT IF(event_name = 'purchase', user_pseudo_id, NULL))
      AS purchased
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
)
SELECT
  viewed_product,
  added_to_cart,
  began_checkout,
  purchased,
  ROUND(SAFE_DIVIDE(added_to_cart, viewed_product) * 100, 2)
    AS view_to_cart_rate,
  ROUND(SAFE_DIVIDE(began_checkout, added_to_cart) * 100, 2)
    AS cart_to_checkout_rate,
  ROUND(SAFE_DIVIDE(purchased, began_checkout) * 100, 2)
    AS checkout_to_purchase_rate,
  ROUND(SAFE_DIVIDE(purchased, viewed_product) * 100, 2)
    AS overall_funnel_conversion
FROM
  funnel;


-- ============================================================
-- Query 11: Product-wise Conversion Analysis
-- ============================================================
SELECT
  item.item_name AS product_name,
  COUNT(DISTINCT CASE
    WHEN event_name = 'view_item' THEN user_pseudo_id
  END) AS users_viewed,
  COUNT(DISTINCT CASE
    WHEN event_name = 'add_to_cart' THEN user_pseudo_id
  END) AS users_added_to_cart,
  COUNT(DISTINCT CASE
    WHEN event_name = 'purchase' THEN user_pseudo_id
  END) AS users_purchased,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT CASE
        WHEN event_name = 'purchase' THEN user_pseudo_id
      END),
      COUNT(DISTINCT CASE
        WHEN event_name = 'view_item' THEN user_pseudo_id
      END)
    ) * 100,
    2
  ) AS view_to_purchase_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
CROSS JOIN
  UNNEST(items) AS item
WHERE
  event_name IN ('view_item', 'add_to_cart', 'purchase')
  AND item.item_name IS NOT NULL
GROUP BY
  product_name
HAVING
  users_viewed >= 100
ORDER BY
  view_to_purchase_rate DESC
LIMIT 10;


-- ============================================================
-- Query 12: Day-of-week Performance
-- ============================================================
SELECT
  FORMAT_DATE(
    '%A',
    PARSE_DATE('%Y%m%d', event_date)
  ) AS day_name,
  EXTRACT(
    DAYOFWEEK FROM PARSE_DATE('%Y%m%d', event_date)
  ) AS day_number,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  COUNTIF(event_name = 'purchase') AS total_purchases,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT CASE
        WHEN event_name = 'purchase' THEN user_pseudo_id
      END),
      COUNT(DISTINCT user_pseudo_id)
    ) * 100,
    2
  ) AS user_conversion_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
GROUP BY
  day_name,
  day_number
ORDER BY
  day_number;


-- ============================================================
-- Query 13: One-time vs Repeat Purchasers
-- ============================================================
WITH customer_orders AS (
  SELECT
    user_pseudo_id,
    COUNT(DISTINCT ecommerce.transaction_id) AS total_orders,
    SUM(ecommerce.purchase_revenue) AS customer_revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    event_name = 'purchase'
  GROUP BY
    user_pseudo_id
)
SELECT
  CASE
    WHEN total_orders = 1 THEN 'One-time Purchaser'
    WHEN total_orders > 1 THEN 'Repeat Purchaser'
  END AS customer_type,
  COUNT(*) AS total_customers,
  ROUND(
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
    2
  ) AS customer_percentage,
  ROUND(SUM(customer_revenue), 2) AS total_revenue,
  ROUND(AVG(customer_revenue), 2) AS average_revenue_per_customer
FROM
  customer_orders
GROUP BY
  customer_type
ORDER BY
  total_customers DESC;


-- ============================================================
-- Query 14: Cart-abandonment Analysis
-- ============================================================
WITH user_activity AS (
  SELECT
    user_pseudo_id,
    MAX(CASE
      WHEN event_name = 'add_to_cart' THEN 1
      ELSE 0
    END) AS added_to_cart,
    MAX(CASE
      WHEN event_name = 'purchase' THEN 1
      ELSE 0
    END) AS made_purchase
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  GROUP BY
    user_pseudo_id
)
SELECT
  COUNTIF(added_to_cart = 1) AS users_added_to_cart,
  COUNTIF(added_to_cart = 1 AND made_purchase = 0)
    AS users_abandoned_cart,
  COUNTIF(added_to_cart = 1 AND made_purchase = 1)
    AS cart_users_who_purchased,
  ROUND(
    SAFE_DIVIDE(
      COUNTIF(added_to_cart = 1 AND made_purchase = 0),
      COUNTIF(added_to_cart = 1)
    ) * 100,
    2
  ) AS cart_abandonment_rate
FROM
  user_activity;


-- ============================================================
-- Query 15: Browser-wise Performance
-- ============================================================
SELECT
  device.web_info.browser AS browser,
  COUNT(DISTINCT user_pseudo_id) AS total_users,
  COUNTIF(event_name = 'session_start') AS total_sessions,
  COUNTIF(event_name = 'purchase') AS total_purchases,
  ROUND(
    SAFE_DIVIDE(
      COUNT(DISTINCT CASE
        WHEN event_name = 'purchase' THEN user_pseudo_id
      END),
      COUNT(DISTINCT user_pseudo_id)
    ) * 100,
    2
  ) AS user_conversion_rate
FROM
  `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE
  device.web_info.browser IS NOT NULL
GROUP BY
  browser
HAVING
  total_users >= 100
ORDER BY
  total_users DESC
LIMIT 10;


-- ============================================================
-- Query 16: Month-over-month Revenue Growth
-- ============================================================
WITH monthly_revenue AS (
  SELECT
    DATE_TRUNC(
      PARSE_DATE('%Y%m%d', event_date),
      MONTH
    ) AS month,
    ROUND(SUM(ecommerce.purchase_revenue), 2) AS revenue
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    event_name = 'purchase'
  GROUP BY
    month
),
revenue_comparison AS (
  SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue
  FROM
    monthly_revenue
)
SELECT
  month,
  revenue,
  previous_month_revenue,
  ROUND(
    SAFE_DIVIDE(
      revenue - previous_month_revenue,
      previous_month_revenue
    ) * 100,
    2
  ) AS month_over_month_growth_percentage
FROM
  revenue_comparison
ORDER BY
  month;


-- ============================================================
-- Query 17: Monthly Cohort-retention Analysis
-- ============================================================
WITH user_activity AS (
  SELECT DISTINCT
    user_pseudo_id,
    DATE_TRUNC(
      PARSE_DATE('%Y%m%d', event_date),
      MONTH
    ) AS activity_month
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
),
user_cohort AS (
  SELECT
    user_pseudo_id,
    MIN(activity_month) AS cohort_month
  FROM
    user_activity
  GROUP BY
    user_pseudo_id
),
cohort_activity AS (
  SELECT
    c.cohort_month,
    a.activity_month,
    DATE_DIFF(a.activity_month, c.cohort_month, MONTH) AS month_number,
    COUNT(DISTINCT a.user_pseudo_id) AS active_users
  FROM
    user_activity AS a
  JOIN
    user_cohort AS c
    ON a.user_pseudo_id = c.user_pseudo_id
  GROUP BY
    c.cohort_month,
    a.activity_month,
    month_number
),
cohort_size AS (
  SELECT
    cohort_month,
    active_users AS total_cohort_users
  FROM
    cohort_activity
  WHERE
    month_number = 0
)
SELECT
  ca.cohort_month,
  ca.activity_month,
  ca.month_number,
  cs.total_cohort_users,
  ca.active_users,
  ROUND(
    SAFE_DIVIDE(ca.active_users, cs.total_cohort_users) * 100,
    2
  ) AS retention_rate
FROM
  cohort_activity AS ca
JOIN
  cohort_size AS cs
  ON ca.cohort_month = cs.cohort_month
ORDER BY
  ca.cohort_month,
  ca.month_number;
