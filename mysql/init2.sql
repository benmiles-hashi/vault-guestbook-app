-- mysql/init.sql
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE IF NOT EXISTS items (
  id   INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL
);

-- ensure exactly one row
INSERT INTO items (id, name)
  VALUES (1,'★ demo item ★')
  ON DUPLICATE KEY UPDATE name='★ demo item ★';
