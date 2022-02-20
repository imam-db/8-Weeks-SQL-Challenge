# 1. What is the total amount each customer spent at the restaurant?
SELECT sales.`customer_id`, 
	SUM(menu.`price`) AS total_amount
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`
GROUP BY sales.customer_id;

# 2. How many days has each customer visited the restaurant?
SELECT sales.`customer_id`,
	COUNT(DISTINCT sales.order_date) AS total_days
FROM sales AS sales
GROUP BY sales.`customer_id`;

# 3. What was the first item from the menu purchased by each customer?
WITH all_sales AS
(
SELECT sales.`customer_id`, 
	sales.`order_date`, 
	sales.`product_id`,
	menu.`product_name`,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS number
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`)

SELECT customer_id,
	product_name
FROM all_sales
WHERE number = 1;

# 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
WITH product_purchased AS
(
SELECT sales.`product_id`, 
	menu.`product_name`, 
	COUNT(sales.product_id) AS total_purchased,
	ROW_NUMBER() OVER(ORDER BY COUNT(sales.product_id) DESC) AS number
FROM sales AS sales
INNER JOIN menu AS menu
ON menu.`product_id` = sales.`product_id`
GROUP BY sales.`product_id`
ORDER BY total_purchased DESC)

SELECT product_name, 
	total_purchased
FROM product_purchased
WHERE number = 1;

# 5. Which item was the most popular for each customer?
WITH all_sales AS
(
SELECT sales.`customer_id`,
	menu.`product_id`,
	menu.`product_name`,
	COUNT(*) AS total_purchase,
	ROW_NUMBER() OVER(PARTITION BY sales.`customer_id` ORDER BY COUNT(*) DESC) AS number
FROM sales AS sales
INNER JOIN menu AS menu
ON menu.`product_id` = sales.`product_id`
GROUP BY sales.`customer_id`, menu.`product_id`
)

SELECT customer_id,
	product_name
FROM all_sales 
WHERE number = 1;

# 6. Which item was purchased first by the customer after they became a member?
WITH all_sales AS
(
SELECT sales.`customer_id`, 
	sales.`order_date`, 
	sales.`product_id`,
	menu.`product_name`,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS number
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`
INNER JOIN members AS members
ON members.`customer_id` = sales.`customer_id`
WHERE members.`joindate` < sales.`order_date`
)

SELECT customer_id,
	product_name
FROM all_sales
WHERE number = 1;

# 7. Which item was purchased just before the customer became a member?
WITH all_sales AS
(
SELECT sales.`customer_id`, 
	sales.`order_date`, 
	sales.`product_id`,
	menu.`product_name`,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date DESC) AS number
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`
INNER JOIN members AS members
ON members.`customer_id` = sales.`customer_id`
WHERE members.`joindate` > sales.`order_date`
)

SELECT customer_id,
	product_name
FROM all_sales
WHERE number = 1;

# 8. What is the total items and amount spent for each member before they became a member?
WITH all_sales AS
(
SELECT sales.`customer_id`, 
	sales.`order_date`, 
	sales.`product_id`,
	menu.`product_name`,
	menu.`price`
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`
INNER JOIN members AS members
ON members.`customer_id` = sales.`customer_id`
WHERE members.`joindate` > sales.`order_date`
)

SELECT customer_id,
	COUNT(`product_id`) AS total_items,
	SUM(price) AS total_amount
FROM all_sales
GROUP BY customer_id;

# 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT sales.`customer_id`, 
	SUM(CASE WHEN menu.`product_id` = 1 THEN menu.`price` * 2 * 10 ELSE menu.`price` * 10 END) AS points
FROM sales AS sales
INNER JOIN menu AS menu
ON sales.`product_id` = menu.`product_id`
GROUP BY sales.`customer_id`;

# 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
# not just sushi - how many points do customer A and B have at the end of January?
WITH all_sales AS
(
SELECT sales.`customer_id`,
	sales.`order_date`,
	menu.product_id,
	menu.`product_name`,
	menu.`price`,
	members.`joindate`,
	DATE_ADD(members.`joindate`, INTERVAL 7 DAY) AS one_week
FROM sales AS sales
INNER JOIN members AS members 
ON sales.`customer_id` = members.`customer_id`
INNER JOIN menu AS menu
ON menu.`product_id` = sales.`product_id`
)

SELECT customer_id,
	SUM(
	CASE WHEN order_date BETWEEN joindate AND one_week THEN 2 * 10 * price
	WHEN order_date NOT BETWEEN joindate AND one_week AND product_id = 1 THEN 2 * 10 * price
	ELSE 10 * price END) AS points
FROM all_sales
GROUP BY customer_id