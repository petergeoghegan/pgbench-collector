SELECT
  t.set,
  ts.info,
  scale,
  test,
  script,
  clients,
  rate_limit,
  start_time,
  workers,
  round(tps) AS tps,
  round(1000*avg_latency)/1000 AS avg_latency,
  round(1000*percentile_90_latency)/1000 AS "90%<",
  round(1000*percentile_99_latency)/1000 AS "99%<",
  trans
FROM tests t JOIN testset ts on t.set = ts.set
ORDER BY set, scale, script, clients, rate_limit, test;
