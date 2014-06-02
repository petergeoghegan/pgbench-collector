select
  set,
  scale,
  pg_size_pretty(avg(dbsize)::int8) as db_size,
  clients,
  rate_limit,
  round(avg(tps)) as tps,
  round(1000 * avg(avg_latency))/1000 as avg_latency,
  round(1000 * max(max_latency))/1000 as max_latency,
  to_char(avg(end_time -  start_time),'hh24:mi:ss') as runtime
from tests
group by set,scale,clients,rate_limit
order by set,scale,clients,rate_limit;
