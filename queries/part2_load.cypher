
// 1. ІНДЕКСИ
CREATE INDEX user_id   IF NOT EXISTS FOR (u:User)  ON (u.userId);
CREATE INDEX movie_id  IF NOT EXISTS FOR (m:Movie) ON (m.movieId);
CREATE INDEX genre_name IF NOT EXISTS FOR (g:Genre) ON (g.name);


// 2. ВУЗЛИ: Genre
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
WITH split(row.genres, '|') AS genreList
UNWIND genreList AS genreName
WITH trim(genreName) AS name
WHERE name <> '' AND name <> '(no genres listed)'
MERGE (:Genre {name: name});


// 3. ВУЗЛИ: Movie
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
WITH
  toInteger(row.movieId) AS movieId,
  trim(replace(row.title, ' (' + substring(row.title, size(row.title) - 5, 4) + ')', '')) AS title,
  toInteger(substring(row.title, size(row.title) - 5, 4)) AS year
MERGE (m:Movie {movieId: movieId})
SET
  m.title = title,
  m.year  = year;


// 4. ВУЗЛИ: User
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET
  u.gender = row.gender,
  u.age = toInteger(row.age),
  u.occupation = CASE toInteger(row.occupation)
    WHEN 0 THEN 'other'
    WHEN 1 THEN 'academic/educator'
    WHEN 2 THEN 'artist'
    WHEN 3 THEN 'clerical/admin'
    WHEN 4 THEN 'college/grad student'
    WHEN 5 THEN 'customer service'
    WHEN 6 THEN 'doctor/health care'
    WHEN 7 THEN 'executive/managerial'
    WHEN 8 THEN 'farmer'
    WHEN 9 THEN 'homemaker'
    WHEN 10 THEN 'K-12 student'
    WHEN 11 THEN 'lawyer'
    WHEN 12 THEN 'programmer'
    WHEN 13 THEN 'retired'
    WHEN 14 THEN 'sales/marketing'
    WHEN 15 THEN 'scientist'
    WHEN 16 THEN 'self-employed'
    WHEN 17 THEN 'technician/engineer'
    WHEN 18 THEN 'tradesman/craftsman'
    WHEN 19 THEN 'unemployed'
    WHEN 20 THEN 'writer'
    ELSE 'unknown'
  END;


// 5. РЕБРА: Movie -> Genre  (HAS_GENRE)
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MATCH (m:Movie {movieId: toInteger(row.movieId)})
WITH m, split(row.genres, '|') AS genreList
UNWIND genreList AS genreName
WITH m, trim(genreName) AS name
WHERE name <> '' AND name <> '(no genres listed)'
MATCH (g:Genre {name: name})
MERGE (m)-[:HAS_GENRE]->(g);


// 6. РЕБРА: User -> Movie  (RATED)  — через apoc.periodic.iterate
CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",

  "MATCH (u:User  {userId:  toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   MERGE (u)-[r:RATED]->(m)
   SET
     r.rating    = toFloat(row.rating),
     r.timestamp = toInteger(row.timestamp)",

  {batchSize: 10000, parallel: false}
);

// Перевірка результатів
// MATCH (u:User) RETURN count(u) AS users;
// 6040
// MATCH (m:Movie) RETURN count(m) AS movies;
// 3883
// MATCH ()-[r:RATED]->() RETURN count(r) AS ratings;
// 1000209