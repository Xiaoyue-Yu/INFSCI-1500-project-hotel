USE hotel_project;

-- ========================================================
-- 1. Basic Configuration Data
-- ========================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE Tier_Benefits;
TRUNCATE TABLE Service_Usage;
TRUNCATE TABLE Reservations;
TRUNCATE TABLE Rooms;
TRUNCATE TABLE Guests;
TRUNCATE TABLE Amenities;
TRUNCATE TABLE Room_Types;
TRUNCATE TABLE Membership_Tiers;
TRUNCATE TABLE Employees;
SET FOREIGN_KEY_CHECKS = 1;

-- Membership Tiers
INSERT INTO Membership_Tiers (tier_id, tier_name, stay_requirement, discount_rate, description) VALUES
(1, 'Non-Member Guest', 5, 1.00, 'Guests who booked through a third party'),
(2, 'Honors - Member', 5, 0.95, 'Basic membership, discounts on bookings and free WiFi'),
(3, 'Honors - Silver', 15, 0.90, 'Extra points and bottled water upon check-in'),
(4, 'Honors - Gold', 30, 0.85, 'Enjoy space upgrades and daily dining credits'),
(5, 'Honors - Diamond', 60, 0.80, 'Top-tier membership, guaranteed executive lounge access and premium upgrades');

-- Room Types
INSERT INTO Room_Types (type_id, type_name, price, description) VALUES
(1, '1 King Bed', 135.00, 'Standard Room'),
(2, '2 Queen Beds', 143.00, 'Standard room suitable for family or friends'),
(3, '1 King Bed Suite', 165.00, 'Suite with separate living room'),
(4, '1 King Bed Suite with Sofabed', 248.00, 'Suite with King Bed and Sofa Bed'),
(5, 'Accessible Room', 135.00, 'ADA-compliant rooms with convenient amenities');

-- Amenities
INSERT INTO Amenities (amenity_id, amenity_name, daily_capacity, is_free) VALUES
(1, 'Executive Lounge', 50, 1),
(2, 'Digital Key', 1000, 1),
(3, 'Fitness Center', 40, 1),
(4, 'Pool', 60, 1),
(5, 'Pet-Friendly', 20, 0);

-- Tier Benefits
INSERT INTO Tier_Benefits (tier_id, amenity_id, access_level) VALUES
(5, 1, 5), (5, 2, 5), (5, 3, 3),
(4, 2, 5), (4, 3, 3),
(3, 2, 4),
(2, 2, 3), (2, 4, 3), (2, 5, 4),
(1, 4, 2), (1, 5, 4);

-- ========================================================
-- 2. Create Admin & Staff (With Hashed Password)
-- ========================================================
-- Password is '123' (Hashed with Bcrypt)
INSERT INTO Employees (username, role, password)
VALUES
('admin_xiaoyue', 'Manager', '123');

-- ========================================================
-- 3. Data Generation for Dashboard (History Data)
-- ========================================================

-- Generate Numbers Helper
DROP TABLE IF EXISTS tmp_nums;
CREATE TABLE tmp_nums (n INT PRIMARY KEY);
INSERT INTO tmp_nums (n) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

-- Generate 50 Guests
INSERT INTO Guests (first_name, last_name, email, phone, password, tier_id, role)
SELECT
  CONCAT('Guest', LPAD(a.n*10 + b.n, 3, '0')) AS first_name,
  'User' AS last_name,
  CONCAT('user', LPAD(a.n*10 + b.n, 3, '0'), '@example.com') AS email,
  '555-0199' AS phone,            -- Added default phone
  'default_pass' AS password,     -- Added default plain text password
  ((a.n*10 + b.n) % 5) + 1 AS tier_id,
  'Guest' AS role
FROM tmp_nums a JOIN tmp_nums b ON 1=1
WHERE a.n*10 + b.n < 50;

-- Generate Physical Rooms (Auto-generated based on types)
INSERT IGNORE INTO Rooms (room_number, floor, status, type_id)
SELECT
  (100 * floor_num.n) + room_num.n AS room_number,
  floor_num.n AS floor,
  'Available' AS status,
  ((floor_num.n + room_num.n) % 5) + 1 AS type_id
FROM
  (SELECT n+1 AS n FROM tmp_nums WHERE n < 5) AS floor_num
JOIN
  (SELECT n+1 AS n FROM tmp_nums WHERE n < 9) AS room_num
ON 1=1;

-- Generate Reservations (Past Year for Dashboard)
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT
  g.guest_id,
  r.room_number,
  DATE_ADD('2025-01-01', INTERVAL (g.guest_id * 5) DAY) AS check_in,
  DATE_ADD('2025-01-01', INTERVAL (g.guest_id * 5 + 3) DAY) AS check_out,
  rt.price * 3 AS total_price,
  'Completed'
FROM Guests g
JOIN Rooms r ON (g.guest_id % 40) + 101 = r.room_number -- Random-ish mapping
JOIN Room_Types rt ON r.type_id = rt.type_id
WHERE g.guest_id <= 40; -- Create 40 past reservations

-- Cleanup
DROP TABLE IF EXISTS tmp_nums;

-- Final Check
SELECT 'Data Seeded Successfully' AS Status;
SELECT COUNT(*) AS Total_Guests FROM Guests;
SELECT COUNT(*) AS Total_Reservations FROM Reservations;