This is the questions and my answers in case-1

Question 1. What is the total amount each customer spent at the restaurant?
<pre>
SELECT customer_id, SUM(menu.price) AS totla_spent
FROM sales
JOIN menu ON sales.product_id = menu.product_id
GROUP BY customer_id;
</pre>
