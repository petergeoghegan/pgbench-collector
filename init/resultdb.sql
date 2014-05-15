BEGIN;

DROP TABLE IF EXISTS testset CASCADE;
CREATE TABLE testset(
  set serial PRIMARY KEY,
  info text UNIQUE not null,
  testdb text not null,
  testuser text not null,
  testhost text not null,
  testport int not null,
  settings text
);

DROP TABLE IF EXISTS tests CASCADE;
CREATE TABLE tests(
  test serial PRIMARY KEY,
  set int NOT NULL REFERENCES testset(set) ON DELETE CASCADE,
  scale int,
  dbsize int8,
  start_time timestamptz default now(),
  end_time timestamptz default null,
  tps decimal default 0,
  script text,
  clients int,
  workers int,
  trans int,
  avg_latency float,
  percentile_90_latency float,
  percentile_99_latency float,
  wal_written numeric,
  cleanup interval default null,
  rate_limit numeric default null
);

DROP TABLE IF EXISTS timing;
CREATE TABLE timing(
  ts timestamptz,
  filenum int,
  latency numeric(9,3),
  test int NOT NULL REFERENCES tests(test)
  );

CREATE INDEX idx_timing_test on timing(test,ts);

DROP TABLE IF EXISTS test_bgwriter;
CREATE TABLE test_bgwriter(
  test int PRIMARY KEY REFERENCES tests(test) ON DELETE CASCADE,
  checkpoints_timed bigint,
  checkpoints_req bigint,
  buffers_checkpoint bigint,
  buffers_clean bigint,
  maxwritten_clean bigint,
  buffers_backend bigint,
  buffers_alloc bigint,
  buffers_backend_fsync bigint,
  max_dirty bigint
);

DROP TABLE IF EXISTS test_dstat;
CREATE TABLE test_dstat(
  dstatid bigserial PRIMARY KEY,
  test int REFERENCES tests(test) ON DELETE CASCADE,
  taken timestamptz NOT NULL,
  cpu_perc_usr numeric,
  cpu_perc_sys numeric,
  cpu_perc_idle numeric,
  cpu_perc_wait numeric,
  cpu_perc_hiq numeric,
  cpu_perc_siq numeric,
  mem_used_bytes bigint,
  mem_buff_bytes bigint,
  mem_cache_bytes bigint,
  mem_free_bytes bigint,
  paging_pages_in bigint,
  paging_pages_out bigint,
  system_interrupts bigint,
  system_context_switches bigint,
  disk_read_ops bigint,
  disk_write_ops bigint
);

CREATE INDEX idx_test_dstat on test_dstat(test);

DROP TABLE IF EXISTS temp_test_dstat;
CREATE TABLE temp_test_dstat(
  test int REFERENCES tests(test) ON DELETE CASCADE,
  taken_since_epoch float,
  cpu_perc_usr text,
  cpu_perc_sys text,
  cpu_perc_idle text,
  cpu_perc_wait text,
  cpu_perc_hiq text,
  cpu_perc_siq text,
  mem_used_bytes text,
  mem_buff_bytes text,
  mem_cache_bytes text,
  mem_free_bytes text,
  paging_pages_in text,
  paging_pages_out text,
  system_interrupts text,
  system_context_switches text,
  disk_read_ops text,
  disk_write_ops text
);

CREATE INDEX idx_temp_test_dstat on temp_test_dstat(test);

--
-- Convert hex value to a decimal one.  It's possible to do this using
-- undocumented features of the bit type, such as:
--
--     "SELECT 'xff'::text::bit(8)::int;"
--
-- This function relies on that only to convert single hex digits, meaning
-- it handles abitrarily large numbers too.  The code is inspired by the hex
-- to decimal examples at http://postgres.cz and is not case sensitive.
--
-- Sample tests:
--
-- SELECT hex_to_dec('FF');
-- SELECT hex_to_dec('ffff');
-- SELECT hex_to_dec('FFff');
-- SELECT hex_to_dec('FFFFFFFFFFFFFFFF');
--
CREATE OR REPLACE FUNCTION hex_to_dec (text)
RETURNS numeric AS
$$
DECLARE
    r numeric;
    i int;
    digit int;
BEGIN
    r := 0;
    FOR i in 1..length($1) LOOP
        EXECUTE E'SELECT x\''||substring($1 from i for 1)|| E'\'::integer' INTO digit;
        r := r * 16 + digit;
        END LOOP;
    RETURN r;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

--
-- Process the output from pg_current_xlog_location() or
-- pg_current_xlog_insert_location() and return a WAL Logical Serial Number
-- from that information.  That represents an always incrementing offset
-- within the WAL stream, proportional to how much data has been written
-- there.  The input will look like '2/13BDE690'.
--
-- Sample use:
--
-- SELECT wal_lsn(pg_current_xlog_location());
-- SELECT wal_lsn(pg_current_xlog_insert_location());
--
-- There's no error checking here.  If you input a hex string without a "/"
-- in it, the function will process it without complaint, returning a large
-- number as if that were the left hand side of a valid pair.
--
CREATE OR REPLACE FUNCTION wal_lsn (text)
RETURNS numeric AS $$
SELECT hex_to_dec(split_part($1,'/',1)) * 16 * 1024 * 1024 * 255
    + hex_to_dec(split_part($1,'/',2));
$$ language sql;

CREATE OR REPLACE FUNCTION convert_dstats(int)
RETURNS void AS $$
insert into test_dstat(
  test,
  taken,
  cpu_perc_usr,
  cpu_perc_sys,
  cpu_perc_idle,
  cpu_perc_wait,
  cpu_perc_hiq,
  cpu_perc_siq,
  mem_used_bytes,
  mem_buff_bytes,
  mem_cache_bytes,
  mem_free_bytes,
  paging_pages_in,
  paging_pages_out,
  system_interrupts,
  system_context_switches,
  disk_read_ops,
  disk_write_ops)
select
  $1,
  to_timestamp(taken_since_epoch),
  cpu_perc_usr::numeric,
  cpu_perc_sys::numeric,
  cpu_perc_idle::numeric,
  cpu_perc_wait::numeric,
  cpu_perc_hiq::numeric,
  cpu_perc_siq::numeric,
  mem_used_bytes::numeric::bigint,
  mem_buff_bytes::numeric::bigint,
  mem_cache_bytes::numeric::bigint,
  mem_free_bytes::numeric::bigint,
  paging_pages_in::numeric::bigint,
  paging_pages_out::numeric::bigint,
  system_interrupts::numeric::bigint,
  system_context_switches::numeric::bigint,
  disk_read_ops::numeric::bigint,
  disk_write_ops::numeric::bigint
from
  temp_test_dstat where test = $1;

  delete from temp_test_dstat where test = $1;

$$ language sql;

COMMIT;
