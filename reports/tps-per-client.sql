select
  t.set,
  ts.info,
  scale,
  pg_size_pretty(avg(dbsize)::int8) as db_size,
  pg_size_pretty(avg(dbsize)::int8 / scale) as size_per_scale,
  clients,
  round(avg(tps)) as tps,
  round(avg(tps)/clients) as tps_per_client,
  to_char(avg(end_time -  start_time), 'hh24:mi:ss') as runtime
from tests t
join testset ts on t.set = ts.set
group by t.set, ts.info, scale, clients
order by t.set, scale, clients;
