# fpocket User Manual
fpocket is a protein pocket prediction algorithm. Given a PDB protein structure it enables the user to identify potent binding sites. Based on Voronoi tessellation, this algorithm is very fast and particularly well suited for large scale protein binding pocket screenings and development of scoring functions for binding pocket characterization. Now, fpocket also allows pocket detection on MD trajectories and assessment of the volume & the druggability of a binding site. Last, also interaction energy calculations are now possible using fpocket & mdpocket.

## Notes
1.	This program uses output coming from Qhull. Qhull is integrated within fpocket. More information about Qhull can be found in the paper : Barber, C.B., Dobkin, D.P., and Huhdanpaa, H.T., "The Quickhull algorithm for convex hulls," ACM Trans. on Mathematical Software, 22(4):469-483, Dec 1996, http://www.qhull.org
2.	Part of this software includes code based on external code developed by the Theoretical and Computational Biophysics Group in the Beckman Institute for Advanced Science and Technology at the University of Illinois at Urbana-Champaign. The PDB parser of the Molfile Plugin of VMD were modified for the purposes of fpocket's PDB parsing. Furthermore, the molfile plugin allows now mdpocket to analyse various MD trajectory formats.
3.	Within the whole documentation code and output from computer programs are represented and formatted in the following way : `ls -1 > out.txt`
4.	This documentation, as well as the software itself, is under steady change. The fpocket developer team tries to provide a useful and easy to understand documentation, a thing that completely lacks in most of scientific open source softwares nowadays. In our opinion an open source software is useless without documentation of the source code on one side and documentation of the software on the other. Thus, we welcome every suggestion to improve this documentation in terms of accuracy, clarity and completeness.

## Contents
* [Introduction](INTRODUCTION.md)

* [Installation](INSTALLATION.md)

* [Getting Started & Advanced Features](GETTINGSTARTED.md)
