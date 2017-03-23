
#include "../headers/writepdb.h"
/*

## GENERAL INFORMATION
##
## FILE 					writepdb.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			02-12-08
##
## SPECIFICATIONS
##
##  Routine to write several data in the PDB/PQR format
##
## MODIFICATIONS HISTORY
##
##  02-12-08    (v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##  (v) Handle (unlakely) error when entries are actually writen (using fprinf)
##

*/

 /*
    COPYRIGHT DISCLAIMER

    Vincent Le Guilloux, Peter Schmidtke and Pierre Tuffery, hereby
	claim all copyright interest in the program “fpocket” (which
	performs protein cavity detection) written by Vincent Le Guilloux and Peter
	Schmidtke.

    Vincent Le Guilloux  01 Decembre 2012
    Peter Schmidtke      01 Decembre 2012
    Pierre Tuffery       01 Decembre 2012

    GNU GPL

    This file is part of the fpocket package.

    fpocket is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    fpocket is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with fpocket.  If not, see <http://www.gnu.org/licenses/>.

**/
 
/**
   ## FUNCTION: 
	write_pdb_atom_line
  
   ## SPECIFICATION: 
	Write an atom in the following pdb format 2.3.
	
	COLUMNS      DATA TYPE        FIELD      DEFINITION
	
	1 -  6      Record name      "ATOM    "
	7 - 11      Integer          serial     Atom serial number.
	13 - 16      Atom             name       Atom name.
	17           Character        altLoc     Alternate location indicator.
	18 - 20      Residue name     resName    Residue name.
	22           Character        chainID    Chain identifier.
	23 - 26      Integer          resSeq     Residue sequence number.
	27           AChar            iCode      Code for insertion of residues.
	31 - 38      Real(8.3)        x          Orthogonal coordinates for X in 
											 Angstroms
	39 - 46      Real(8.3)        y          Orthogonal coordinates for Y in 
											 Angstroms
	47 - 54      Real(8.3)        z          Orthogonal coordinates for Z in 
											 Angstroms
	55 - 60      Real(6.2)        occupancy  Occupancy.
	61 - 66      Real(6.2)        tempFactor Temperature factor.
	77 - 78      LString(2)       element    Element symbol, right-justified.
	79 - 80      LString(2)       charge     Charge on the atom.

  
   ## PARAMETRES:
  
   ## RETURN:
  
*/
void write_pdb_atom_line(FILE *f, const char rec_name[], int id, const char atom_name[], 
						 char alt_loc, const char res_name[], const char chain[], 
						 int res_id, const char insert, float x, float y, float z, float occ, 
						 float bfactor, int abpa, const char *symbol, int charge,float abpa_prob) 
{
	/* Example of pdb record: */
	/* Position:          1         2         3         4         5         6 */
	/* Position: 123456789012345678901234567890123456789012345678901234567890 */
	/* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */
	
	/* Position: 6         7         8 */
	/* Position: 012345678901234567890 */
	/* Record:   0 11.92           N   */

	int status = 0 ;
	char id_buf[6] = "*****",
		 res_id_buf[5] = "****",
		 charge_buf[3] = "  ";
	
	if (id < 100000) sprintf(id_buf, "%5d", id);
	else sprintf(id_buf, "%05x", id);

	if (res_id < 10000) sprintf(res_id_buf, "%4d", res_id);
	else if (res_id < 65536) sprintf(res_id_buf, "%04x", res_id);
	else sprintf(res_id_buf, "****");

	alt_loc = (alt_loc == '\0')? ' ': alt_loc;

	if(charge == -1) sprintf(charge_buf, "  ") ;
	else sprintf(charge_buf, "%2d", charge) ;

      /*status = fprintf(f, "%-6s%5s %4s%c%-4s%c%4s%c   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
 						 rec_name, id_buf, atom_name, alt_loc, res_name, chain[0], 
 						 res_id_buf, insert, x, y, z, occ, bfactor, symbol, charge_buf);*/
        
        float finalabpa=0.0;
        if(abpa) finalabpa=abpa_prob;
        
        status = fprintf(f, "%-6s%5s %4s%c%-4s%c%4s%c   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
 						 rec_name, id_buf, atom_name, alt_loc, res_name, chain[0], 
 						 res_id_buf, insert, x, y, z, finalabpa, bfactor, symbol, charge_buf);

        
	 //printf OUT (       "ATOM%7d %-5s%4s%5d    %8.3f%8.3f%8.3f  1.00%6.2f      %4s \n",
	   //$num,$atomname,$resname,$resnum,$x,$y,$z,$w,$segname);
}


/**
   ## FUNCTION: 
	write_pqr_atom_line
  
   ## SPECIFICATION: 
	Write an atom in pqr format.
	
	COLUMNS      DATA TYPE        FIELD      DEFINITION
	
	1 -  6      Record name      "ATOM    "
	7 - 11      Integer          serial     Atom serial number.
	13 - 16      Atom             name       Atom name.
	17           Character        altLoc     Alternate location indicator.
	18 - 20      Residue name     resName    Residue name.
	22           Character        chainID    Chain identifier.
	23 - 26      Integer          resSeq     Residue sequence number.
	27           AChar            iCode      Code for insertion of residues.
	31 - 38      Real(8.3)        x          Orthogonal coordinates for X in 
											 Angstroms
	39 - 46      Real(8.3)        y          Orthogonal coordinates for Y in 
											 Angstroms
	47 - 54      Real(8.3)        z          Orthogonal coordinates for Z in 
											 Angstroms
						 charge
						 vdw radius
  
   ## PARAMETRES:
  
   ## RETURN:
  
*/
void write_pqr_atom_line(FILE *f, const char *rec_name, int id, const char *atom_name, 
						 char alt_loc, const char *res_name, const char *chain, 
						 int res_id, const char insert, float x, float y, float z, float charge, 
						 float radius) 
{
	/* Example of pdb record: */
	/* Position:          1         2         3         4         5         6 */
	/* Position: 123456789012345678901234567890123456789012345678901234567890 */
	/* Record:   ATOM    145  N   VAL A  25      32.433  16.336  57.540  1.00 */
	
	/* Position: 6         7         8 */
	/* Position: 012345678901234567890 */
	/* Record:   0 11.92           N   */
	
	int status ;
 	char id_buf[7],
 		 res_id_buf[6];
/* 		 charge_buf[3] ; */
 	
 	if (id < 100000) sprintf(id_buf, "%5d", id);
 	else sprintf(id_buf, "%05x", id);

 	if (res_id < 10000) sprintf(res_id_buf, "%4d", res_id);
 	else if (res_id < 65536) sprintf(res_id_buf, "%04x", res_id);
 	
 	alt_loc = (alt_loc == '\0')? ' ': alt_loc;
 	
/* 	if(charge == -1) { 
 		charge_buf[0] = charge_buf[1] = ' ' ;
 		charge_buf[2] = '\0' ;
 	}
 	else sprintf(charge_buf, "%2d", charge) ;
*/ 	
 	status = fprintf(f, "%-6s%5s %4s%c%-4s%c%4s%c   %8.3f%8.3f%8.3f  %6.2f   %6.2f\n",
 						 rec_name, id_buf, atom_name, alt_loc, res_name, chain[0], 
 						 res_id_buf, insert, x, y, z, charge,radius) ;
}

