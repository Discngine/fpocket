#! /bin/sh

D=1.73
m=3.0
M=6.0
i=36
n=2
out="desc_all_D"$D"_m"$m"_M"$M"_i"$i"_n"$n

mkdir $out

echo "== Describing training set"
./bin/dpocket -f data/train-d.txt -D $D -m $m -M $M -i $i -n $n
mv dpout_fpocketnp.txt dpout_fpocketnp_train.txt
mv dpout_fpocketp.txt dpout_fpocketp_train.txt
mv dpout_fpocket*_train.txt $out

cat $out/dpout_fpocketp_train.txt > $out/all_train.txt
awk 'NR > 1' $out/dpout_fpocketnp_train.txt >> $out/all_train.txt
sed 's/[ ]\{1,100\}/;/g' $out/all_train.txt > $out/all_train.csv

