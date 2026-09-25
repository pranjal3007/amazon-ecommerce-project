CREATE TABLE ecommerce_data (
    user_id VARCHAR(100),
    product_id VARCHAR(100),
    category VARCHAR(100),
    subcategory VARCHAR(100),
    brand VARCHAR(100),
    price NUMERIC(12,2),
    discount NUMERIC(5,2),
    final_price NUMERIC(12,2),
    rating NUMERIC(3,2),
    review_count NUMERIC(12,2),
    stock NUMERIC(12,2),
    seller_id VARCHAR(100),
    seller_rating NUMERIC(3,2),
    purchase_date DATE,
    shipping_time_days NUMERIC(5,2),
    location VARCHAR(100),
    device VARCHAR(50),
    payment_method VARCHAR(50),
    is_returned VARCHAR(20),
    delivery_status VARCHAR(50),
    revenue NUMERIC(14,2),
    year INT,
    month_year VARCHAR(20),
    return_status VARCHAR(30),
    delivery_delay VARCHAR(30)
);


-- 1  Find the top 5 categories with the highest total sales revenue
select category, sum(revenue) as total_revenue
from ecommerce_data
group by category
order by total_revenue desc
limit 5;

--2 Calculate the return percentage for each brand and rank them from highest to lowest.
SELECT
    is_returned,
    COUNT(*) AS count
FROM ecommerce_data
GROUP BY is_returned
ORDER BY count DESC;

SELECT
    brand,
    COUNT(*) AS total_orders,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(TRIM(is_returned)) = 'true' THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS return_percentage,
    DENSE_RANK() OVER (
        ORDER BY
            100.0 * SUM(
                CASE
                    WHEN LOWER(TRIM(is_returned)) = 'true' THEN 1
                    ELSE 0
                END
            ) / COUNT(*) DESC
    ) AS return_rank
FROM ecommerce_data
GROUP BY brand
ORDER BY return_rank;

--3 Find sellers whose average seller rating is above 4.5 but have delayed deliveries above average
SELECT
    seller_id,
    ROUND(AVG(seller_rating), 2) AS avg_seller_rating,
    COUNT(*) AS total_orders
FROM ecommerce_data
GROUP BY seller_id
HAVING AVG(seller_rating) > 4.5
ORDER BY avg_seller_rating DESC;

WITH seller_performance AS (
    SELECT
        seller_id,
        AVG(seller_rating) AS avg_seller_rating,
        COUNT(*) AS total_orders,
        100.0 * SUM(
            CASE
                WHEN LOWER(TRIM(delivery_status)) = 'delayed'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*) AS delay_percentage
    FROM ecommerce_data
    GROUP BY seller_id
)

SELECT
    seller_id,
    ROUND(avg_seller_rating, 2) AS avg_seller_rating,
    total_orders,
    ROUND(delay_percentage, 2) AS delay_percentage
FROM seller_performance
WHERE avg_seller_rating > 4.5
ORDER BY delay_percentage DESC;


-- max highest seller rating
SELECT
    MAX(avg_rating) AS highest_seller_rating
FROM (
    SELECT
        seller_id,
        AVG(seller_rating) AS avg_rating
    FROM ecommerce_data
    GROUP BY seller_id
) AS sellers;

--4  Write a query to find monthly sales growth percentage using window functions.
WITH monthly_sales AS (
    SELECT
        TO_CHAR(purchase_date, 'YYYY-MM') AS month,
        SUM(revenue) AS monthly_revenue
    FROM ecommerce_data
    GROUP BY TO_CHAR(purchase_date, 'YYYY-MM')
),

sales_with_previous AS (
    SELECT
        month,
        monthly_revenue,
        LAG(monthly_revenue) OVER (
            ORDER BY month
        ) AS previous_month_revenue
    FROM monthly_sales
)

SELECT
    month,
    ROUND(monthly_revenue, 2) AS monthly_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        100.0 * (monthly_revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS monthly_growth_percentage
FROM sales_with_previous
ORDER BY month;

--5 Find the top-selling subcategory in each category using ROW_NUMBER().
WITH subcategory_sales AS (
    SELECT
        category,
        subcategory,
        SUM(revenue) AS total_revenue
    FROM ecommerce_data
    GROUP BY category, subcategory
),

ranked_subcategories AS (
    SELECT
        category,
        subcategory,
        total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY total_revenue DESC
        ) AS rank
    FROM subcategory_sales
)

SELECT
    category,
    subcategory,
    ROUND(total_revenue, 2) AS total_revenue
FROM ranked_subcategories
WHERE rank = 1
ORDER BY total_revenue DESC;


-- 6  Identify products where stock < 50, review_count > average review_count, and rating > 4.
SELECT
    product_id,
    category,
    subcategory,
    brand,
    stock,
    review_count,
    rating,
    revenue
FROM ecommerce_data
WHERE stock < 50
  AND review_count > (
      SELECT AVG(review_count)
      FROM ecommerce_data
  )
  AND rating > 4
ORDER BY review_count DESC;

--7  Find cities with the highest average shipping time and compare their average customer ratings
SELECT
    location,
    ROUND(AVG(shipping_time_days), 2) AS avg_shipping_time,
    ROUND(AVG(rating), 2) AS avg_customer_rating,
    COUNT(*) AS total_orders
FROM ecommerce_data
GROUP BY location
ORDER BY avg_shipping_time DESC;

-- 8  Use CTEs to calculate total revenue, total returns, and average discount category-wise.
WITH category_analysis AS (
    SELECT
        category,
        SUM(revenue) AS total_revenue,
        SUM(
            CASE
                WHEN LOWER(TRIM(is_returned)) = 'true'
                THEN 1
                ELSE 0
            END
        ) AS total_returns,
        AVG(discount) AS average_discount
    FROM ecommerce_data
    GROUP BY category
)

SELECT
    category,
    ROUND(total_revenue, 2) AS total_revenue,
    total_returns,
    ROUND(average_discount, 2) AS average_discount
FROM category_analysis
ORDER BY total_revenue DESC;
)

-- 9 Find which payment method contributes the highest revenue and lowest return rate.
SELECT
    payment_method,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS total_orders,
    SUM(
        CASE
            WHEN LOWER(TRIM(is_returned)) = 'true'
            THEN 1
            ELSE 0
        END
    ) AS total_returns,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN LOWER(TRIM(is_returned)) = 'true'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS return_rate
FROM ecommerce_data
GROUP BY payment_method
ORDER BY total_revenue DESC;

-- 10  Write a query to classify sellers into Excellent, Good, Average, and Poor based on seller_rating and delivery performance
WITH seller_performance AS (
    SELECT
        seller_id,
        AVG(seller_rating) AS avg_seller_rating,
        COUNT(*) AS total_orders,
        SUM(
            CASE
                WHEN LOWER(TRIM(delivery_status)) = 'delayed'
                THEN 1
                ELSE 0
            END
        ) AS delayed_orders,
        100.0 * SUM(
            CASE
                WHEN LOWER(TRIM(delivery_status)) = 'delayed'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*) AS delay_percentage
    FROM ecommerce_data
    GROUP BY seller_id
)

SELECT
    seller_id,
    ROUND(avg_seller_rating, 2) AS avg_seller_rating,
    total_orders,
    delayed_orders,
    ROUND(delay_percentage, 2) AS delay_percentage,

    CASE
        WHEN avg_seller_rating >= 4.5
             AND delay_percentage < 10
            THEN 'Excellent'

        WHEN avg_seller_rating >= 4.0
             AND delay_percentage < 20
            THEN 'Good'

        WHEN avg_seller_rating >= 3.5
             AND delay_percentage < 30
            THEN 'Average'

        ELSE 'Poor'
    END AS seller_classification

FROM seller_performance
ORDER BY avg_seller_rating DESC;