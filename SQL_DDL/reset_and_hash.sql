USE hotel_project;

SET FOREIGN_KEY_CHECKS = 0;

TRUNCATE TABLE Service_Usage;
TRUNCATE TABLE Reservations;
TRUNCATE TABLE Guests;
TRUNCATE TABLE Employees;

SET SQL_SAFE_UPDATES = 0; 
UPDATE Rooms SET status = 'Available';
SET SQL_SAFE_UPDATES = 1;

INSERT INTO Employees (username, role, password) 
VALUES ('admin_xiaoyue', 'Manager', '$2b$12$Mo.isVEk5wE8IbWJ7ntDQuF2rWuOyGvUj3jXb85NKLa/upUgSv9N6'); 

SET FOREIGN_KEY_CHECKS = 1;

SELECT * FROM Rooms; 
SELECT * FROM Guests;