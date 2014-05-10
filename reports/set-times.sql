/*
 * Show the total runtime for each set.  Normally used to help estimate how
 * long it might be until a running set finishes, in cases where you've run
 * a similar one already.
 */
select
set,
max(end_time) - min(start_time) as elapsed
from tests
group by set
order by set;
