-- Report of background write effectiveness

select
  set,
  scale,
  clients,
  round(avg(tps)) as tps,
  round(avg(checkpoints_timed+checkpoints_req)) as chkpts,
  round(avg(buffers_checkpoint)) as buf_check,
  round(avg(buffers_clean)) as buf_clean,
  round(avg(buffers_backend)) as buf_backend,
  round(avg(buffers_alloc)) as buf_alloc ,
  round(avg(buffers_backend_fsync)) as backend_fsync
from test_bgwriter
right join tests on tests.test = test_bgwriter.test
group by scale, set, clients
order by scale, set, clients;
