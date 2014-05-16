About pgbench-collector
=======================

pgbench-collector is a fork of Greg Smith's pgbench-tools.

pgbench-collector is intended to fully decouple collection of pgbench
statistics from their presentation. Like pgbench-tools, it automates running
PostgreSQL's built-in pgbench tool in a useful way.  It will run some number of
database sizes (the database scale) and various concurrent client count
combinations. Scale/client runs with some common characteristic--perhaps one
configuration of the postgresql.conf--can be organized into a "set" of runs.
The program graphs transaction rate during each test, latency, and comparisons
between test sets.

All statistics and instrumentation is stored in a PostgreSQL database. It is possible to:

* Collect a variety of lower-level statistics using the dstat utility. These
  can be compared with each other, and with pgbench results. Rich graphs can be
  produced with GnuPlot.

* Fully re-generate reports with all details intact without access to anything
  more than the results database. This includes dstat instrumentation.

* Product normalized graphs, to make graph comparisons across tests and runs as
  simple and intuitive as possible.

* Explicitly specify which test set is being run. This allows benchmarks of
  multiple PostgreSQL systems to be collected in parallel, since each server
  running pgbench-collector may indicate that it is running a particular
  testset.

pgbench-collector setup
=======================

* Create databases for your test and for the results::

    createdb results
    createdb pgbench

  *  Both databases can be the same, but there may be more shared_buffers
     cache churn in that case. Some amount of cache disruption
     is unavoidable unless the result database is remote, because
     of the OS cache. The recommended and default configuration
     is to have a pgbench database and a results database. This also
     keeps the size of the result dataset from being included in the
     total database size figure recorded by the test.

* Initialize the results database by executing::

    psql -f init/resultdb.sql -d results

  Make sure to reference the correct database.

* You need to create a test set with a description::

    ./newset 'Initial Config'

  Note that each set must have a unique description. Running the "newset"
  utility without any parameters will list all of the existing test sets.

Running tests
=============

* Edit the config file to reference the test and results database, as
  well as list the test you want to run. The default test is a
  SELECT-only one that runs for 60 seconds.

* Execute::

    ./runset

  In order to execute all the tests. Sometimes, it can be useful to specify the
  set number of the set being run.  This allows benchmarks of multiple systems
  to be run in parallel (with a single results database)::


    ./runset 5

   (An individual test set's set number is determined at the ./newset stage).
   Naturally, since the whole point of specifying a set number to runset is to
   avoid the assumption that the maximum set number is "current"/your set
   number, care should be taken in specifying a set number.  Since the testset
   table (the table that newset populates, in the results database) has a
   unique constraint on its "info" (description) column, the appropriate set
   number can reliably be obtained by querying the table (e.g. "SELECT set from
   testset where info = 'mytestinfo'").

Results
=======

* You can check results even as the test is running with::

    cd reports/
    psql -d results -f report.sql

  This is unlikely to disrupt the test results very much unless you've
  run an enormous number of tests already.

* Other useful reports you can run include:
   * fastest.sql
   * summary.sql
   * bufreport.sql
   * bufsummary.sql

* Once the tests are done, the results/ directory will include
  a HTML subdirectory for each test giving its results,
  in addition to the summary information in the results database.

* The results directory will also include its own index HTML file (named
  index.html) that shows summary information and plots for all the tests.

* If you manually adjust the test result database, you can then manually
  regenerate both the summary graphs, and individual test graphs by running::

    ./webreport

Restarting from scratch
=======================

As a convenience, pgbench-collector makes available a script for automatically
restarting from scratch::

    ./cleanreport

Test sets comparison
====================

Runs of pgbench via the runset command are oriented into test sets. Each test
that is run will be put into the same test set until you tell the program to
switch to a new set. Each test set is assigned both a serial number and a test
description.

New test sets are added like this::

  psql -d results -c "INSERT INTO testset (info) VALUES ('set name')"

pgbench-collector aims to help compare multiple setups of PostgreSQL. That
might be different configuration parameters, different source code builds, or
even different versions of the database. One reason the results database is
separate from the test database is that you can use a shared results database
across multiple test sets, while connecting to multiple test database
installations.

The graphs generated by the program will generate a seperate graph pair for
each test set, as well as a master graph pair that compares all of them.  The
graphs in each pair are graphed with a X axis of client count and database
scale (size) respectively. The idea is that you might see whether an alternate
configuration is better at handling larger data sets, or if it handles
concurrency at high client counts better.

Note that all of the built-in pgbench tests use very simple queries. The
results can be useful for testing read-only SELECT scaling at different client
counts. They can also be useful for seeing how the server handles heavy write
volume. But none of these results will change if you alter server parameters
that adjust query execution, such as work_mem or effective_cache_size.  Many of
the useful PostgreSQL parameters to tune for better query execution on larger
servers in particular fall into this category. You will not always be able to
compare configurations usefully using the built-in pgbench tests. Even for
parameters that should impact results, such as shared_buffers or
checkpoint_segments, making useful comparisons with pgbench is often difficult.

There is more information about what pgbench is useful for, as well as how to
adjust the program to get better results, in the pgbench documentation:

http://www.postgresql.org/docs/current/static/pgbench.html

Version compatibility
=====================

The default configuration now aims to support the pgbench that ships with
PostgreSQL 8.4 and later versions, which uses names such as "pgbench_accounts"
for its tables. Earlier versions are unsupported.

Multiple worker support
-----------------------

Starting in PostgreSQL 9.0, pgbench allows splitting up the work pgbench does
into multiple worker threads or processes (which depends on whether the
database client libraries haves been compiled with thread-safe behavior or
not).

This feature is extremely valuable, as it's likely to give at least a 15%
speedup on common hardware. And it can more than double throughput on
operating systems that are particularly hostile to running the pgbench client.
One known source of this problem is Linux kernels using the Completely Fair
Scheduler introduced in 2.6.23, which does not schedule the pgbench program
very well when it's connecting to the database using the default method,
Unix-domain sockets.

(Note that pgbench-collector doesn't suffer greatly from this problem itself,
as it connects over TCP/IP using the "-H" parameter. Manual pgbench runs that
do not specify a host, and therefore connect via a local socket can be
extremely slow on recent Linux kernels.)

Taking advantage of this feature is done in pgbench-collector by increasing the
MAX_WORKERS setting in the configuration file. It takes the value of `nproc`
by default, or where that isn't available (typically on systems without a
recent version of GNU coreutils), the default can be set to blank, which avoids
using this feature altogether -- thereby remaining compatible not only with
systems lacking the nproc program, but also with PostgreSQL/pgbench versions
before this capability was added.

When using multiple workers, each must be allocated an equal number of clients.
That means that client counts that are not a multiple of the worker count will
result in pgbench not running at all.

Accordingly, if you set MAX_WORKERS to a number to enable this capability,
pgbench-collector picks the maximum integer of that value or lower that the
client count is evenly divisible by. For example, if MAX_WORKERS is 4, running
with 8 clients will use 4 workers, while 9 clients will shift downward to 3
workers as the best option.

A reasonable setting for MAX_WORKERS is the number of physical cores on the
server, typically giving best performance. And when using this feature, it's
better to tweak test client counts toward ones that are divisible by as many
factors as possible. For example, if you wanted approximately 15 clients, it
would be best to use 16, allowing worker counts of 2, 4, or 8, all likely to
match common core counts. Second choice would be 14, compatible with 2 workers.
Third is 15, which would allow 3 workers--not improving upon a single worker on
common dual-core systems. The worst choices would be 13 or 17 clients, which
are prime and therefore cannot be usefully allocated more than one worker on
common hardware.

Removing bad tests
==================

If you abort a test in the middle of running, you will end up with a bad test
result entry in the results database. These will look odd and can distort
averages and graphs. Ideally you would erase the entire directory each of those
bad test results are in, followed by removing their main entry from the results
database. You can do that at a shell prompt like this::

  cd results/
  psql -d results -At -c "SELECT test FROM tests WHERE tps=0" | xargs rm -rf
  psql -d results -At -c "DELETE FROM tests WHERE tps=0"
  ./webreport


Known issues
============

* On Solaris, where the benchwarmer script calls tail it may need to use
  /usr/xpg4/bin/tail instead

Contact
=======

The project is hosted at https://github.com/petergeoghegan/pgbench-collector

If you have any hints, changes or improvements, please contact:

 * Peter Geoghegan peter.geoghegan86@gmail.com

Credits
=======

Portions Copyright (c) 2007-2013, Gregory Smith

Portions Copyright (c) 2014, Peter Geoghegan

See COPYRIGHT file for full license details and HISTORY for a list of
other contributors to the program.
