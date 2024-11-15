-- ORDER ANAYSIS

-- 1. Analyze order dsitrubition based on months.

SELECT to_char(order_approved_at,'YYYY, Month') as year_and_month,
COUNT(order_id) as order_amount
FROM orders
WHERE order_approved_at is not null
GROUP BY 1
ORDER BY 1 DESC


-- 2. Analyze order amount based on order status and months.  

SELECT to_char(order_approved_at,'YYYY, Month') as year_and_month,
order_status,
COUNT(order_id) as order_amount
FROM orders
WHERE order_approved_at is not null
GROUP BY 1,2
ORDER BY 1,2


-- 3.Analze order amounts based on category. Which categories do stand out? 

WITH category as
(
SELECT oi.order_id, oi.product_id, order_approved_at, product_category_name
FROM order_items as oi
LEFT JOIN orders as o
ON oi.order_id=o.order_id
LEFT JOIN products as p
ON oi.product_id=p.product_id
)
SELECT product_category_name as category,
COUNT(DISTINCT order_id) as order_amount
FROM category
WHERE product_category_name is not NULL
GROUP BY 1


-- Adding months to analyze importanat days (new year, valentines day, etc.)

WITH category as
(
SELECT oi.order_id, oi.product_id, order_approved_at, product_category_name
FROM order_items as oi
LEFT JOIN orders as o
ON oi.order_id=o.order_id
LEFT JOIN products as p
ON oi.product_id=p.product_id
)
SELECT to_char(order_approved_at,'Month') as month,
product_category_name as category,
COUNT(DISTINCT order_id) as order_amount
FROM category
WHERE product_category_name is not NULL AND order_approved_at is not NULL
GROUP BY 1,2


-- 4.Anayze order amounts based on week days and month days.

WITH ordered_days as
(
SELECT to_char(order_purchase_timestamp,'day') as day_of_week,
COUNT(order_id) as order_amount
FROM orders
WHERE order_purchase_timestamp is not NULL
GROUP BY 1
)
SELECT * FROM ordered_days
ORDER BY 
CASE WHEN day_of_week= 'monday   ' THEN 1
     WHEN day_of_week= 'tuesday  ' THEN 2
	 WHEN day_of_week= 'wednesday' THEN 3
	 WHEN day_of_week= 'thursday ' THEN 4
	 WHEN day_of_week= 'friday   ' THEN 5
	 WHEN day_of_week= 'saturday ' THEN 6
	 WHEN day_of_week= 'sunday   ' THEN 7
	 END

-- Month days

SELECT EXTRACT(DAY FROM order_purchase_timestamp) as day_of_month,
COUNT(order_id) as order_amount
FROM orders
WHERE order_purchase_timestamp is not NULL
GROUP BY 1


-- CUSTOMER ANALYSIS

-- 1. In which cities do customers shop more? 

WITH final_results as
(
WITH final_table as
(
WITH orders_per_city as
(
WITH cities as
(
SELECT o.order_id, c.customer_unique_id, customer_city
FROM orders as o
LEFT JOIN customers as c
ON o.customer_id=c.customer_id
WHERE order_status not in ('canceled','unavailable')
)
SELECT customer_unique_id, customer_city, 
COUNT(order_id) as order_amount
FROM cities
GROUP BY 1,2
ORDER BY 1
)	
SELECT customer_unique_id, customer_city, order_amount,
ROW_NUMBER() OVER(PARTITION BY customer_unique_id ORDER BY order_amount desc),
SUM(order_amount) OVER(PARTITION BY customer_unique_id) as sum_order
FROM orders_per_city
)
SELECT customer_unique_id, customer_city,sum_order
FROM final_table
WHERE row_number=1
ORDER BY 3 desc
)
SELECT customer_city, 
SUM(sum_order) as overall_orders
FROM final_results
GROUP BY 1
ORDER BY 2 desc


-- SELLER ANALSIS
 
-- 1. Analyze fastes sellers. (Sellers with more than 10 orders were evaluated)

WITH speed as
(
WITH delivery_times as
(
SELECT DISTINCT o.order_id, o_i.seller_id, order_purchase_timestamp, order_delivered_customer_date
FROM orders as o
LEFT JOIN order_items as o_i
ON o.order_id=o_i.order_id
WHERE o_i.seller_id is not null
AND order_status = 'delivered'
)
SELECT *, 
order_delivered_customer_date-order_purchase_timestamp as deliver_time
FROM delivery_times 
WHERE order_purchase_timestamp is not null
AND order_delivered_customer_date is not null
)
SELECT seller_id,
COUNT(order_id) as order_amount,
AVG(deliver_time) as avg_deliver_time
FROM speed
GROUP BY 1
HAVING COUNT(order_id) >10
ORDER BY 3
LIMIT 5


-- Score and comments analysis of fastest sellers.

WITH reviews as
(
WITH speed as
(
WITH delivery_times as
(
SELECT DISTINCT o.order_id, o_i.seller_id, order_purchase_timestamp, order_delivered_customer_date
FROM orders as o
LEFT JOIN order_items as o_i
ON o.order_id=o_i.order_id
WHERE o_i.seller_id is not null
AND order_status = 'delivered'
)
SELECT *, 
order_delivered_customer_date-order_purchase_timestamp as deliver_time
FROM delivery_times 
WHERE order_purchase_timestamp is not null
AND order_delivered_customer_date is not null
)
SELECT seller_id,
COUNT(order_id) as order_amount,
AVG(deliver_time) as avg_deliver_time
FROM speed
GROUP BY 1
HAVING COUNT(order_id) >10
ORDER BY 3
LIMIT 5
)
SELECT or_r.order_id, seller_id, review_score, 
AVG(review_score) OVER(PARTITION BY seller_id),
review_comment_message
FROM order_reviews as or_r
LEFT JOIN order_items or_i
ON or_r.order_id=or_i.order_id
WHERE seller_id in (SELECT seller_id FROM reviews)


-- 2.Which sellers sell products from more categories? 

WITH category as
(
SELECT o.order_id, seller_id, product_category_name
FROM orders as o
LEFT JOIN order_items as o_i
ON o.order_id=o_i.order_id
LEFT JOIN products as p
ON o_i.product_id=p.product_id
WHERE o_i.seller_id is not null
AND order_status not in ('canceled','unavailable')
)
SELECT seller_id, 
COUNT(DISTINCT product_category_name) as category_types,
COUNT(DISTINCT order_id) as order_amount
FROM category 
GROUP BY 1
ORDER BY 2 DESC


-- PAYMENT ANALSIS

-- 1. In which region do users with the highest number of installments live? (Considered customers who have more than 12 installments)

SELECT o.order_id, payment_installments, customer_city,
COUNT(customer_city) OVER(PARTITION BY customer_city) as city_amount
FROM orders as o
LEFT JOIN customers as c
ON o.customer_id=c.customer_id
LEFT JOIN order_payments as p
ON o.order_id=p.order_id
WHERE payment_installments >12
ORDER BY 4 DESC


-- 2. Calculate the number of successful orders and total successful payment amount according to payment type. Rank them in order from the most used payment type to the least.

WITH payment_table as
(
SELECT p.order_id, payment_type, payment_value
FROM order_payments as p
LEFT JOIN orders as o
ON p.order_id=o.order_id
WHERE order_status not in ('canceled','unavailable')
)
SELECT payment_type,
COUNT(payment_type) as payment_type_amount,
COUNT(DISTINCT order_id) as order_amount,
round(SUM(payment_value)) as total_payment
FROM payment_table
GROUP BY 1
ORDER BY 2 DESC


-- 3. Make a category-based analysis of orders paid in one shot and in installments. In which categories is payment in installments used most?

WITH final_analysis as
(
WITH payment_analysis as
(
SELECT product_category_name, payment_installments 
FROM order_payments as p
LEFT JOIN order_items as o_i
ON p.order_id=o_i.order_id
LEFT JOIN products as pr
ON o_i.product_id=pr.product_id
WHERE payment_installments>=1
)
SELECT product_category_name,
CASE WHEN payment_installments=1 THEN 'single payment'
ELSE 'installment' END AS single_or_inst
FROM payment_analysis
)
SELECT product_category_name, single_or_inst, 
COUNT (single_or_inst)
FROM final_analysis
WHERE product_category_name is not null
GROUP BY 1,2
ORDER BY 2, 3 DESC



