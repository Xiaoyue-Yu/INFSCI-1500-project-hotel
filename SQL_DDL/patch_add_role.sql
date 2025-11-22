USE hotel_project;

SET SQL_SAFE_UPDATES = 0;

UPDATE Guests 
SET role = 'Admin' 
WHERE email = 'xiy249@pitt.edu';

SET SQL_SAFE_UPDATES = 1;

SELECT * FROM Guests WHERE email = 'xiy249@pitt.edu';