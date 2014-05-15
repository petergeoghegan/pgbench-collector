select
  set,
  info,
  script,
  scale,
  clients,
  workers,
  round(tps) as tps
from
(
  select
    t.set, info, script, scale, clients, workers, max(tps) as tps
  from tests t join testset ts on t.set = ts.set
  group by t.set, info, script, scale, clients, workers
) as grouped
order by tps desc limit 20;
