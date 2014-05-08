set term svg enhanced mouse size 800,600
set terminal svg size 800,600
set output "3d.svg"
set title "pgbench transactions/sec"
set ylabel "Scaling factor"
set yrange [*:*] reverse
set xlabel "Clients"
set zlabel "TPS"
set dgrid3d 30,30
set hidden3d
splot "3d.txt" u 2:1:3 with lines
