#!/usr/bin/python

import sys,os
from PDBpy import *

for fname in os.listdir("."):
	res = fname.split(".")
	if(len(res) > 1):
		if(res[1]=="pdb"):
			deb=fname.split(".")[0]
			x = PDB("%s.pdb" % deb, hetSkip = 1)
			x.out("%s-noHet.pdb" % deb)
