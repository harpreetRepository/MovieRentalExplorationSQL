-- 1 : list of all the different (distinct) replacement costs of the films
Create View Distinct_Replacement_costs as
SELECT DISTINCT film.replacement_cost AS Replacement_Cost
FROM public.film
ORDER BY film.replacement_cost
;

-- From this list we can figure out the highest and lowest replacement costs and how many types of different replacement costs do we have.
Select *
from Distinct_replacement_costs;

-- 2 : Creating groups into low , medium or high replacement cost.
/*
low: 9.99 - 19.99
medium: 20.00 - 24.99
high: 25.00 - 29.99
Question: How many films have a replacement cost in the "low" group?*/
create view replacementCostGroups as
SELECT *,
       CASE
           WHEN (
               film.replacement_cost <= 19.99)
               THEN 'low'
           WHEN (
                       film.replacement_cost >= 20.00
                   AND film.replacement_cost <= 24.99)
               THEN 'medium'
           WHEN (
                       film.replacement_cost >= 25.00
                   AND film.replacement_cost <= 29.99)
               THEN 'high'
           END AS replaceCostCategory
FROM public.film;

-- counting number of films in each category

SELECT COUNT(*) filter (WHERE replacecostcategory = 'low')    AS lowreplace,
       COUNT(*) filter (WHERE replacecostcategory = 'medium') AS mediumreplace,
       COUNT(*) filter (WHERE replacecostcategory = 'high')   AS highreplace
FROM replacementCostGroups;


/* 3:Longest Film by length in drama or sports category list*/
SELECT f.title,
       f.length,
       c.name
FROM film f
         JOIN
     film_category fc
     ON
         f.film_id = fc.film_id
         JOIN
     category c
     ON
         c.category_id = fc.category_id
WHERE c.name = 'Drama'
   OR c.name = 'Sports'
order by f.length desc
limit 1;

/* 4: Overview of how many movies (titles) there are in each category (name).
*/
SELECT c.name,
       COUNT(*) AS count_category
FROM film f
         JOIN
     film_category fc
     ON
         f.film_id = fc.film_id
         JOIN
     category c
     ON
         c.category_id = fc.category_id
GROUP BY c.name
ORDER BY count_category DESC;


/* 5 : Overview of the actors' first and last names and in how many movies they appear
in.*/

SELECT a.first_name,
       a.last_name,
       COUNT(DISTINCT fa.film_id) AS countmovies
FROM actor a
         JOIN
     film_actor fa
     ON
         a.actor_id = fa.actor_id
GROUP BY a.first_name,
         a.last_name
ORDER BY countmovies DESC;

/* 6 : Overview of the addresses that are not associated to any customer.*/

SELECT a.address_id
FROM address a
WHERE a.address_id NOT IN
      (SELECT address_id
       FROM customer);

/* 7  : Overview of the cities and how much sales (sum of amount) have occurred
there.*/

SELECT c.city,
       SUM(amount) samt
FROM payment p
         JOIN
     customer cu
     ON
         p.customer_id = cu.customer_id
         JOIN
     address a
     ON
         cu.address_id = a.address_id
         JOIN
     city c
     ON
         a.city_id = c.city_id
GROUP BY c.city
ORDER BY samt DESC;

/* 8: overview of the revenue (sum of amount) grouped by a column in the format "
country, city".*/

SELECT concat(try.country, ',', c.city) AS countryCity,
       SUM(amount)                         samt
FROM payment p
         JOIN
     customer cu
     ON
         p.customer_id = cu.customer_id
         JOIN
     address a
     ON
         cu.address_id = a.address_id
         JOIN
     city c
     ON
         a.city_id = c.city_id
         JOIN
     country try
     ON
         c.country_id = try.country_id
GROUP BY try.country,
         c.city
ORDER BY samt ASC;

/* 9: A list with the average of the sales amount each staff_id has per customer.
Which staff_id makes on average more revenue per customer?
*/
WITH q1 AS
         (SELECT staff_id,
                 COUNT(DISTINCT customer_id) AS cntcust
          FROM payment
          GROUP BY staff_id)
SELECT DISTINCT (a.staff_id),
                ROUND((SUM(a.amount) over (
                    PARTITION BY
                        a.staff_id) / b.cntcust), 2) AS avgrev
FROM payment a
         JOIN
     q1 b
     ON
         a.staff_id = b.staff_id
ORDER BY avgrev DESC;

/* 10: average daily revenue of all Sundays.
*/
WITH sunAMT AS
         (SELECT DATE(payment_date),
                 SUM(amount) AS total
          FROM payment
          WHERE extract(dow FROM payment_date) = 0
          GROUP BY DATE(payment_date))
SELECT AVG(total)
FROM sunAMT;

/*11 : Create a list of movies - with their length and their replacement cost - that are longer
than the average length in each replacement cost group.
*/
WITH RC AS
         (SELECT title,
                 film.replacement_cost,
                 CASE
                     WHEN (
                         film.replacement_cost <= 19.99)
                         THEN 'low'
                     WHEN (
                                 film.replacement_cost >= 20.00
                             AND film.replacement_cost <= 24.99)
                         THEN 'medium'
                     WHEN (
                                 film.replacement_cost >= 25.00
                             AND film.replacement_cost <= 29.99)
                         THEN 'high'
                     END AS replaceCostCategory,
                 film.length
          FROM public.film)
        ,
     avg_length AS
         (SELECT title,
                 replaceCostCategory,
                 ROUND(AVG(LENGTH) over (
                     PARTITION BY
                         replaceCostCategory), 2) AS avglength,
                 LENGTH
          FROM RC)
SELECT *
FROM avg_length
WHERE LENGTH > avglength
ORDER BY LENGTH ASC;


/* 12 :  a list that shows the "average customer lifetime value" grouped by the different
districts.
Which district has the highest average customer lifetime value*/
WITH totalspent AS
         (SELECT SUM(p.amount) AS amt,
                 c.customer_id,
                 a.district
          FROM payment p
                   JOIN
               customer c
               ON
                   p.customer_id = c.customer_id
                   JOIN
               address a
               ON
                   c.address_id = a.address_id
          GROUP BY c.customer_id,
                   a.district
          ORDER BY a.district)
SELECT district,
       AVG(amt) AS avgcust
FROM totalspent
GROUP BY district
ORDER BY avgcust DESC;

/*13 : a list that shows all payments including the payment_id, amount,
and the film category (name) plus the total amount that was made in this category.
Order the results ascendingly by the category (name) and as second order criterion by the
payment_id ascendingly
What is the total revenue of the category 'Action' and what is the lowest payment_id in
that category 'Action'?*/
WITH topPerforming AS
         (SELECT p.payment_id,
                 p.amount,
                 c.name           AS category_name,
                 f.title,
                 SUM(p.amount) over (
                     PARTITION BY
                         f.title) AS filmSum
          FROM payment p
                   JOIN
               rental r
               ON
                   p.rental_id = r.rental_id
                   JOIN
               inventory i
               ON
                   r.inventory_id = i.inventory_id
                   JOIN
               film f
               ON
                   i.film_id = f.film_id
                   JOIN
               film_category fc
               ON
                   f.film_id = fc.film_id
                   JOIN
               category c
               ON
                   fc.category_id = c.category_id
          ORDER BY c.name,
                   p.payment_id)
SELECT *
FROM topPerforming
WHERE category_name = 'Animation'
ORDER BY filmsum DESC;