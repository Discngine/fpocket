#!/bin/sh

python doCleanPDBs.py 
ls -1 *.pdb | grep -v "Het" | cut -f1 -d"." > ids.lst

mv ppicket-frame.tzd ppicket-frame.pml

for i in `cat ids.lst`
do
echo $i
export theExpr="s/FRAME/$i/g"
echo $theExpr
cat ppicket-frame.pml | sed $theExpr > $i.pml
done

mv ppicket-frame.pml ppicket-frame.tzd

ls *.pml -1 | xargs -n 1 -P 4 pymol
