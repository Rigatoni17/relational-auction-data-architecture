-- Auction & Bidding schema for Part 2 + Part 3
DROP DATABASE IF EXISTS auctiondb;
CREATE DATABASE auctiondb CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE auctiondb;

SET time_zone = '+00:00';

CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(120),
    role ENUM('buyer','seller','admin','rep') NOT NULL DEFAULT 'buyer',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE items (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    seller_id INT NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    category VARCHAR(60),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE auctions (
    auction_id INT AUTO_INCREMENT PRIMARY KEY,
    item_id INT NOT NULL,
    seller_id INT NOT NULL,
    start_price DECIMAL(10,2) NOT NULL,
    reserve_price DECIMAL(10,2),
    current_price DECIMAL(10,2) NOT NULL,
    high_bidder_id INT NULL,
    winner_id INT NULL,
    closing_price DECIMAL(10,2),
    status ENUM('active','closed') DEFAULT 'active',
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    reserve_met TINYINT(1) DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (item_id) REFERENCES items(item_id) ON DELETE CASCADE,
    FOREIGN KEY (seller_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (high_bidder_id) REFERENCES users(user_id),
    FOREIGN KEY (winner_id) REFERENCES users(user_id)
);

CREATE TABLE bids (
    bid_id INT AUTO_INCREMENT PRIMARY KEY,
    auction_id INT NOT NULL,
    user_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    is_auto TINYINT(1) DEFAULT 0,
    bid_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (auction_id) REFERENCES auctions(auction_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE auto_bids (
    auto_bid_id INT AUTO_INCREMENT PRIMARY KEY,
    auction_id INT NOT NULL,
    user_id INT NOT NULL,
    max_amount DECIMAL(10,2) NOT NULL,
    increment DECIMAL(10,2) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_auto_bid (auction_id, user_id),
    FOREIGN KEY (auction_id) REFERENCES auctions(auction_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Part 3 tables
CREATE TABLE alerts (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    keyword VARCHAR(120),
    category VARCHAR(60),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE questions (
    question_id INT AUTO_INCREMENT PRIMARY KEY,
    auction_id INT NOT NULL,
    user_id INT NOT NULL,
    question_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (auction_id) REFERENCES auctions(auction_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE
);

CREATE TABLE answers (
    answer_id INT AUTO_INCREMENT PRIMARY KEY,
    question_id INT NOT NULL,
    rep_id INT NOT NULL,
    answer_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (question_id) REFERENCES questions(question_id) ON DELETE CASCADE,
    FOREIGN KEY (rep_id) REFERENCES users(user_id) ON DELETE CASCADE
);

-- Seed data
INSERT INTO users (username, password_hash, email, role) VALUES
('admin', 'admin123', 'admin@example.com', 'admin'),
('rep_jordan', 'rep123', 'rep@buyme.com', 'rep'),
('seller_linda', 'sellerpass', 'linda@sellers.com', 'seller'),
('seller_jamie', 'sellerpass', 'jamie@sellers.com', 'seller'),
('buyer_mia', 'buyerpass', 'mia@buyers.com', 'buyer'),
('buyer_liam', 'buyerpass', 'liam@buyers.com', 'buyer');

INSERT INTO items (seller_id, name, description, category) VALUES
(3, 'Vintage Camera', 'Fully working 35mm camera with leather case.', 'Electronics'),
(3, 'Gaming Laptop', 'RTX 4070, 16GB RAM, 1TB SSD. Still under warranty.', 'Computers'),
(4, 'Electric Guitar', 'Maple neck, fresh strings, includes gig bag.', 'Music');

INSERT INTO auctions (item_id, seller_id, start_price, reserve_price, current_price,
                      start_time, end_time, status) VALUES
(1, 3, 120.00, 150.00, 120.00, NOW(), DATE_ADD(NOW(), INTERVAL 5 DAY), 'active'),
(2, 3, 900.00, 1100.00, 900.00, NOW(), DATE_ADD(NOW(), INTERVAL 3 DAY), 'active'),
(3, 4, 550.00, 620.00, 550.00, NOW(), DATE_ADD(NOW(), INTERVAL 1 DAY), 'active');

-- Seed bids so there is history to inspect
INSERT INTO bids (auction_id, user_id, amount, is_auto) VALUES
(1, 5, 125.00, 0),
(1, 6, 135.00, 0),
(2, 5, 910.00, 0);

UPDATE auctions SET current_price = 135.00, high_bidder_id = 6 WHERE auction_id = 1;
UPDATE auctions SET current_price = 910.00, high_bidder_id = 5 WHERE auction_id = 2;

-- Auto bidding watchers for demo
INSERT INTO auto_bids (auction_id, user_id, max_amount, increment) VALUES
(1, 5, 200.00, 5.00),
(1, 6, 220.00, 10.00),
(2, 6, 1200.00, 20.00);
