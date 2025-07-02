-- Q1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(menu.price) AS total_spent
FROM sales
JOIN menu ON sales.product_id = menu.product_id
GROUP BY customer_id;

-- Q2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(distinct order_date) AS visit_count
FROM sales
GROUP BY customer_id;

-- Q3. What was the first item from the menu purchased by each customer?
SELECT s.customer_id, s.order_date, m.product_name
FROM sales s
JOIN menu m ON s.product_id = m.product_id
WHERE (s.customer_id, s.order_date) IN ( 
	SELECT
		  customer_id,
		  MIN(order_date)
	FROM
		  sales
	GROUP BY
		  customer_id
	);
    
-- Q4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT m.product_name, COUNT(s.product_id) AS num_purchased
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY m.product_name
ORDER BY num_purchased DESC
LIMIT 1;

-- Q5. Which item was the most popular for each customer?
WITH ranked_purchases AS(
SELECT s.customer_id, m.product_name, COUNT(*) AS purchase_count, 
		DENSE_RANK () OVER (partition by s.customer_id order by COUNT(*) DESC) AS rank_num
FROM sales s
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id, m.product_name
)
SELECT customer_id, product_name, purchase_count
FROM ranked_purchases
WHERE rank_num = 1;

-- Q6. Which item was purchased first by the customer after they became a member?
WITH order_sequence AS (
	SELECT s.customer_id, s.product_id, s.order_date, m.join_date,
			ROW_NUMBER () OVER (PARTITION BY s.customer_id ORDER BY s.order_date) AS sequence
	FROM sales s
	JOIN members m ON s.customer_id = m.customer_id
    WHERE s.order_date >= m.join_date
)

SELECT os.customer_id, m.product_name
FROM order_sequence os
JOIN menu m ON os.product_id = m.product_id
WHERE os.sequence = 1;

-- Q7. Which item was purchased just before the customer became a member?
WITH order_sequence AS (
	SELECT s.customer_id, s.product_id, s.order_date, m.join_date,
			DENSE_RANK () OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS sequence
	FROM sales s
	JOIN members m ON s.customer_id = m.customer_id
    WHERE s.order_date < m.join_date
)

SELECT os.customer_id, m.product_name
FROM order_sequence os
JOIN menu m ON os.product_id = m.product_id
WHERE os.sequence = 1;

-- Q8. What is the total items and amount spent for each member before they became a member?
WITH order_sequence AS (
	SELECT s.customer_id, s.product_id, s.order_date, m.join_date,
			DENSE_RANK () OVER (PARTITION BY s.customer_id ORDER BY s.order_date DESC) AS sequence
	FROM sales s
	JOIN members m ON s.customer_id = m.customer_id
    WHERE s.order_date < m.join_date
)

SELECT os.customer_id, SUM(m.price) AS totla_amount
FROM order_sequence os
JOIN menu m ON os.product_id = m.product_id
GROUP BY os.customer_id;

-- Q9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - 
--     how many points would each customer have?
WITH product_points AS(
	SELECT product_id, CASE WHEN product_id = 1 THEN price * 20
							ELSE price * 10
                            END AS points
    FROM menu
)
SELECT s.customer_id, SUM(pp.points)
FROM product_points pp
JOIN sales s ON s.product_id = pp. product_id
GROUP BY s.customer_id;

-- Q10. In the first week after a customer joins the program (including their join date) 
--      they earn 2x points on all items, not just sushi - 
--      how many points do customer A and B have at the end of January?
SELECT s.customer_id, SUM(case WHEN s.order_date BETWEEN mb.join_date AND DATE_ADD(mb.join_date, INTERVAL 7 DAY)
							THEN m.price * 2
                            ELSE m.price
                            END) AS total_points
FROM sales s
JOIN menu m ON s.product_id = m.product_id
JOIN members mb ON s.customer_id = mb.customer_id
WHERE s.customer_id IN ('A', 'B') AND s.order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- Bonus Question 1. Join All The Things
SELECT s.customer_id, s.order_date, m.product_name, m.price, CASE WHEN s.order_date < mb.join_date THEN 'N'
																WHEN s.order_date >= mb.join_date THEN 'Y'
                                                                ELSE 'N' END AS member_status
FROM sales s
JOIN menu m ON s.product_id = m.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id
ORDER BY s.customer_id, s.order_date;

-- Bonus Question 2. Rank All The Things
WITH join_all AS (
	SELECT s.customer_id, s.order_date, m.product_name, m.price, CASE WHEN s.order_date < mb.join_date THEN 'N'
																WHEN s.order_date >= mb.join_date THEN 'Y'
                                                                ELSE 'N' END AS member_status
	FROM sales s
	JOIN menu m ON s.product_id = m.product_id
	LEFT JOIN members mb ON s.customer_id = mb.customer_id
	ORDER BY s.customer_id, s.order_date
)
SELECT customer_id, order_date, product_name, price, member_status, CASE WHEN member_status = 'N' THEN NULL
																		ELSE DENSE_RANK () OVER (PARTITION BY customer_id, member_status
																								ORDER BY order_date
																		)END AS ranking
FROM join_all;