# Relational Auction Data Architecture & ETL

## Project Overview
This project demonstrates the design and implementation of a highly structured relational database architecture built to support high velocity concurrent transactional data. The primary engineering focus was on dimensional data modeling, data governance, and backend business rule execution.

## Role & Credits
This project was developed collaboratively. As the lead data and backend engineer, my specific contributions included:
* Engineering the complex relational database schema and entity relationship diagrams.
* Developing the backend ETL business rules for automated bid ingestion and validation.
* Structuring the data governance and role based access control logic.

Team Members: Dhruv Patel (dhp91), Adithya Menon (am2998), Sai Sanapala (vs839), Ikhlas Ismale (ip294)

## Data Modeling & Architecture
To ensure data integrity and query optimization, I engineered a comprehensive Entity Relationship Diagram deployed via MySQL. 
* Core Entities: Designed normalized tables for users, items, bids, auctions, and alerts.
* Data Lineage: Established strict foreign key constraints linking bid ledgers to specific user and auction IDs to maintain flawless data provenance.
* Backend ETL & Business Rules: Engineered continuous data profiling scripts and database level triggers to handle automated bidding limits, reserve price triggers, and real time user alerts.

## Quick Start Deployment

    cd "Final Project/backend"
    ROOT_PASS='YOUR_ROOT_PASSWORD' ./setup_and_run.sh
    # Jetty serves http://localhost:8080/login.jsp

### Manual Setup Steps:

1. Create and import the dimensional schema:
    mysql -uroot -p -e "CREATE DATABASE IF NOT EXISTS auctiondb;"
    mysql -uroot -p auctiondb < sql/auctiondb.sql

2. Grant the expected application user access:
    mysql -uroot -p -e "CREATE USER IF NOT EXISTS 'buyme_app'@'localhost' IDENTIFIED BY 'StrongP@ssw0rd!'; GRANT ALL PRIVILEGES ON auctiondb.* TO 'buyme_app'@'localhost';"

3. Build and run the service:
    mvn -DskipTests package
    mvn org.eclipse.jetty:jetty-maven-plugin:11.0.15:run-war -Djetty.port=8080

## Demo Credentials & Testing

The database seeds include two active auctions, historical bids, and several auto bid watchers so you can immediately test the automated bidding flows and data validation rules.

| Role   | Username       | Password    |
|--------|----------------|-------------|
| Admin  | admin          | admin123    |
| Rep    | rep_jordan     | rep123      |
| Seller | seller_linda   | sellerpass  |
| Seller | seller_jamie   | sellerpass  |
| Buyer  | buyer_mia      | buyerpass   |
| Buyer  | buyer_liam     | buyerpass   |

## Repository Contents
* relational_schema_and_triggers.sql: The complete database architecture including automated triggers for bid validation.
* /backend/: The backend ingestion services and scripts responsible for processing concurrent user data.
* entity_relationship_diagram.pdf: The visual architectural blueprint of the database schema.
* backend_business_rules.pdf: The systematic logic and data validation requirements.
