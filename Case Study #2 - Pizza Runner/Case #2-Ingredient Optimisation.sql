USE Pizza_Runner;

-- Q1. What are the standard ingredients for each pizza?
SELECT 
  pn.pizza_name,
  pt.topping_name
FROM pizza_names pn
JOIN pizza_recipes pr ON pn.pizza_id = pr.pizza_id
JOIN pizza_toppings pt ON ',' || pr.toppings || ',' LIKE '%,' || pt.topping_id || ',%'
ORDER BY pn.pizza_name, pt.topping_name;

-- Q2. What was the most commonly added extra?
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 5
),
split_extras AS (
  SELECT
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(extras, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM customer_orders
  JOIN numbers ON CHAR_LENGTH(REPLACE(extras, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(extras, ' ', ''), ',', '')) + 1 >= n
  WHERE extras IS NOT NULL
    AND TRIM(extras) <> ''
    AND LOWER(TRIM(extras)) <> 'null'
)
SELECT
  pt.topping_name,
  COUNT(*) AS count
FROM split_extras se
JOIN pizza_toppings pt ON pt.topping_id = se.topping_id
GROUP BY pt.topping_name
ORDER BY count DESC
LIMIT 1;

-- Q3. What was the most common exclusion?
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 5
),
split_exclusions AS (
  SELECT
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(exclusions, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM customer_orders
  JOIN numbers ON CHAR_LENGTH(REPLACE(exclusions, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(exclusions, ' ', ''), ',', '')) + 1 >= n
  WHERE exclusions IS NOT NULL
    AND TRIM(exclusions) <> ''
    AND LOWER(TRIM(exclusions)) <> 'null'
)
SELECT
  pt.topping_name,
  COUNT(*) AS count
FROM split_exclusions se
JOIN pizza_toppings pt ON pt.topping_id = se.topping_id
GROUP BY pt.topping_name
ORDER BY count DESC
LIMIT 1;

-- Q4. Generate an order item for each record in the customers_orders table in the format of one of the following
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 5
),

-- Step 1: Base order with pizza name
base_orders AS (
  SELECT
    co.order_id,
    co.pizza_id,
    pn.pizza_name,
    co.exclusions,
    co.extras
  FROM customer_orders co
  JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
),

-- Step 2: Split exclusions
exclusion_split AS (
  SELECT
    bo.order_id,
    'Exclude' AS type,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(bo.exclusions, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM base_orders bo
  JOIN numbers ON CHAR_LENGTH(REPLACE(bo.exclusions, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(bo.exclusions, ' ', ''), ',', '')) + 1 >= n
  WHERE bo.exclusions IS NOT NULL AND TRIM(bo.exclusions) <> '' AND LOWER(TRIM(bo.exclusions)) <> 'null'
),

-- Step 3: Split extras
extra_split AS (
  SELECT
    bo.order_id,
    'Extra' AS type,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(bo.extras, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM base_orders bo
  JOIN numbers ON CHAR_LENGTH(REPLACE(bo.extras, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(bo.extras, ' ', ''), ',', '')) + 1 >= n
  WHERE bo.extras IS NOT NULL AND TRIM(bo.extras) <> '' AND LOWER(TRIM(bo.extras)) <> 'null'
),

-- Step 4: Combine all modifications
all_mods AS (
  SELECT * FROM exclusion_split
  UNION ALL
  SELECT * FROM extra_split
),

-- Step 5: Get topping names
mods_named AS (
  SELECT
    am.order_id,
    am.type,
    pt.topping_name
  FROM all_mods am
  JOIN pizza_toppings pt ON pt.topping_id = am.topping_id
),

-- Step 6: Aggregate by order
mod_agg AS (
  SELECT
    order_id,
    GROUP_CONCAT(CASE WHEN type = 'Exclude' THEN topping_name END ORDER BY topping_name SEPARATOR ', ') AS exclude_list,
    GROUP_CONCAT(CASE WHEN type = 'Extra' THEN topping_name END ORDER BY topping_name SEPARATOR ', ') AS extra_list
  FROM mods_named
  GROUP BY order_id
)

-- Step 7: Final formatting
SELECT
  bo.order_id,
  CASE
    WHEN ma.exclude_list IS NULL AND ma.extra_list IS NULL THEN pn.pizza_name
    WHEN ma.exclude_list IS NOT NULL AND ma.extra_list IS NULL THEN CONCAT(pn.pizza_name, ' - Exclude ', ma.exclude_list)
    WHEN ma.exclude_list IS NULL AND ma.extra_list IS NOT NULL THEN CONCAT(pn.pizza_name, ' - Extra ', ma.extra_list)
    ELSE CONCAT(pn.pizza_name, ' - Exclude ', ma.exclude_list, ' - Extra ', ma.extra_list)
  END AS order_item
FROM base_orders bo
LEFT JOIN mod_agg ma ON bo.order_id = ma.order_id
JOIN pizza_names pn ON bo.pizza_id = pn.pizza_id
ORDER BY bo.order_id;

-- Q5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 10
),

-- 1. Base order info
orders AS (
  SELECT co.order_id, co.pizza_id, co.exclusions, co.extras, pn.pizza_name, pr.toppings AS base_toppings
  FROM customer_orders co
  JOIN pizza_names pn ON co.pizza_id = pn.pizza_id
  JOIN pizza_recipes pr ON co.pizza_id = pr.pizza_id
),

-- 2. Split base toppings
base_split AS (
  SELECT
    o.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(o.base_toppings, ',', n), ',', -1) AS UNSIGNED) AS topping_id,
    'base' AS source
  FROM orders o
  JOIN numbers ON CHAR_LENGTH(o.base_toppings) - CHAR_LENGTH(REPLACE(o.base_toppings, ',', '')) + 1 >= n
),

-- 3. Split exclusions
exclusion_split AS (
  SELECT
    o.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(o.exclusions, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM orders o
  JOIN numbers ON CHAR_LENGTH(REPLACE(o.exclusions, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(o.exclusions, ' ', ''), ',', '')) + 1 >= n
  WHERE o.exclusions IS NOT NULL AND TRIM(o.exclusions) <> '' AND LOWER(o.exclusions) <> 'null'
),

-- 4. Split extras
extra_split AS (
  SELECT
    o.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(o.extras, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id,
    'extra' AS source
  FROM orders o
  JOIN numbers ON CHAR_LENGTH(REPLACE(o.extras, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(o.extras, ' ', ''), ',', '')) + 1 >= n
  WHERE o.extras IS NOT NULL AND TRIM(o.extras) <> '' AND LOWER(o.extras) <> 'null'
),

-- 5. Combine base + extras
combined_toppings AS (
  SELECT * FROM base_split
  UNION ALL
  SELECT * FROM extra_split
),

-- 6. Remove exclusions
filtered_toppings AS (
  SELECT ct.order_id, ct.topping_id, ct.source
  FROM combined_toppings ct
  LEFT JOIN exclusion_split es ON ct.order_id = es.order_id AND ct.topping_id = es.topping_id
  WHERE es.topping_id IS NULL
),

-- 7. Mark 2x toppings (if they appear in both base and extras)
topping_counted AS (
  SELECT
    ft.order_id,
    pt.topping_name,
    COUNT(*) AS qty
  FROM filtered_toppings ft
  JOIN pizza_toppings pt ON pt.topping_id = ft.topping_id
  GROUP BY ft.order_id, pt.topping_name
),

-- 8. Final formatting
formatted AS (
  SELECT
    order_id,
    CASE
      WHEN qty = 2 THEN CONCAT('2x', topping_name)
      ELSE topping_name
    END AS ingredient
  FROM topping_counted
),

-- 9. Group and output
final_output AS (
  SELECT
    o.order_id,
    o.pizza_name,
    GROUP_CONCAT(f.ingredient ORDER BY f.ingredient SEPARATOR ', ') AS ingredient_list
  FROM orders o
  JOIN formatted f ON o.order_id = f.order_id
  GROUP BY o.order_id, o.pizza_name
)

SELECT CONCAT(pizza_name, ': ', ingredient_list) AS order_description
FROM final_output
ORDER BY order_description;

-- Q6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH RECURSIVE numbers AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM numbers WHERE n < 10
),

-- Step 1: Get only delivered orders
delivered_orders AS (
  SELECT co.*
  FROM customer_orders co
  JOIN runner_orders ro ON co.order_id = ro.order_id
  WHERE ro.pickup_time IS NOT NULL
),

-- Step 2: Get pizza base toppings
base_toppings AS (
  SELECT
    d.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(pr.toppings, ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM delivered_orders d
  JOIN pizza_recipes pr ON d.pizza_id = pr.pizza_id
  JOIN numbers ON CHAR_LENGTH(pr.toppings) - CHAR_LENGTH(REPLACE(pr.toppings, ',', '')) + 1 >= n
),

-- Step 3: Get exclusions
exclusion_toppings AS (
  SELECT
    d.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(d.exclusions, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM delivered_orders d
  JOIN numbers ON CHAR_LENGTH(REPLACE(d.exclusions, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(d.exclusions, ' ', ''), ',', '')) + 1 >= n
  WHERE d.exclusions IS NOT NULL AND TRIM(d.exclusions) <> '' AND LOWER(TRIM(d.exclusions)) <> 'null'
),

-- Step 4: Get extras
extra_toppings AS (
  SELECT
    d.order_id,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(d.extras, ' ', ''), ',', n), ',', -1) AS UNSIGNED) AS topping_id
  FROM delivered_orders d
  JOIN numbers ON CHAR_LENGTH(REPLACE(d.extras, ' ', '')) - CHAR_LENGTH(REPLACE(REPLACE(d.extras, ' ', ''), ',', '')) + 1 >= n
  WHERE d.extras IS NOT NULL AND TRIM(d.extras) <> '' AND LOWER(TRIM(d.extras)) <> 'null'
),

-- Step 5: Filter out excluded toppings from base
filtered_base AS (
  SELECT bt.*
  FROM base_toppings bt
  LEFT JOIN exclusion_toppings et ON bt.order_id = et.order_id AND bt.topping_id = et.topping_id
  WHERE et.topping_id IS NULL
),

-- Step 6: Combine filtered base + extras
all_toppings AS (
  SELECT * FROM filtered_base
  UNION ALL
  SELECT * FROM extra_toppings
),

-- Step 7: Count each topping
topping_counts AS (
  SELECT topping_id, COUNT(*) AS total_count
  FROM all_toppings
  GROUP BY topping_id
)

-- Step 8: Join with topping names and sort
SELECT
  pt.topping_name,
  tc.total_count
FROM topping_counts tc
JOIN pizza_toppings pt ON pt.topping_id = tc.topping_id
ORDER BY tc.total_count DESC;