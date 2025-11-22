USE hotel_project;

ALTER TABLE Employees ADD COLUMN password VARCHAR(255) DEFAULT '123';

INSERT INTO Employees (username, role, password) 
VALUES ('admin_xiaoyue', 'Manager', '123');

-- ALTER TABLE Guests DROP COLUMN role;