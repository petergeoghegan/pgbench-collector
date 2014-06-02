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
  round(1000*avg_latency)/1000 AS avg_latency_per_bucket,
  round(1000*max_latency)/1000 AS max_latency,
  trans
FROM tests t JOIN testset ts on t.set = ts.set
ORDER BY set, scale, script, clients, rate_limit, test;
