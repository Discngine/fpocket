
#include "../headers/writepdb.h"

/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
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
        
		//printf("%s \t",chain);
        status = fprintf(f, "%-6s%5s %4s%c%-4s%s%4s%c   %8.3f%8.3f%8.3f%6.2f%6.2f          %2s%2s\n",
 						 rec_name, id_buf, atom_name, alt_loc, res_name, chain, 
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

	//printf("i%s \t",chain);
 	status = fprintf(f, "%-6s%5s %4s%c%-4s%s%4s%c   %8.3f%8.3f%8.3f  %6.2f   %6.2f\n",
 						 rec_name, id_buf, atom_name, alt_loc, res_name, chain, 
 						 res_id_buf, insert, x, y, z, charge,radius) ;
}

void write_mmcif_atom_line(FILE *f, const char rec_name[], int id, const char atom_name[], 
						 char alt_loc, const char res_name[], const char chain[], 
						 int res_id, const char insert, float x, float y, float z, float occ, 
						 float bfactor, int abpa, const char *symbol, int charge,float abpa_prob) 
{
	int status = 0 ;
	char id_buf[6] = "*****",
		 res_id_buf[5] = "****",
		 charge_buf[3] = "  \0";
	
	if (id < 100000) sprintf(id_buf, "%5d", id);
	else sprintf(id_buf, "%05x", id);

	if (res_id < 10000) sprintf(res_id_buf, "%4d", res_id);
	else if (res_id < 65536) sprintf(res_id_buf, "%04x", res_id);
	else sprintf(res_id_buf, "****");

	alt_loc = (alt_loc == '\0')? ' ': alt_loc;

	if(charge == -1) sprintf(charge_buf, " 0") ;
	else sprintf(charge_buf, "%2d", charge) ;
	

	 float finalabpa=0.0;
        if(abpa) finalabpa=abpa_prob;

	status = fprintf(f,"%-6s %6s %3s %4s . %4s %3s . %s ? %8.3f%8.3f%8.3f%6.2f %2s %s\n",
						rec_name,id_buf,symbol,atom_name,res_name,chain,res_id_buf,x,y,z,occ,charge_buf,chain);	
	


	/*"ATOM %d %s %s . %s %s . %d ? %f %f %f %f %f %s\n",
            i + 1, atoms[i].name, atoms[i].type, atoms[i].resname, atoms[i].chain,
            atoms[i].resid, *x, *y, *z, atoms[i].occupancy,
            atoms[i].charge, atoms[i].chain);*/
}