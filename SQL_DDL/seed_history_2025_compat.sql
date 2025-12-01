USE hotel_project;

DROP TEMPORARY TABLE IF EXISTS tmp_d10a;
CREATE TEMPORARY TABLE tmp_d10a (n INT PRIMARY KEY) ENGINE=MEMORY;
INSERT INTO tmp_d10a (n) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

DROP TEMPORARY TABLE IF EXISTS tmp_d10b;
CREATE TEMPORARY TABLE tmp_d10b (n INT PRIMARY KEY) ENGINE=MEMORY;
INSERT INTO tmp_d10b (n) VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9);

-- 0..19
DROP TEMPORARY TABLE IF EXISTS tmp_n20;
CREATE TEMPORARY TABLE tmp_n20 (n INT PRIMARY KEY) ENGINE=MEMORY;
INSERT INTO tmp_n20 (n)
SELECT a.n*10 + b.n
FROM tmp_d10a a JOIN tmp_d10b b ON 1=1
WHERE a.n*10 + b.n < 20;

-- 1..50
DROP TEMPORARY TABLE IF EXISTS tmp_n50;
CREATE TEMPORARY TABLE tmp_n50 (n INT PRIMARY KEY) ENGINE=MEMORY;
INSERT INTO tmp_n50 (n)
SELECT a.n*10 + b.n + 1
FROM tmp_d10a a JOIN tmp_d10b b ON 1=1
WHERE a.n*10 + b.n + 1 <= 50;


DROP TEMPORARY TABLE IF EXISTS tmp_tiers;
CREATE TEMPORARY TABLE tmp_tiers (
  rn INT AUTO_INCREMENT PRIMARY KEY,
  tier_id INT NOT NULL,
  discount_rate DECIMAL(6,2) NULL
) ENGINE=MEMORY;

INSERT INTO tmp_tiers (tier_id, discount_rate)
SELECT tier_id, discount_rate
FROM Membership_Tiers
ORDER BY discount_rate DESC, tier_id;

SET @tier_count := (SELECT COUNT(*) FROM tmp_tiers);


INSERT INTO Guests (first_name,last_name,email,phone,password,tier_id,role)
SELECT
  CONCAT('Hist', LPAD(t.n,2,'0')) AS first_name,
  'User' AS last_name,
  CONCAT('hist_', LPAD(t.n,2,'0'), '@example.com') AS email,
  '000-000-0000' AS phone,
  NULL AS password,
  (SELECT tier_id FROM tmp_tiers tt WHERE tt.rn = ((t.n - 1) % @tier_count) + 1) AS tier_id,
  'Guest' AS role
FROM tmp_n50 t
LEFT JOIN Guests g ON g.email = CONCAT('hist_', LPAD(t.n,2,'0'), '@example.com')
WHERE g.guest_id IS NULL;


DROP TEMPORARY TABLE IF EXISTS tmp_guest_pool;
CREATE TEMPORARY TABLE tmp_guest_pool (
  rn INT AUTO_INCREMENT PRIMARY KEY,
  guest_id INT NOT NULL,
  tier_id INT NOT NULL
) ENGINE=MEMORY;

INSERT INTO tmp_guest_pool (guest_id, tier_id)
SELECT guest_id, tier_id
FROM Guests
WHERE email LIKE 'hist_%@example.com'
ORDER BY guest_id;

SET @gp_count := (SELECT COUNT(*) FROM tmp_guest_pool);


DROP TEMPORARY TABLE IF EXISTS tmp_types;
CREATE TEMPORARY TABLE tmp_types (
  rn INT AUTO_INCREMENT PRIMARY KEY,
  type_id INT NOT NULL,
  price DECIMAL(10,2) NULL
) ENGINE=MEMORY;

INSERT INTO tmp_types (type_id, price)
SELECT type_id, price FROM Room_Types ORDER BY type_id;

SET @type_count := (SELECT COUNT(*) FROM tmp_types);


INSERT IGNORE INTO Rooms (room_number, floor, status, type_id)
SELECT
  5000 + t.type_id*10 + k.n AS room_number,
  50 + t.type_id AS floor,
  'Available' AS status,
  t.type_id
FROM tmp_types t
JOIN (SELECT 1 n UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) k ON 1=1;



-- 2025-01
SET @mon := 1;  SET @offset := 0;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT
  gp.guest_id,
  (5000 + tt.type_id*10 + ((n.n % 4) + 1)) AS room_number,
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d') AS ci,
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY) AS co,
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2) AS total_price,
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-02
SET @mon := 2;  SET @offset := 20;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-03
SET @mon := 3;  SET @offset := 40;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-04
SET @mon := 4;  SET @offset := 60;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-05
SET @mon := 5;  SET @offset := 80;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-06
SET @mon := 6;  SET @offset := 100;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-07
SET @mon := 7;  SET @offset := 120;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-08
SET @mon := 8;  SET @offset := 140;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-09
SET @mon := 9;  SET @offset := 160;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-10
SET @mon := 10; SET @offset := 180;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;

-- 2025-11
SET @mon := 11; SET @offset := 200;
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status)
SELECT gp.guest_id,(5000 + tt.type_id*10 + ((n.n % 4) + 1)),
  STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'),
  DATE_ADD(STR_TO_DATE(CONCAT('2025-', LPAD(@mon,2,'0'), '-', LPAD(CASE WHEN n.n < 10 THEN 1 + 2*n.n ELSE 2 + 2*(n.n-10) END, 2, '0')), '%Y-%m-%d'), INTERVAL ((n.n % 3)+1) DAY),
  ROUND(tt.price * ((n.n % 3)+1) *
        (CASE WHEN mt.discount_rate <= 0.3 THEN 1 - mt.discount_rate ELSE mt.discount_rate END), 2),
  'Completed'
FROM tmp_n20 n
JOIN tmp_guest_pool gp ON gp.rn = ((n.n + @offset) % @gp_count) + 1
JOIN tmp_types tt ON tt.rn = ((n.n % @type_count) + 1)
JOIN Membership_Tiers mt ON mt.tier_id = gp.tier_id;


SELECT DATE_FORMAT(check_out_date,'%Y-%m') ym, COUNT(*) cnt, ROUND(SUM(total_price),2) revenue
FROM Reservations
WHERE status='Completed' AND check_out_date BETWEEN '2025-01-01' AND '2025-11-30'
GROUP BY ym ORDER BY ym;
