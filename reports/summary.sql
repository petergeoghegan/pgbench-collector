select
  set,
  scale,
  pg_size_pretty(avg(dbsize)::int8) as db_size,
  clients,
  rate_limit,
  round(avg(tps)) as tps,
  round(1000 * avg(avg_latency))/1000 as avg_latency,
  round(1000 * avg(percentile_90_latency))/1000 as "90%<",
  round(1000 * avg(percentile_99_latency))/1000 as "99%<",
  to_char(avg(end_time -  start_time),'hh24:mi:ss') as runtime
from tests
group by set,scale,clients,rate_limit
order by set,scale,clients,rate_limit;
