-- Creating database:
CREATE DATABASE CustomerSupportDB;
USE CustomerSupportDB;

-- Creating Raw  data table:
CREATE TABLE raw_tickets (
    ticket_id TEXT,
    customer_name TEXT,
    customer_email TEXT,
    customer_age TEXT,
    customer_gender TEXT,
    product_purchased TEXT,
    date_of_purchase TEXT,
    ticket_type TEXT,
    ticket_subject TEXT,
    ticket_description TEXT,
    ticket_status TEXT,
    resolution TEXT,
    ticket_priority TEXT,
    ticket_channel TEXT,
    first_response_time TEXT,
    time_to_resolution TEXT,
    customer_satisfaction TEXT
);


-- Loading csv file into raw data table:
SET GLOBAL local_infile = 1;
LOAD DATA INFILE 'D:/DataScience/Database And SQL/Cutomer Support Project/customer_support_tickets.csv'
INTO TABLE raw_tickets
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT * FROM raw_tickets LIMIT 10;

SELECT COUNT(*) FROM raw_tickets;

-- 1. Creating Customers Table
CREATE TABLE Customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255) UNIQUE,
    age INT,
    gender VARCHAR(50)
);

-- 2. Creating Products Table
CREATE TABLE Products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) UNIQUE
);

-- 3. Creating Tickets Table
CREATE TABLE Tickets (
    ticket_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    ticket_type VARCHAR(100),
    priority VARCHAR(50),
    status VARCHAR(50),
    channel VARCHAR(50),
    first_response_time DATETIME,
    resolved_at DATETIME,
    satisfaction_score DECIMAL(3,2),
    purchase_date DATE,
    FOREIGN KEY (customer_id) REFERENCES Customers(customer_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);


-- Inserting Customers data into Customers table from raw data table:
INSERT INTO Customers (name, email, age, gender)
SELECT DISTINCT 
    customer_name, 
    customer_email, 
    CAST(customer_age AS UNSIGNED), 
    customer_gender
FROM raw_tickets;


-- Inserting Products data into Customers table from raw data table:
INSERT IGNORE INTO Products (product_name)
SELECT DISTINCT TRIM(product_purchased)
FROM raw_tickets
WHERE product_purchased IS NOT NULL;


-- Inserting Tickets data into Customers table from raw data table:
INSERT INTO Tickets (ticket_id, customer_id, product_id, ticket_type, priority, status, channel, purchase_date, first_response_time, resolved_at, satisfaction_score)
SELECT 
    t.ticket_id, 
    c.customer_id, 
    p.product_id, 
    t.ticket_type, 
    t.ticket_priority, 
    t.ticket_status, 
    t.ticket_channel,
    STR_TO_DATE(t.date_of_purchase, '%Y-%m-%d'),
    STR_TO_DATE(NULLIF(t.first_response_time, ''), '%Y-%m-%d %H:%i:%s'),
    STR_TO_DATE(NULLIF(t.time_to_resolution, ''), '%Y-%m-%d %H:%i:%s'),
    CAST(NULLIF(t.customer_satisfaction, '') AS DECIMAL(3,2))
FROM raw_tickets t
JOIN Customers c ON t.customer_email = c.email
JOIN Products p ON t.product_purchased = p.product_name;



--- Data Quality and Integrity Check --- 


-- Checking that all data from raw table moved to normalized table (Row counts).
SELECT
	(SELECT COUNT(*) FROM raw_tickets) AS raw_count,
    (SELECT COUNT(*) FROM tickets) AS normalized_count,
    (SELECT COUNT(*) FROM raw_tickets) - (SELECT COUNT(*) FROM tickets) AS missing_count;


-- cheking for critical null values (Making sure all tickets belongs to customer and product).
SELECT 
	COUNT(CASE WHEN customer_id IS NULL THEN 1 END) AS null_customer_id,
	COUNT(CASE WHEN product_id IS NULL THEN 1 END) AS null_product_id
FROM tickets;


-- Validation of status-based field completeness.
SELECT 
    status,
    COUNT(*) AS total_tickets,
    COUNT(first_response_time) AS has_response_time,
    COUNT(resolved_at) AS has_resolution_time,
    COUNT(satisfaction_score) AS has_score
FROM Tickets
GROUP BY status;


-- Making sure that min and max satisfaction score is in range(1-5).
SELECT 
	MIN(satisfaction_score) AS min_score,
    MAX(satisfaction_score) AS max_score
from tickets
WHERE satisfaction_score IS NOT NULL;


-- Making sure that the first_response_time is greater than resolved_at time (Logic: A ticket cannot be resolved before first response).
SELECT COUNT(*) AS invalid_resolution_cases
FROM Tickets
WHERE resolved_at < first_response_time;


-- The query revealed 1,339 invalid resolution cases. Instead of deleting this data, I created a view to handle the errors properly during analysis while keeping our database records complete.
CREATE OR REPLACE VIEW v_cleaned_tickets AS
SELECT 
    ticket_id,
    customer_id,
    product_id,
    ticket_type,
    priority,
    status,
    first_response_time,
    CASE 
        WHEN resolved_at < first_response_time THEN NULL 
        ELSE resolved_at 
    END AS resolved_at,
    satisfaction_score,
    channel
FROM Tickets;


-- This should now return 0
SELECT COUNT(*) AS invalid_resolution_cases
FROM v_cleaned_tickets 
WHERE resolved_at < first_response_time;



--- Product Analysis ---


-- Ranking products by total support ticket count.
SELECT p.product_name, COUNT(v.ticket_id) AS total_tickets
FROM v_cleaned_tickets v
JOIN Products p ON v.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_tickets DESC;


-- Identifying products with the highest volume of 'Critical' tickets.
SELECT p.product_name, COUNT(v.ticket_id) AS critical_count
FROM v_cleaned_tickets v
JOIN Products p ON v.product_id = p.product_id
WHERE v.priority = 'Critical'
GROUP BY p.product_name
ORDER BY critical_count DESC;


-- Comparing average customer satisfaction ratings per product.
SELECT p.product_name, ROUND(AVG(v.satisfaction_score), 2) AS avg_satisfaction
FROM v_cleaned_tickets v
JOIN Products p ON v.product_id = p.product_id
WHERE v.satisfaction_score IS NOT NULL
GROUP BY p.product_name
ORDER BY avg_satisfaction DESC;



--- Team Performance Analysis ---


-- Measuring average resolution hours across support platforms.
SELECT channel, ROUND(AVG(TIMESTAMPDIFF(HOUR, first_response_time, resolved_at)), 1) AS avg_hours_to_resolve
FROM v_cleaned_tickets
WHERE status = 'Closed' AND resolved_at IS NOT NULL
GROUP BY channel
ORDER BY avg_hours_to_resolve ASC;


-- Analyzing resolution rates across different ticket categories.
SELECT ticket_type, 
       COUNT(*) AS total,
       SUM(CASE WHEN status = 'Closed' THEN 1 ELSE 0 END) AS resolved,
       ROUND(SUM(CASE WHEN status = 'Closed' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS resolution_rate_pct
FROM v_cleaned_tickets
GROUP BY ticket_type;


-- Calculating the percentage distribution of ticket priorities.
SELECT priority, COUNT(*) AS ticket_count,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM v_cleaned_tickets), 2) AS pct_of_total
FROM v_cleaned_tickets
GROUP BY priority;



--- Customer Insights ---


-- Identifying "Power Users" with multiple support engagements.
SELECT c.email, COUNT(v.ticket_id) AS ticket_count
FROM v_cleaned_tickets v
JOIN Customers c ON v.customer_id = c.customer_id
GROUP BY c.email
HAVING ticket_count > 1
ORDER BY ticket_count DESC;


-- Evaluating if satisfaction scores vary by gender.
SELECT c.gender, ROUND(AVG(v.satisfaction_score), 2) AS avg_satisfaction
FROM v_cleaned_tickets v
JOIN Customers c ON v.customer_id = c.customer_id
WHERE v.satisfaction_score IS NOT NULL
GROUP BY c.gender;


-- Segmenting customer satisfaction across different age brackets. 
SELECT 
    CASE 
        WHEN c.age < 30 THEN 'Under 30'
        WHEN c.age BETWEEN 30 AND 50 THEN '30-50'
        ELSE 'Over 50'
    END AS age_group,
    ROUND(AVG(v.satisfaction_score), 2) AS avg_satisfaction
FROM v_cleaned_tickets v
JOIN Customers c ON v.customer_id = c.customer_id
WHERE v.satisfaction_score IS NOT NULL
GROUP BY age_group
ORDER BY avg_satisfaction DESC;


-- Correlating resolution speed with final customer satisfaction scores.
SELECT 
    CASE 
        WHEN TIMESTAMPDIFF(HOUR, first_response_time, resolved_at) <= 24 THEN 'Under 24 Hours'
        WHEN TIMESTAMPDIFF(HOUR, first_response_time, resolved_at) BETWEEN 24 AND 72 THEN '1-3 Days'
        ELSE 'Over 3 Days'
    END AS resolution_speed,
    ROUND(AVG(satisfaction_score), 2) AS avg_score
FROM v_cleaned_tickets
WHERE status = 'Closed' AND resolved_at IS NOT NULL
GROUP BY resolution_speed
ORDER BY avg_score DESC;

