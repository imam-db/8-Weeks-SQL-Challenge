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

# Runner and customer experience

## 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT WEEK(runners.`registration_date`) AS weeks,COUNT(runner_id) AS total_runners
FROM runners 
GROUP BY WEEK(runners.`registration_date`);

## 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH pickup_time
AS
(
SELECT co.`order_id`,
	ro.`runner_id`,
	TIMESTAMPDIFF(MINUTE, co.`order_time`, ro.`pickup_time`) AS runner_arrive
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
GROUP BY co.`order_id`
)

SELECT pt.runner_id, 
	AVG(runner_arrive) AS runner_arrive
FROM pickup_time AS pt
GROUP BY pt.runner_id;

## 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
-- Yes there is relationship, order with 1 pizza on average take 12 minutes, order with 2 pizza take 18 minutes and 3 pizza take 29 minutes
WITH pickup_time
AS
(
SELECT co.`order_id`,
	ro.`runner_id`,
	TIMESTAMPDIFF(MINUTE, co.`order_time`, ro.`pickup_time`) AS runner_arrive,
	COUNT(co.pizza_id) AS total_pizza
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
GROUP BY co.`order_id`
)

SELECT total_pizza,
	AVG(runner_arrive) AS avg_preptime
FROM pickup_time
GROUP BY total_pizza;

## 4. What was the average distance travelled for each customer?
WITH pickup_time
AS
(
SELECT co.`order_id`,
	ro.`runner_id`,
	co.`customer_id`,
	distance,
	COUNT(co.pizza_id) AS total_pizza
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
GROUP BY co.`order_id`
)

SELECT customer_id,
	AVG(distance) AS avg_distance
FROM pickup_time
GROUP BY customer_id;

## 5. What was the difference between the longest and shortest delivery times for all orders?
WITH pickup_time
AS
(
SELECT co.`order_id`,
	ro.`runner_id`,
	TIMESTAMPDIFF(MINUTE, co.`order_time`, ro.`pickup_time`) AS runner_arrive,
	COUNT(co.pizza_id) AS total_pizza
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
GROUP BY co.`order_id`
)

SELECT MAX(runner_arrive) AS longest,
	MIN(runner_arrive) AS shortest,
	MAX(runner_arrive) - MIN(runner_arrive) AS difference
FROM pickup_time;

## 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT ro.`runner_id`, 
	ROUND(AVG(ro.`distance` / (ro.duration/60)),2) AS avg_speed
FROM `runner_orders` AS ro
GROUP BY ro.`runner_id`;

## 7. What is the successful delivery percentage for each runner?
WITH successful_delivery AS
(
SELECT ro.`runner_id`,
	CASE WHEN ro.pickup_time IS NULL THEN 0 ELSE 1 END AS is_success
FROM runner_orders AS ro)

SELECT sd.runner_id,
	ROUND(AVG(is_success)*100,0) AS delivery_percentage
FROM successful_delivery AS sd
GROUP BY sd.runner_id