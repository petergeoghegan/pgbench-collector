select
  t.set,
  ts.info as set_info,
  scale,
  t.test,
  clients,
  round(tps) as tps,
  checkpoints_timed + checkpoints_req as chkpts,
  buffers_checkpoint as buf_check,
  buffers_clean as buf_clean,
  buffers_backend as buf_backend,
  buffers_alloc as buf_alloc,
  buffers_backend_fsync as backend_sync
from test_bgwriter bgw
right join tests t on t.test = bgw.test
join testset ts on ts.set = t.set
order by scale, t.set, clients, test;
