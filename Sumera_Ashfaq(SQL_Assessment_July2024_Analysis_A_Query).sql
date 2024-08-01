--create the database
CREATE DATABASE Assessment;

--Use the created database
USE Assessment;

--create the table 
CREATE TABLE poll_table (
	user_id VARCHAR(5),   --Unique identifier for each user.
	poll_id VARCHAR(5),   --Identifier for the specific poll (if you have multiple polls).
	poll_option_id CHAR(1),   --Represents the options (A, B, C, D) for the event.
	amount DECIMAL(10, 2),   --The amount invested by the user.
	created_dt DATE    --Date when the investment was made.
);

--insert data into the table (poll_table)
INSERT INTO poll_table (user_id, poll_id, poll_option_id, amount, created_dt)
VALUES
	('id1', 'p1',	'A', '200', '2021-12-01'),
	('id2', 'p1',	'C', '250', '2021-12-01'),
	('id3', 'p1',	'A', '200', '2021-12-01'),
	('id4', 'p1',	'B', '500', '2021-12-01'),
	('id5', 'p1',	'C', '50', '2021-12-01'),
	('id6', 'p1',	'D', '500', '2021-12-01'),
	('id7', 'p1',	'C', '200', '2021-12-01'),
	('id8', 'p1',	'A', '100', '2021-12-01');

-- Verify data
SELECT * FROM poll_table;

--Calculate the total amount invested in each option
SELECT 
    poll_option_id, 
    SUM(amount) AS total_amount
FROM 
    poll_table
GROUP BY 
    poll_option_id;

--Calculate the total amount invested in the losing options (A, B, and D)
SELECT 
    SUM(amount) AS total_losing_amount
FROM 
    poll_table
WHERE 
    poll_option_id IN ('A', 'B', 'D');

--Calculate each user’s share of the winnings from option C
WITH total_investments AS (
    SELECT 
        poll_option_id, 
        SUM(amount) AS total_amount
    FROM 
        poll_table
    GROUP BY 
        poll_option_id
),  --This CTE calculates the total amount invested in each option.
losing_amount AS (
    SELECT 
        SUM(total_amount) AS total_losing_amount
    FROM 
        total_investments
    WHERE 
        poll_option_id IN ('A', 'B', 'D')
),   --This CTE calculates the total amount invested in the losing options (A, B, and D).
winning_investments AS (
    SELECT 
        user_id, 
        amount AS invested_amount,
        (SELECT total_amount FROM total_investments WHERE poll_option_id = 'C') AS total_invested_amount_c,
        (SELECT total_losing_amount FROM losing_amount) AS total_losing_amount
    FROM 
        poll_table
    WHERE 
        poll_option_id = 'C'
)   --This CTE fetches each user’s investment in the winning option (C) and calculates the total amount invested in C and the total losing amount.
SELECT 
    user_id, 
    CAST(ROUND(invested_amount + (invested_amount / total_invested_amount_c) * total_losing_amount, 0) AS INT) AS returns
FROM 
    winning_investments;  --This part calculates each user's returns by adding their original investment and their proportional share of the total losing amount.


--Summary:
--Calculate the total investments in each poll option.
--Determine the total amount invested in losing options (A, B, D).
--Compute each user's returns by adding their original investment in option C and their proportionate share of the total amount invested in the losing options.