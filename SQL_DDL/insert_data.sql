USE hotel_project;

-- ========================================================
-- 0. Cleanup (Optional: Clear old data to avoid duplicates)
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
SET FOREIGN_KEY_CHECKS = 1;

-- ========================================================
-- 1. Insert Membership Tiers (From Your Excel Image)
-- ========================================================
-- IDs: 1=Non-Member, 2=Member, 3=Silver, 4=Gold, 5=Diamond
INSERT INTO Membership_Tiers (tier_id, tier_name, stay_requirement, discount_rate, description) VALUES 
(1, 'Non-Member Guest', 5, 1.00, 'Guests who booked through a third party'),
(2, 'Honors - Member', 5, 0.95, 'Basic membership, discounts on bookings and free WiFi'),
(3, 'Honors - Silver', 15, 0.90, 'Extra points and bottled water upon check-in'),
(4, 'Honors - Gold', 30, 0.85, 'Enjoy space upgrades and daily dining credits'),
(5, 'Honors - Diamond', 60, 0.80, 'Top-tier membership, guaranteed executive lounge access and premium upgrades');

-- ========================================================
-- 2. Insert Room Types (From Your Excel Image)
-- ========================================================
-- IDs: 1=King, 2=2 Queen, 3=Suite, 4=Suite+Sofa, 5=Accessible
INSERT INTO Room_Types (type_id, type_name, price, description) VALUES 
(1, '1 King Bed', 135.00, 'Standard Room'),
(2, '2 Queen Beds', 143.00, 'Standard room suitable for family or friends'),
(3, '1 King Bed Suite', 165.00, 'Suite with separate living room'),
(4, '1 King Bed Suite with Sofabed', 248.00, 'Suite with King Bed and Sofa Bed'),
(5, 'Accessible Room', 135.00, 'ADA-compliant rooms with convenient amenities');

-- ========================================================
-- 3. Insert Amenities (From Your Excel Image)
-- ========================================================
-- IDs: 1=Lounge, 2=Digital Key, 3=Fitness, 4=Pool, 5=Pet
INSERT INTO Amenities (amenity_id, amenity_name, daily_capacity, is_free) VALUES 
(1, 'Executive Lounge', 50, 1),   -- Exclusive with free breakfast
(2, 'Digital Key', 1000, 1),      -- Unlock via App
(3, 'Fitness Center', 40, 1),     -- 24-hour gym
(4, 'Pool', 60, 1),               -- Indoor swimming pool
(5, 'Pet-Friendly', 20, 0);       -- Fees usually apply (so is_free = 0)

-- ========================================================
-- 4. Insert Tier Benefits (Mapping Tiers to Amenities)
-- ========================================================
-- This matches the Green rows in your Excel "Source -> Target" image.
-- Structure: (benefit_id, tier_id, amenity_id, access_level)

INSERT INTO Tier_Benefits (tier_id, amenity_id, access_level) VALUES 
-- Diamond (5) Benefits
(5, 1, 5), -- Diamond -> Executive Lounge (Value 5)
(5, 2, 5), -- Diamond -> Digital Key (Value 5)
(5, 3, 3), -- Diamond -> Fitness Center (Value 3)

-- Gold (4) Benefits
(4, 2, 5), -- Gold -> Digital Key (Value 5)
(4, 3, 3), -- Gold -> Fitness Center (Value 3)

-- Silver (3) Benefits
(3, 2, 4), -- Silver -> Digital Key (Value 4)

-- Member (2) Benefits
(2, 2, 3), -- Member -> Digital Key (Value 3)
(2, 4, 3), -- Member -> Pool (Value 3)
(2, 5, 4), -- Member -> Pet-Friendly (Value 4)

-- Non-Member (1) Benefits
(1, 4, 2), -- Non-Member -> Pool (Value 2)
(1, 5, 4); -- Non-Member -> Pet-Friendly (Value 4)

-- ========================================================
-- 5. Insert Physical Rooms
-- ========================================================
INSERT INTO Rooms (room_number, floor, status, type_id) VALUES 
(101, 1, 'Available', 1), -- 1 King Bed
(102, 1, 'Occupied', 1),
(103, 1, 'Available', 5), -- Accessible
(201, 2, 'Available', 2), -- 2 Queen Beds
(202, 2, 'Cleaning', 2),
(301, 3, 'Available', 3), -- Suite
(305, 3, 'Occupied', 3),
(401, 4, 'Available', 4), -- Suite with Sofabed
(501, 5, 'Available', 4);

-- ========================================================
-- 6. Insert Guests (With different Tiers)
-- ========================================================
INSERT INTO Guests (guest_id, first_name, last_name, email, phone, password, tier_id) VALUES 
(1, 'Xiaoyue', 'Yu', 'xiy249@pitt.edu', '', '123', 5), -- Diamond Member
(2, 'Liangyu', 'Zhao', 'liz294@pitt.edu', '', '123', 1), -- Non-Member
(3, 'Boyi', 'Sun', 'bos69@pitt.edu', '', '123', 4); -- Gold Member

-- ========================================================
-- 7. Insert Reservations (Transactions for Analysis)
-- ========================================================
-- We need these to test your Dashboard (Aggregation Functions)
INSERT INTO Reservations (guest_id, room_number, check_in_date, check_out_date, total_price, status) VALUES 
-- Completed stays (Revenue)
(1, 301, '2025-10-01', '2025-10-05', 660.00, 'Completed'), -- Diamond guest bought Suite (4 nights * 165)
(3, 201, '2025-10-10', '2025-10-12', 286.00, 'Completed'), -- Gold guest bought 2 Queen (2 nights * 143)
(2, 101, '2025-11-01', '2025-11-02', 135.00, 'Completed'), -- Non-member bought King (1 night * 135)

-- Future bookings
(1, 401, '2025-12-20', '2025-12-25', 1240.00, 'Booked'),   -- Diamond guest bought Suite+Sofa
(3, 305, '2025-11-20', '2025-11-22', 330.00, 'Booked');    -- Gold guest bought Suite

-- ========================================================
-- 8. Insert Service Usage (Optional: For advanced queries)
-- ========================================================
-- Linking a specific reservation to an amenity usage
INSERT INTO Service_Usage (reservation_id, amenity_id, usage_date, quantity) VALUES 
(1, 1, '2025-10-02 09:00:00', 2), -- Guest 1 used Exec Lounge
(1, 3, '2025-10-03 18:00:00', 1), -- Guest 1 used Fitness Center
(2, 4, '2025-10-11 10:00:00', 4); -- Guest 3 used Pool (Group of 4)

-- ========================================================
-- 9. Insert Employees
-- ========================================================
INSERT INTO Employees (username, role) VALUES 
('manager', 'Manager'),
('reception', 'Receptionist');