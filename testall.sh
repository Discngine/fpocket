#! /bin/sh

D=1.73
m=3.0
M=6.0
i=36
n=2
v=1000

out="perf_all_D"$D"_m"$m"_M"$M"_i"$i"_n"$n

mkdir $out
echo "== Testing Pocketpicker HOLO"

./bin/tpocket -L ../data/pp-cplx-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_pph.txt
mv stats_p.txt stats_p_pph.txt
mv stats_g_pph.txt $out
mv stats_p_pph.txt $out

echo "== Testing Pocketpicker APO"
./bin/tpocket -L ../data/pp-apo-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_ppa.txt
mv stats_p.txt stats_p_ppa.txt
mv stats_g_ppa.txt $out
mv stats_p_ppa.txt $out

echo "== Testing cheng set"
./bin/tpocket -L ../data/cheng-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_ch.txt
mv stats_p.txt stats_p_ch.txt
mv stats_g_ch.txt $out
mv stats_p_ch.txt $out

echo "== Testing astex diverse set"
./bin/tpocket -L ../data/astex-diverse-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_astex_diverse.txt
mv stats_p.txt stats_p_astex_diverse.txt
mv stats_g_astex_diverse.txt $out
mv stats_p_astex_diverse.txt $out

echo "== Testing training set"
./bin/tpocket -L ../data/train-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_train.txt
mv stats_p.txt stats_p_train.txt
mv stats_g_train.txt $out
mv stats_p_train.txt $out

echo "== Testing ccdc-clean set"
./bin/tpocket -L ../data/ccdc-clean-t.txt -D $D -m $m -M $M -i $i -n $n -v $v #-k
mv stats_g.txt stats_g_ccdc-clean.txt
mv stats_p.txt stats_p_ccdc-clean.txt
mv stats_g_ccdc-clean.txt $out
mv stats_p_ccdc-clean.txt $out

