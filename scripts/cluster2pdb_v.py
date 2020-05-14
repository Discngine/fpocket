#!/usr/bin/python

import sys
import os
import re
from PDBpy import *

if __name__ == "__main__":
	regex = re.compile('noHet.pdb')
	lstf = os.listdir('.')
	for f in lstf:
		if os.path.isfile(f) and regex.search(f):
			basename = os.path.splitext(os.path.basename(f))[0]
			pdbname = str(basename)+".pdb"
			pdir = "results/"+basename+"/clusterinfo.txt"
			
			print(pdbname+" - "+pdir+"\n")

			f = open(pdir)
			lines = f.readlines()
			f.close()
			
			n = 8000
			nr = 900
			olines = []
			for l in lines:
				it = l.split()
				ol = "HETATM %4d  C   PC%s  %4d    %8.3f%8.3f%8.3f  1.00 \n" % (n, it[0],nr, float(it[1]), float(it[2]), float(it[3]))
				if n != 8000:
					if it[0] != lpn:
						nr += 1
				lpn = it[0]

				n += 1
				olines.append(ol)

			x = PDB(pdbname)
			y = PDB(olines)
			z = x+y

			outname = basename.split('-')[0]+"-PPicker.pdb"
			z.out(outname)
