USE Pizza_Runner;

-- Q1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT 
  FLOOR(DATEDIFF(registration_date, '2021-01-01') / 7) + 1 AS week_number,
  COUNT(*) AS runners_signed_up
FROM runners
GROUP BY week_number
ORDER BY week_number;

-- Q2. What was the average time in minutes it took for each runner to arrive at 
--     the Pizza Runner HQ to pickup the order?
WITH cleaned_customer_orders AS (
SELECT order_id, customer_id, pizza_id, CASE WHEN exclusions = 'null' THEN ''
											ELSE exclusions
											END AS exclusions,
										CASE WHEN extras IS NULL THEN ''
											WHEN extras = 'null' THEN ''
											ELSE extras
                                            END AS extras, order_time
FROM customer_orders
),
valid_runner_orders AS (
SELECT order_id, runner_id, pickup_time, distance, duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
)
SELECT vro.runner_id, ROUND(AVG(TIMESTAMPDIFF(MINUTE, cco.order_time, vro.pickup_time)), 2) AS avg_pickup_minutes
FROM cleaned_customer_orders cco
JOIN valid_runner_orders vro ON cco.order_id = vro.order_id
GROUP BY vro.runner_id;

-- Q3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH cleaned_customer_orders AS (
SELECT order_id, customer_id, pizza_id, CASE WHEN exclusions = 'null' THEN ''
											ELSE exclusions
											END AS exclusions,
										CASE WHEN extras IS NULL THEN ''
											WHEN extras = 'null' THEN ''
											ELSE extras
                                            END AS extras, order_time
FROM customer_orders
),
valid_runner_orders AS (
SELECT order_id, runner_id, pickup_time, distance, duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
),
order_prep_time AS (
  SELECT 
    cco.order_id,
    COUNT(cco.pizza_id) AS pizzas_in_order,
    TIMESTAMPDIFF(MINUTE, MIN(cco.order_time), vro.pickup_time) AS prep_time
  FROM cleaned_customer_orders cco
  JOIN valid_runner_orders vro ON cco.order_id = vro.order_id
  GROUP BY cco.order_id, vro.pickup_time
)
SELECT 
  pizzas_in_order,
  ROUND(AVG(prep_time), 2) AS avg_prep_time
FROM order_prep_time
GROUP BY pizzas_in_order
ORDER BY pizzas_in_order;

-- Q4. What was the average distance travelled for each customer?
WITH cleaned_runner_orders AS(
SELECT
order_id, runner_id, pickup_time,
CAST(REPLACE(TRIM(REPLACE(distance, 'km', '')), ' ', '') AS DECIMAL(5, 2)) AS distance,
CAST(TRIM(REGEXP_SUBSTR(duration, '[0-9]+')) AS UNSIGNED) AS duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
), cleaned_customer_orders AS (
SELECT order_id, customer_id, pizza_id, CASE WHEN exclusions = 'null' THEN ''
											ELSE exclusions
											END AS exclusions,
										CASE WHEN extras IS NULL THEN ''
											WHEN extras = 'null' THEN ''
											ELSE extras
                                            END AS extras, order_time
FROM customer_orders
)
SELECT cco.customer_id, AVG(cro.distance) AS avg_distance
FROM cleaned_customer_orders cco
JOIN cleaned_runner_orders cro ON cco.order_id = cro.order_id
GROUP BY cco.customer_id;

-- Q5. What was the difference between the longest and shortest delivery times for all orders?
WITH cleaned_runner_orders AS(
SELECT
order_id, runner_id, pickup_time,
CAST(REPLACE(TRIM(REPLACE(distance, 'km', '')), ' ', '') AS DECIMAL(5, 2)) AS distance,
CAST(TRIM(REGEXP_SUBSTR(duration, '[0-9]+')) AS UNSIGNED) AS duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
)
SELECT MAX(duration) - MIN(duration) AS largest_difference
FROM cleaned_runner_orders;

-- Q6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
WITH cleaned_runner_orders AS(
SELECT
order_id, runner_id, pickup_time,
CAST(REPLACE(TRIM(REPLACE(distance, 'km', '')), ' ', '') AS DECIMAL(5, 2)) AS distance,
CAST(TRIM(REGEXP_SUBSTR(duration, '[0-9]+')) AS UNSIGNED) AS duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
)
SELECT runner_id, order_id, ROUND(distance/(duration/60), 2) AS speed
FROM cleaned_runner_orders
ORDER BY runner_id;

-- Q7. What is the successful delivery percentage for each runner?
WITH modified_runner_orders AS(
SELECT 
    runner_id,
    order_id,
    pickup_time,
    cancellation,
    -- Flag successful delivery
    CASE 
      WHEN pickup_time IS NOT NULL 
           AND (TRIM(LOWER(cancellation)) IN ('', 'null') OR cancellation IS NULL)
      THEN 1 ELSE 0
    END AS is_successful
  FROM runner_orders
)
SELECT
runner_id,
COUNT(*) AS total_orders,
SUM(is_successful) AS successful_deliveries,
ROUND(SUM(is_successful) / COUNT(*) * 100, 2) AS success_rate_percent
FROM modified_runner_orders
GROUP BY runner_id;
