USE hotel_project; 

INSERT INTO Membership_Tiers (tier_name, stay_requirement, discount_rate, description) 
VALUES ('Honors - Gold', 30, 0.85, 'Enjoy space upgrades and daily dining credits');

INSERT INTO Room_Types (type_name, price, description) 
VALUES ('1 King Bed Suite', 165.00, 'Suite with separate living room');

INSERT INTO Rooms (room_number, floor, status, type_id) 
VALUES (101, 1, 'Available', 1), (102, 1, 'Available', 1);

INSERT INTO Guests (first_name, last_name, email, tier_id) 
VALUES ('Xiaoyue', 'Yu', 'xiy249@pitt.edu', 1);guestsguestsguests