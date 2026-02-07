# Customer Support Data Engineering & Analytics Project

## Project Overview
This project transforms a raw, flat dataset of 8,000+ customer support records into a normalized, relational database. The goal was to clean "dirty" synthetic data, establish data integrity through a multi-table schema, and derive actionable business insights regarding product reliability and support team performance.

## Tech Stack
Language: SQL (MySQL)
Tooling: MySQL Workbench
Concepts: Data Normalization, Data Validation, Views, Conditional Aggregation, Joins, and Time-Series Analysis.

## Database Architecture
The original dataset was normalized into three distinct tables to reduce redundancy and improve query performance:

Customers: Stores unique customer profiles.
Products: A lookup table for all items in the catalog.
Tickets: The central fact table containing ticket details, status, and timestamps.

## Data Cleaning & Quality Assurance
A major challenge identified during the EDA (Exploratory Data Analysis) phase was Chronological Inconsistency. Approximately 1,300 records contained resolution timestamps that occurred before the initial response.

Solution: Instead of deleting data, I implemented a Reporting View (v_cleaned_tickets). This view uses CASE logic to nullify invalid timestamps on the fly, ensuring that performance metrics remain accurate without destroying the source data.

## Key Insights
Product Reliability: Identified specific hardware products with disproportionately high "Critical" ticket rates.
Channel Performance: Discovered that despite higher volumes, specific digital channels (like Chat) maintained faster resolution times and higher satisfaction scores than Email.
Operational Flaws: Revealed gaps where "Low" priority tickets were occasionally being resolved faster than "Critical" tickets, suggesting a need for better queue management.

## How to Use
Database Setup: Open the customer_support_tickets_analysis.sql file in MySQL Workbench.
Execution: Run the script in its entirety. It is designed to:
- Create the Schema: Sets up the Customers, Products, and Tickets tables.
- Data Ingestion: Migrates data from the raw staging table into the normalized relational structure.
- Logic Layer: Automatically creates the v_cleaned_tickets view to handle data anomalies.
Reporting: Once the script finishes, you can run any of the 10 analysis queries located at the bottom of the file to see the results instantly.
