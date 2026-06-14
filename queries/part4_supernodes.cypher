
// Супервузли серед User. Хто виставив найбільше оцінок?

MATCH (u:User)
WITH u, count { (u)-[:RATED]->() } AS degree
WHERE degree > 500
RETURN
  u.userId     AS userId,
  u.gender     AS gender,
  u.age        AS age,
  u.occupation AS occupation,
  degree       AS rated_count
ORDER BY degree DESC
LIMIT 20;


// Супервузли серед Movie. Які фільми отримали найбільше оцінок?

MATCH (m:Movie)
WITH m, count { ()-[:RATED]->(m) } AS degree
WHERE degree > 1000
RETURN
  m.movieId AS movieId,
  m.title   AS title,
  m.year    AS year,
  degree    AS ratings_count
ORDER BY degree DESC
LIMIT 20;


// Супервузли серед Genre. Скільки фільмів у кожному жанрі?

MATCH (g:Genre)
WITH g, count { ()<-[:HAS_GENRE]-(g) } AS degree
RETURN
  g.name  AS genre,
  degree  AS movie_count
ORDER BY degree DESC;
