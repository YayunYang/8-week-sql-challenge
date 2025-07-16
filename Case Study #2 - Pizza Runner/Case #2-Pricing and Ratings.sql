USE Pizza_Runner;

-- Q1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT
  SUM(
    CASE
      WHEN pn.pizza_name = 'Meatlovers' THEN 12
      WHEN pn.pizza_name = 'Vegetarian' THEN 10
      ELSE 0
    END
  ) AS total_revenue
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
WHERE ro.pickup_time IS NOT NULL;

-- Q2. What if there was an additional $1 charge for any pizza extras?
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 5
),

-- 1. Delivered orders
delivered_orders AS (
  SELECT co.order_id, co.pizza_id, co.extras
  FROM customer_orders co
  JOIN runner_orders ro ON co.order_id = ro.order_id
  WHERE ro.pickup_time IS NOT NULL
),

-- 2. Split extras into rows
extras_split AS (
  SELECT
    d.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(d.extras, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM delivered_orders d
  JOIN numbers ON CHAR_LENGTH(REPLACE(d.extras, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(d.extras, ' ', ''), ',', '')) + 1 >= n
  WHERE d.extras IS NOT NULL AND TRIM(d.extras) <> '' AND LOWER(TRIM(d.extras)) <> 'null'
),

-- 3. Count extras per order
extras_count AS (
  SELECT order_id, COUNT(*) AS extra_count
  FROM extras_split
  GROUP BY order_id
),

-- 4. Base prices
base_prices AS (
  SELECT
    d.order_id,
    pn.pizza_name,
    CASE
      WHEN pn.pizza_name = 'Meatlovers' THEN 12
      WHEN pn.pizza_name = 'Vegetarian' THEN 10
      ELSE 0
    END AS base_price
  FROM delivered_orders d
  JOIN pizza_names pn ON d.pizza_id = pn.pizza_id
)

-- 5. Final total: base price + $1 per extra
SELECT
  SUM(bp.base_price + IFNULL(ec.extra_count, 0)) AS total_revenue
FROM base_prices bp
LEFT JOIN extras_count ec ON bp.order_id = ec.order_id;

-- Q5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
-- Step 1: Calculate total revenue from delivered pizzas
WITH revenue AS (
  SELECT
    SUM(
      CASE
        WHEN pn.pizza_name = 'Meatlovers' THEN 12
        WHEN pn.pizza_name = 'Vegetarian' THEN 10
        ELSE 0
      END
    ) AS total_revenue
  FROM customer_orders co
  JOIN runner_orders ro ON co.order_id = ro.order_id
  JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
  WHERE ro.pickup_time IS NOT NULL
),

-- Step 2: Clean and convert distance values from string to numeric (in km)
runner_pay AS (
  SELECT
    SUM(
      CAST(REPLACE(REPLACE(distance, 'km', ''), ' ', '') AS DECIMAL(5,2)) * 0.30
    ) AS total_runner_cost
  FROM runner_orders
  WHERE pickup_time IS NOT NULL AND distance IS NOT NULL
)

-- Step 3: Final net profit
SELECT
  r.total_revenue,
  p.total_runner_cost,
  r.total_revenue - p.total_runner_cost AS net_profit
FROM revenue r, runner_pay p;
