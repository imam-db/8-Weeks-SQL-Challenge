# Pizza Metrics

## 1. How many pizzas were ordered?
SELECT COUNT(pizza_id) AS total_pizza
FROM customer_orders AS co;

## 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT customer_id) AS total_unique_customer
FROM customer_orders AS co;

## 3. How many successful orders were delivered by each runner?
SELECT COUNT(ro.`order_id`) AS total_successful_order
FROM runner_orders AS ro
WHERE pickup_time IS NOT NULL;

## 4. How many of each type of pizza was delivered?
SELECT co.`pizza_id`, COUNT(pizza_id) AS total_pizza
FROM customer_orders AS co
GROUP BY co.`pizza_id`;

## 5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT co.`customer_id`, 
	co.`pizza_id`,
	pn.`pizza_name`,
	COUNT(co.`pizza_id`) AS total_pizza
FROM customer_orders AS co
INNER JOIN pizza_names AS pn
ON co.`pizza_id` = pn.`pizza_id`
GROUP BY co.`customer_id`, 
	co.`pizza_id`;

## 6. What was the maximum number of pizzas delivered in a single order?
WITH co AS
(
SELECT co.`order_id`, 
	COUNT(co.`pizza_id`) AS total_pizza, 
	ROW_NUMBER() OVER(ORDER BY COUNT(co.`pizza_id`) DESC) AS number
FROM customer_orders AS co
GROUP BY co.`order_id`
)

SELECT total_pizza
FROM co
WHERE co.number = 1;

## 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
WITH orders AS
(
SELECT co.order_id, 
	pizza_id,
	customer_id,
	COALESCE(CASE WHEN (exclusions IS NULL OR exclusions = "") OR (extras IS NULL OR extras = "") THEN 1 END,0) AS is_change,
	COALESCE(CASE WHEN (exclusions IS NOT NULL OR exclusions <> "") OR (extras IS NOT NULL OR extras <> "") THEN 1 END,0) AS is_notchange
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
)

SELECT customer_id,
	SUM(CASE WHEN is_change > 0 AND is_notchange > 0 THEN 1
	WHEN is_change > 0 AND is_notchange = 0 THEN 1
	WHEN is_change = 0 AND is_notchange > 0 THEN 0 END) AS is_change,
	SUM(CASE WHEN is_change > 0 AND is_notchange > 0 THEN 0
	WHEN is_change > 0 AND is_notchange = 0 THEN 0
	WHEN is_change = 0 AND is_notchange > 0 THEN 1 END) AS is_notchange
FROM orders 
GROUP BY customer_id;

## 8. How many pizzas were delivered that had both exclusions and extras?
WITH orders AS
(
SELECT co.order_id, 
	pizza_id,
	customer_id,
	COALESCE(CASE WHEN (exclusions IS NOT NULL OR exclusions <> "") AND (extras IS NOT NULL OR extras <> "") THEN 1 END,0) AS is_excl_ext
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL)

SELECT SUM(is_excl_ext) AS total_pizzas
FROM orders;

## 9. What was the total volume of pizzas ordered for each hour of the day?
SELECT DATE_FORMAT(co.`order_time`,'%H') AS hours,
	COUNT(pizza_id) AS total_pizza
FROM customer_orders AS co
GROUP BY DATE_FORMAT(co.`order_time`,'%H')
ORDER BY hours;

## 10. What was the volume of orders for each day of the week?
SELECT DATE_FORMAT(co.`order_time`,'%a') AS days,
	COUNT(pizza_id) AS total_pizza
FROM customer_orders AS co
GROUP BY DATE_FORMAT(co.`order_time`,'%a');