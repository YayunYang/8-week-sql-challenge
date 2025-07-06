USE Pizza_Runner;

-- Q1. How many pizzas were ordered?
SELECT COUNT(*) AS total_pizzas
FROM customer_orders;

-- Q2. How many unique customer orders were made?
SELECT COUNT(distinct order_id) AS No_of_unique_order
FROM customer_orders;

-- Q3. How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(*) AS successful_orders
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
GROUP BY runner_id;

-- Q4. How many of each type of pizza was delivered?
SELECT co.pizza_id, COUNT(co.pizza_id) AS number_delivered
FROM customer_orders co
JOIN runner_orders ro ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(ro.cancellation)) IN ('', 'null')
    OR ro.cancellation IS NULL) 
GROUP BY pizza_id;

-- Q5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT 
  co.customer_id, 
  pn.pizza_name, 
  COUNT(pn.pizza_name) AS order_count
FROM customer_orders AS co
JOIN pizza_names AS pn
  ON co.pizza_id= pn.pizza_id
GROUP BY co.customer_id, pn.pizza_name
ORDER BY co.customer_id;

-- Q6. What was the maximum number of pizzas delivered in a single order?
WITH valid_runner_orders AS (
SELECT order_id, runner_id, pickup_time, distance, duration
FROM runner_orders
WHERE pickup_time IS NOT NULL 
	AND (
    TRIM(LOWER(cancellation)) IN ('', 'null')
    OR cancellation IS NULL)
)
SELECT co.order_id, COUNT(co.pizza_id) AS max_number
FROM valid_runner_orders vro
JOIN customer_orders co ON vro.order_id = co.order_id
GROUP BY co.order_id
ORDER BY max_number DESC
LIMIT 1;

-- Q7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
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
SELECT cco.customer_id,
SUM(CASE WHEN cco.exclusions <> '' OR cco.extras <> '' THEN 1
	ELSE 0 END) AS at_least_one_change, 
SUM(CASE WHEN cco.exclusions = '' AND cco.extras = '' THEN 1
	ELSE 0 END) AS no_changes
FROM cleaned_customer_orders cco
JOIN valid_runner_orders vro ON cco.order_id = vro.order_id
GROUP BY cco.customer_id;

-- Q8. How many pizzas were delivered that had both exclusions and extras?
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
SELECT 
SUM(CASE WHEN cco.exclusions <> '' AND cco.extras <> '' THEN 1
	ELSE 0 END) AS has_both
FROM cleaned_customer_orders cco
JOIN valid_runner_orders vro ON cco.order_id = vro.order_id;

-- Q9. What was the total volume of pizzas ordered for each hour of the day?
SELECT HOUR(order_time) AS hour_of_day,
		COUNT(pizza_id) AS pizza_count
FROM customer_orders
GROUP BY HOUR(order_time)
ORDER BY hour_of_day;

-- Q10. What was the volume of orders for each day of the week?
SELECT 
  DAYNAME(order_time) AS day_of_week,
  COUNT(order_id) AS order_count
FROM customer_orders
GROUP BY DAYNAME(order_time);
