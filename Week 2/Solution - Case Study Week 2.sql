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
GROUP BY sd.runner_id;

# Ingredient Optimisation

## 1. What are the standard ingredients for each pizza?
WITH RECURSIVE pizza AS (
    SELECT *
      FROM pizza_recipes
    UNION ALL
    SELECT pizza_id, 
	regexp_replace(toppings, '^[^,]*,', '') AS toppings
      FROM pizza
      WHERE toppings LIKE '%,%'
),
pt AS
(
SELECT pizza_id, 
	TRIM(regexp_replace(toppings, ',.*', '')) AS toppings
FROM pizza
ORDER BY pizza_id
), 
pt_meatlovers
AS
(
SELECT pts.*
FROM pt AS pt
INNER JOIN pizza_toppings AS pts
ON pt.toppings = pts.topping_id
WHERE pizza_id = 1
),
pt_vegetarian
AS
(
SELECT pts.*
FROM pt AS pt
INNER JOIN pizza_toppings AS pts
ON pt.toppings = pts.topping_id
WHERE pizza_id = 2
)

SELECT ptm.*
FROM pt_meatlovers AS ptm
INNER JOIN pt_vegetarian AS ptv
ON ptm.topping_id = ptv.topping_id;

## 2. What was the most commonly added extra?

WITH RECURSIVE pizza AS (
	SELECT order_id,
		extras
	FROM customer_orders
	UNION ALL
	SELECT order_id, 
		regexp_replace(extras, '^[^,]*,', '') AS toppings
	FROM pizza
	WHERE extras LIKE '%,%'
)
, pt AS
(
SELECT order_id,
	TRIM(regexp_replace(extras, ',.*', '')) AS topping
FROM pizza
)
, pt_final AS
(
SELECT pts.topping_id,
	pts.topping_name,
	COUNT(topping_id) AS total,
	ROW_NUMBER() OVER(ORDER BY COUNT(topping_id) DESC) AS number
FROM pt
INNER JOIN pizza_toppings AS pts
ON pt.topping = pts.topping_id
WHERE topping IS NOT NULL OR topping <> ""
GROUP BY pts.topping_id
)

SELECT *
FROM pt_final
WHERE number = 1;

## 3. What was the most common exclusion?
WITH RECURSIVE pizza AS (
	SELECT order_id,
		exclusions
	FROM customer_orders
	UNION ALL
	SELECT order_id, 
		regexp_replace(exclusions, '^[^,]*,', '') AS toppings
	FROM pizza
	WHERE exclusions LIKE '%,%'
)
, pt AS
(
SELECT order_id,
	TRIM(regexp_replace(exclusions, ',.*', '')) AS topping
FROM pizza
)
, pt_final AS
(
SELECT pts.topping_id,
	pts.topping_name,
	COUNT(topping_id) AS total,
	ROW_NUMBER() OVER(ORDER BY COUNT(topping_id) DESC) AS number
FROM pt
INNER JOIN pizza_toppings AS pts
ON pt.topping = pts.topping_id
WHERE topping IS NOT NULL OR topping <> ""
GROUP BY pts.topping_id
)

SELECT *
FROM pt_final
WHERE number = 1;

## 4. Generate an order item for each record in the customers_orders table in the format one of the following format

### Meat Lovers
### Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
### Meat Lovers - Exclude Beef
### Meat Lovers - Extra Bacon

SELECT *, 
	CASE WHEN pizza_id = 1 AND exclusions IS NULL AND (extras IS NULL OR extras = "") THEN "Meat Lovers"
		WHEN pizza_id = 1 AND (exclusions LIKE '%4%' AND exclusions LIKE '%1%') AND (extras LIKE '%6%' AND extras LIKE '%9%') 
			THEN 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers' 
		WHEN pizza_id = 1 AND exclusions LIKE '%3%' THEN "Meat Lovers - Exclude Beef"
		WHEN pizza_id = 1 AND extras LIKE '%1%' THEN "Meat Lovers - Extra Bacon"
		ELSE "Meat Lovers" END AS order_item
FROM customer_orders;

## 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients 
### For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH RECURSIVE pizza AS (
    SELECT *
      FROM pizza_recipes
    UNION ALL
    SELECT pizza_id, 
	regexp_replace(toppings, '^[^,]*,', '') AS toppings
      FROM pizza
      WHERE toppings LIKE '%,%'
),
pt AS
(
SELECT pizza_id, 
	TRIM(regexp_replace(toppings, ',.*', '')) AS toppings
FROM pizza
ORDER BY pizza_id
),
pt_label AS
(
SELECT pt.*, 
	pts.topping_name
FROM pt AS pt
INNER JOIN pizza_toppings AS pts
ON pt.toppings = pts.topping_id
),
pizza_exclude AS (
SELECT order_id,
	exclusions
FROM customer_orders
UNION ALL
SELECT order_id,
	regexp_replace(exclusions, '^[^,]*,', '') AS toppings
FROM pizza_exclude
WHERE exclusions LIKE '%,%'
)
, pa AS
(
SELECT order_id,
	TRIM(regexp_replace(exclusions, ',.*', '')) AS topping_exclude
FROM pizza_exclude
),order_items AS
(
SELECT *, 
	CASE WHEN pizza_id = 1 AND exclusions IS NULL AND (extras IS NULL OR extras = "") THEN "Meat Lovers"
		WHEN pizza_id = 1 AND (exclusions LIKE '%4%' AND exclusions LIKE '%1%') AND (extras LIKE '%6%' AND extras LIKE '%9%') 
			THEN 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers' 
		WHEN pizza_id = 1 AND exclusions LIKE '%3%' THEN "Meat Lovers - Exclude Beef"
		WHEN pizza_id = 1 AND extras LIKE '%1%' THEN "Meat Lovers - Extra Bacon"
		ELSE "Meat Lovers" END AS order_item
FROM customer_orders
)
, final AS
(
SELECT pt_label.topping_name,
	oi.*,
	CASE WHEN topping_exclude IS NULL THEN "2x" ELSE "" END AS status_relevant
FROM pt_label
INNER JOIN order_items AS oi
ON pt_label.pizza_id = oi.pizza_id
LEFT JOIN pa 
ON pa.order_id = oi.order_id
AND pt_label.toppings = pa.topping_exclude
)

SELECT order_id,
	customer_id,
	pizza_id,
	order_item,
	GROUP_CONCAT(CONCAT(status_relevant,topping_name) 
			ORDER BY status_relevant ASC
			SEPARATOR ",") AS ingredients
FROM final
GROUP BY order_id,
	customer_id,
	pizza_id
ORDER BY order_id,
	customer_id,
	pizza_id,
	order_item ASC;

## 6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

WITH RECURSIVE pizza AS (
    SELECT *
      FROM pizza_recipes
    UNION ALL
    SELECT pizza_id, 
	regexp_replace(toppings, '^[^,]*,', '') AS toppings
      FROM pizza
      WHERE toppings LIKE '%,%'
),
pt AS
(
SELECT pizza_id, 
	TRIM(regexp_replace(toppings, ',.*', '')) AS toppings
FROM pizza
ORDER BY pizza_id
),
pt_label AS
(
SELECT pt.*, 
	pts.topping_name
FROM pt AS pt
INNER JOIN pizza_toppings AS pts
ON pt.toppings = pts.topping_id
),
pizza_exclude AS (
SELECT order_id,
	exclusions
FROM customer_orders
UNION ALL
SELECT order_id,
	regexp_replace(exclusions, '^[^,]*,', '') AS toppings
FROM pizza_exclude
WHERE exclusions LIKE '%,%'
)
, pa AS
(
SELECT order_id,
	TRIM(regexp_replace(exclusions, ',.*', '')) AS topping_exclude
FROM pizza_exclude
),
pizza_extras AS (
SELECT order_id,
	extras
FROM customer_orders
UNION ALL
SELECT order_id,
	regexp_replace(extras, '^[^,]*,', '') AS toppings
FROM pizza_extras
WHERE extras LIKE '%,%'
)
, pe AS
(
SELECT order_id,
	TRIM(regexp_replace(extras, ',.*', '')) AS topping_extras
FROM pizza_extras
),
pe_final AS
(
SELECT *
FROM pe
WHERE topping_extras IS NOT NULL OR topping_extras != ""
),
order_items AS
(
SELECT *, 
	CASE WHEN pizza_id = 1 AND exclusions IS NULL AND (extras IS NULL OR extras = "") THEN "Meat Lovers"
		WHEN pizza_id = 1 AND (exclusions LIKE '%4%' AND exclusions LIKE '%1%') AND (extras LIKE '%6%' AND extras LIKE '%9%') 
			THEN 'Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers' 
		WHEN pizza_id = 1 AND exclusions LIKE '%3%' THEN "Meat Lovers - Exclude Beef"
		WHEN pizza_id = 1 AND extras LIKE '%1%' THEN "Meat Lovers - Extra Bacon"
		ELSE "Meat Lovers" END AS order_item
FROM customer_orders
)
, 
final AS
(
SELECT pt_label.topping_name,
	pt_label.toppings,
	oi.*
FROM pt_label
INNER JOIN order_items AS oi
ON pt_label.pizza_id = oi.pizza_id
INNER JOIN pa 
ON pa.order_id = oi.order_id
AND pt_label.toppings != pa.topping_exclude
),
pefinal_final AS
(
SELECT pt_label.topping_name,
	pt_label.toppings,
	oi.*
FROM pt_label
INNER JOIN order_items AS oi
ON pt_label.pizza_id = oi.pizza_id
INNER JOIN pe_final
ON pe_final.order_id = oi.order_id
AND pt_label.toppings = pe_final.topping_extras
), 
unionall AS
(
SELECT *
FROM final
UNION ALL
SELECT *
FROM pefinal_final
)

SELECT topping_name,
	COUNT(toppings) AS total_toppings
FROM unionall
INNER JOIN runner_orders AS ro
ON unionall.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY toppings
ORDER BY total_toppings DESC;


# Pricing and Ratings

## 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT SUM(CASE WHEN co.pizza_id = 1 THEN 10 ELSE 12 END) AS total_money
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL;

## 2. What if there was an additional $1 charge for any pizza extras?

WITH RECURSIVE pizza AS (
	SELECT order_id,
		pizza_id,
		extras
	FROM customer_orders
	UNION ALL
	SELECT order_id, 
		pizza_id,
		regexp_replace(extras, '^[^,]*,', '') AS toppings
	FROM pizza
	WHERE extras LIKE '%,%'
)
, pt AS
(
SELECT order_id,
	pizza_id,
	TRIM(regexp_replace(extras, ',.*', '')) AS topping
FROM pizza
),
tm AS
(
SELECT SUM(CASE WHEN co.pizza_id = 1 THEN 10 ELSE 12 END) AS total_money
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
)

SELECT COUNT(*) * 1 + (SELECT total_money FROM tm) AS total_money
FROM pt
WHERE topping IS NOT NULL OR topping != "";

## 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
##	how would you design an additional table for this new dataset - 
## 	generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

CREATE TABLE rating_table (
	order_id INT PRIMARY KEY,
	rating TINYINT
);

INSERT INTO rating_table(order_id, rating)
SELECT co.order_id,
	FLOOR( RAND() * (5-1) + 1) AS random_rating
FROM customer_orders AS co
GROUP BY co.order_id;

## 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries? 

#    customer_id
#    order_id
#    runner_id
#    rating
#    order_time
#    pickup_time
#    Time between order and pickup
#    Delivery duration
#    Average speed
#    Total number of pizzas

SELECT co.`customer_id`, 
	co.`order_id`,
	ro.`runner_id`,
	rt.`rating`,
	co.`order_time`,
	ro.`pickup_time`,
	TIMESTAMPDIFF(MINUTE, co.`order_time`, ro.`pickup_time`) AS time_order_pickup,
	ro.`duration`,
	ROUND(ro.`distance` / (ro.duration/60),0) AS avg_speed,
	COUNT(co.pizza_id) AS total_pizza
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
INNER JOIN rating_table AS rt
ON rt.`order_id` = co.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
GROUP BY co.order_id;

## 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - 
## 	how much money does Pizza Runner have left over after these deliveries?

WITH pizza_prices AS
(
SELECT SUM(CASE WHEN co.pizza_id = 1 THEN 10 ELSE 12 END) AS total_money
FROM customer_orders AS co
INNER JOIN runner_orders AS ro
ON co.`order_id` = ro.`order_id`
WHERE ro.`pickup_time` IS NOT NULL
),
distance AS
(
SELECT SUM(ro.distance * 0.3) AS distance_money
FROM runner_orders AS ro
WHERE ro.distance IS NOT NULL
)

SELECT total_money - (SELECT distance_money FROM distance) AS leftover_money 
FROM pizza_prices;