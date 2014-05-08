set term svg enhanced mouse size 800,600
set terminal svg
set output "clients.svg"
set mytics
set title "pgbench transactions/sec"
set grid xtics ytics mytics
set xlabel "Clients"
set ylabel "TPS"
plot \
  "clients.txt" using 1:2 axis x1y1 title 'TPS' with linespoints
