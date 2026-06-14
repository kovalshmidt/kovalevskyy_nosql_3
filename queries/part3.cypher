// Запит 1. Знайти всі фільми жанру «Thriller» із середнім рейтингом вище 4.0:
MATCH (g:Genre {name: "Thriller"})<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH m, avg(r.rating) AS avg_rating, count(r) AS cnt
WHERE avg_rating > 4.0 AND cnt >= 10
RETURN
  m.title      AS title,
  m.year       AS year,
  round(avg_rating * 100) / 100 AS avg_rating,
  cnt          AS total_ratings
ORDER BY avg_rating DESC, cnt DESC;


// Запит 2. Знайти користувачів, які поставили оцінку 5 більш ніж 50 фільмам:
MATCH (u:User)-[r:RATED]->(:Movie)
WHERE r.rating = 5.0
WITH u, count(r) AS fives_count
WHERE fives_count > 50
RETURN
  u.userId     AS userId,
  u.gender     AS gender,
  u.age        AS age,
  u.occupation AS occupation,
  fives_count
ORDER BY fives_count DESC;


// Запит 3. Знайти фільми, які обидва користувачі (наприклад, userId=1 і userId=2) оцінили високо (рейтинг ≥ 4):
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4.0 AND r2.rating >= 4.0
RETURN
  m.title        AS title,
  m.year         AS year,
  r1.rating      AS rating_user1,
  r2.rating      AS rating_user2
ORDER BY (r1.rating + r2.rating) DESC;


// Запит 4. Знайти жанри, чиї фільми стабільно отримують високі оцінки — середній рейтинг і кількість оцінок:
MATCH (g:Genre)<-[:HAS_GENRE]-(m:Movie)<-[r:RATED]-()
WITH g, avg(r.rating) AS avg_rating, count(r) AS cnt
WHERE cnt >= 100
RETURN
  g.name        AS genre,
  round(avg_rating * 100) / 100 AS avg_rating,
  cnt           AS total_ratings
ORDER BY avg_rating DESC;


// Запит 5. Рекомендація «користувачі зі схожими смаками також дивилися»: для заданого користувача знайти фільми, які він ще не дивився, але високо оцінили користувачі з подібними смаками:
MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 4.0
  AND r2.rating >= 4.0
  AND u1 <> u2
WITH u1, u2

MATCH (u2)-[r3:RATED]->(rec:Movie)
WHERE r3.rating >= 4.0
  AND NOT (u1)-[:RATED]->(rec)
RETURN
  rec.title                     AS recommended_title,
  rec.year                      AS year,
  count(DISTINCT u2)            AS recommended_by_users,
  round(avg(r3.rating)*100)/100 AS avg_score
ORDER BY recommended_by_users DESC, avg_score DESC
LIMIT 20;


// Запит 6. Знайти найкоротший ланцюжок зв’язку між двома користувачами
через спільні фільми:
MATCH (u1:User {userId: 1}), (u2:User {userId: 2}),
      p = shortestPath((u1)-[:RATED*..10]-(u2))
RETURN
  length(p) AS path_length,
  [node IN nodes(p) | coalesce(node.title, toString(node.userId))] AS path_nodes;
