
// 5.1 PageRank
// Крок 1: матеріалізуємо ребра фільм-фільм через спільних користувачів
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 4 AND r2.rating >= 4 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: створюємо проєкцію на основі матеріалізованих ребер
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: викоикаємо PageRank алгоритм щоб визначити найвагоміші фільми
CALL gds.pageRank.stream('movieGraph', {
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).title AS name, score
ORDER BY score DESC;


// Крок 4: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph');
MATCH ()-[co:CO_RATED]-() DELETE co;



// 5.2 Louvain
// Крок 1: матеріалізуємо ребра користувач-користувач через спільні фільми (оцінка 5)
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating > 4 AND r2.rating > 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: виконуємо Louvain алгоритм щоб виявити спільноти
CALL gds.louvain.write('userSimilarity', {
  relationshipWeightProperty: 'weight',
  writeProperty: 'community'
})
YIELD communityCount, modularity, modularities;


// Крок 4: Визначення 10 найбільших кластерів
MATCH (u:User)
WHERE u.community IS NOT NULL
RETURN u.community AS communityId, count(u) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 10;

// Крок 5: Визначення топ-3 жанрів для кожної спільноти
MATCH (u:User)-[r:RATED]->(m:Movie)-[:HAS_GENRE]->(g:Genre)
WHERE r.rating >= 4 AND u.community IS NOT NULL
WITH u.community AS communityId, g.name AS genre, count(*) AS genreCount
ORDER BY communityId, genreCount DESC
WITH communityId, collect({genre: genre, count: genreCount})[..3] AS topGenres
RETURN communityId, topGenres
ORDER BY communityId;

// Крок 6: видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('userSimilarity');
MATCH ()-[sim:SIMILAR]-() DELETE sim;
// or
// :auto MATCH (:User)-[sim:SIMILAR]->(:User)
// CALL {
//  WITH sim
//  DELETE sim
//} IN TRANSACTIONS OF 50000 ROWS;



// 5.3 Shortest path
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating > 4 AND r2.rating > 4 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 50000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: distance = 1 / weight, щоб більша схожість = менша відстань для Дейкстри
MATCH (u1:User)-[s:SIMILAR]-(u2:User)
WHERE s.weight > 0
SET s.distance = 1.0 / s.weight;

// Крок 3: створюємо проєкцію з полем cost
CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'distance' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 4: Шукаємо найкоротший шлях між юзерами 1 та 100
MATCH (source:User {userId: 5100}), (target:User {userId: 4169})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
  sourceNode: source,
  targetNode: target,
  relationshipWeightProperty: 'distance'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs, path
RETURN
  index,
  gds.util.asNode(sourceNode).userId AS sourceUserId,
  gds.util.asNode(targetNode).userId AS targetUserId,
  round(1.0 / totalCost) AS similarityScore,
  totalCost AS totalDistance,
  [nodeId IN nodeIds | gds.util.asNode(nodeId).userId] AS pathUserIds,
  costs,
  size(nodeIds) - 2 AS intermediateNodeCount;
// Returns:
// ╒═════╤════════════╤════════════╤═══════════════╤════════════════════╤════════════╤═══════════════════════════╤═════════════════════╕
// │index│sourceUserId│targetUserId│similarityScore│totalDistance       │pathUserIds │costs                      │intermediateNodeCount│
// ╞═════╪════════════╪════════════╪═══════════════╪════════════════════╪════════════╪═══════════════════════════╪═════════════════════╡
// │0    │5100        │4169        │223.0          │0.004484304932735426│[5100, 4169]│[0.0, 0.004484304932735426]│0                    │
// └─────┴────────────┴────────────┴───────────────┴────────────────────┴────────────┴───────────────────────────┴─────────────────────┘

// Крок 5: Очищення
CALL gds.graph.drop('userGraph');