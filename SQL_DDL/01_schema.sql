-- ======================================================
-- Panther Hotel Management System - Final Schema
-- File: 01_schema.sql
-- Description: Creates the database and all tables in 3NF.
-- ======================================================

DROP SCHEMA IF EXISTS `hotel_project`;
CREATE SCHEMA IF NOT EXISTS `hotel_project` DEFAULT CHARACTER SET utf8;
USE `hotel_project`;

-- 1. Membership_Tiers
CREATE TABLE IF NOT EXISTS Membership_Tiers (
  tier_id INT NOT NULL AUTO_INCREMENT,
  tier_name VARCHAR(45) NULL,
  stay_requirement INT NULL,
  discount_rate DECIMAL(3,2) NULL,
  description VARCHAR(255) NULL,
  PRIMARY KEY (tier_id)
) ENGINE = InnoDB;

-- 2. Room_Types
CREATE TABLE IF NOT EXISTS Room_Types (
  type_id INT NOT NULL AUTO_INCREMENT,
  type_name VARCHAR(45) NOT NULL,
  price DECIMAL(10,2) NULL,
  description VARCHAR(255) NULL,
  PRIMARY KEY (type_id)
) ENGINE = InnoDB;

-- 3. Rooms
CREATE TABLE IF NOT EXISTS Rooms (
  room_number INT NOT NULL,
  floor INT NULL,
  status VARCHAR(20) NULL,
  type_id INT NOT NULL,
  PRIMARY KEY (room_number),
  CONSTRAINT fk_Rooms_Room_Types
    FOREIGN KEY (type_id)
    REFERENCES Room_Types (type_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB;

-- 4. Guests
CREATE TABLE IF NOT EXISTS Guests (
  guest_id INT NOT NULL AUTO_INCREMENT,
  first_name VARCHAR(45) NOT NULL,
  last_name VARCHAR(45) NOT NULL,
  email VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NULL,
  password VARCHAR(255) NULL,       -- Added for security
  role VARCHAR(20) DEFAULT 'Guest', -- Added for RBAC
  tier_id INT NOT NULL,
  PRIMARY KEY (guest_id),
  CONSTRAINT fk_Guests_Membership_Tiers1
    FOREIGN KEY (tier_id)
    REFERENCES Membership_Tiers (tier_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB;

-- 5. Reservations
CREATE TABLE IF NOT EXISTS Reservations (
  reservation_id INT NOT NULL AUTO_INCREMENT,
  check_in_date DATE NOT NULL,
  check_out_date DATE NOT NULL,
  total_price DECIMAL(10,2) NULL,
  status VARCHAR(20) NULL,
  guest_id INT NOT NULL,
  room_number INT NOT NULL,
  PRIMARY KEY (reservation_id),
  CONSTRAINT fk_Reservations_Guests1
    FOREIGN KEY (guest_id)
    REFERENCES Guests (guest_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT fk_Reservations_Rooms1
    FOREIGN KEY (room_number)
    REFERENCES Rooms (room_number)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB;

-- 6. Amenities
CREATE TABLE IF NOT EXISTS Amenities (
  amenity_id INT NOT NULL AUTO_INCREMENT,
  amenity_name VARCHAR(45) NOT NULL,
  daily_capacity INT NULL,
  is_free TINYINT(1) NULL,
  PRIMARY KEY (amenity_id)
) ENGINE = InnoDB;

-- 7. Service_Usage
CREATE TABLE IF NOT EXISTS Service_Usage (
  usage_id INT NOT NULL AUTO_INCREMENT,
  usage_date DATETIME NULL,
  quantity INT NULL,
  reservation_id INT NOT NULL,
  amenity_id INT NOT NULL,
  PRIMARY KEY (usage_id),
  CONSTRAINT fk_Service_Usage_Reservations1
    FOREIGN KEY (reservation_id)
    REFERENCES Reservations (reservation_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT fk_Service_Usage_Amenities1
    FOREIGN KEY (amenity_id)
    REFERENCES Amenities (amenity_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB;

-- 8. Employees
CREATE TABLE IF NOT EXISTS Employees (
  employee_id INT NOT NULL AUTO_INCREMENT,
  username VARCHAR(45) NOT NULL,
  role VARCHAR(20) NULL,
  password VARCHAR(255) DEFAULT '123', -- Added for Admin Login
  PRIMARY KEY (employee_id)
) ENGINE = InnoDB;

-- 9. Tier_Benefits
CREATE TABLE IF NOT EXISTS Tier_Benefits (
  benefit_id INT NOT NULL AUTO_INCREMENT,
  access_level INT NULL,
  tier_id INT NOT NULL,
  amenity_id INT NOT NULL,
  PRIMARY KEY (benefit_id),
  CONSTRAINT fk_Tier_Benefits_Membership_Tiers1
    FOREIGN KEY (tier_id)
    REFERENCES Membership_Tiers (tier_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT fk_Tier_Benefits_Amenities1
    FOREIGN KEY (amenity_id)
    REFERENCES Amenities (amenity_id)
    ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB;