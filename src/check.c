
/*

## GENERAL INFORMATION
##
## FILE 					check.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			22-01-09
##
## SPECIFICATIONS
##
##	Perform basic tests for fpocket.
##
## MODIFICATIONS HISTORY
##
##	23-03-09	(v) No more test for qhull installation
##	17-03-09	(v) Additional test routines for pdb reading
##	22-01-09	(v) Created
##
## TODO or SUGGESTIONS
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

*/

/** TODO: finish documentation here.*/
#include "../headers/check.h"

/**
   ## FUNCTION:
	int main(int argc, char *argv[])
  
   ## SPECIFICATION:
	Main program for testing programm.
  
*/
int main(void)
{
	fprintf(stdout, "\n*** TESTING FPOCKET PACKAGE ***\n") ;
	int nfailure = check_fparams() ;

	nfailure += check_pdb_reader() ;
	nfailure += check_fpocket () ;
	
	fprintf(stdout, "\n*** TESTING ENDS WITH %d FAILURES ***\n", nfailure) ;
	
	return (EXIT_SUCCESS) ;
}

int check_qhull(void)
{
	fprintf(stdout, "\n--> TESTING QHULL INSTALLATION <--\n") ;
	fprintf(stdout, "    IS QVORONOI HERE ............... ") ;
	int status = system("qvoronoi > /dev/null") ;
	if (status != 0) {
		fprintf(stdout, "NO -> FPOCKET CANNOT BE TESTED\n") ;
		status = 1 ;
	}
	else{
		fprintf(stdout, "YES\n") ;
	}

	return status ;
}

/**
   ## FUNCTION:
	int check_fpocket(void)

   ## SPECIFICATION:
        function to check fpocket correct functionality

*/
int check_fpocket (void)
{
	fprintf(stdout, "\n--> TESTING FPOCKET ALGORITHM <--\n") ;
	/* Setting parameters*/
	int N = 3, i = 0, nfail = 0 ;
	char targs[][100] = {"fpocket", "-f", "sample/3LKF.pdb"} ;

	char **args = my_malloc(N*sizeof(char*)) ;
	for(i = 0 ; i < N ; i++) {
		args[i] = my_malloc(sizeof(char)*strlen(targs[i])) ;
		strcpy(args[i], targs[i]) ;
	}

	/* Checking */
	fprintf(stdout, "    PARSING COMMAND LINE ........... ") ;
	s_fparams *params = get_fpocket_args(N, args) ;
	if(!params) {
		fprintf(stdout, "FAILED \n") ;
		return 1 ;
	}
	fprintf(stdout, "OK \n") ;
	
	fprintf(stdout, "    OPENING PDB FILE................ ") ;
	s_pdb *pdb =  rpdb_open(params->pdb_path, NULL, M_DONT_KEEP_LIG, 0) ;
        s_pdb *pdb_w_lig =  rpdb_open(params->pdb_path, NULL, M_KEEP_LIG, 0) ;

	if(pdb) {
		/* Actual reading of pdb data and then calculation */
			fprintf(stdout, "OK \n") ;
			fprintf(stdout, "    READING PDB FILE ............... ") ;
			rpdb_read(pdb, NULL, M_DONT_KEEP_LIG, 0) ;
                        rpdb_read(pdb_w_lig, NULL, M_KEEP_LIG, 0) ;
			fprintf(stdout, "OK \n") ;

			fprintf(stdout, "    RUNNING FPOCKET ................ ") ;
			c_lst_pockets *pockets = search_pocket(pdb, params,pdb_w_lig);
			if(pockets && pockets->n_pockets > 0) {
				fprintf(stdout, "OK \n") ;
				fprintf(stdout, "    WRITING FPOCKET OUTPUT ......... ") ;
				write_out_fpocket(pockets, pdb, params->pdb_path);
				fprintf(stdout, "OK \n") ;
				c_lst_pocket_free(pockets) ;
			}
			else {
				nfail++ ;
				fprintf(stdout, "NO POCKET FOUND\n") ;
			}
	}
	else {
		nfail++ ;
		fprintf(stdout, "FAILED (%s) \n", params->pdb_path) ;
	}

	for(i = 0 ; i < N ; i++) my_free(args[i]) ;
	my_free(args) ;
	free_fparams(params) ;

	return nfail ;
}

/**
   ## FUNCTION:
	int check_fparams(void)

   ## SPECIFICATION:
        function to check fparams parsing

*/
int check_fparams(void)
{
	fprintf(stdout, "\n--> TESTING FPOCKET PARAMETERS <--\n") ;
	/* Setting parameters*/
	int N = 21 ;
	int i ;
	char targs[][100] = { "fpocket",
						"-f", "sample/3LKF.pdb",
						"-m", "3.1",
						"-M", "6.1",
						"-A", "2",
						"-D", "1.5",
						"-s", "4.0",
						"-n", "5",
						"-i", "1000",
						"-r", "10.0",
					    "-p", "0.0001"} ;

	char **args = my_malloc(N*sizeof(char*)) ;
	for(i = 0 ; i < N ; i++) {
		args[i] = my_malloc(sizeof(char)*strlen(targs[i])) ;
		strcpy(args[i], targs[i]) ;
	}
	/* Checking */

	fprintf(stdout, "    PARSING COMMAND LINE ........... ") ;
	s_fparams *params = get_fpocket_args(N, (char**)args) ;
	if(!params) {
		fprintf(stdout, "FAILED \n") ;
		return 1 ;
	}
	fprintf(stdout, "OK \n") ;
	
	int nfails = 0 ;
	if(strcmp(args[2], params->pdb_path) == 0)
		fprintf(stdout, "    TEST FPARAM f .................. OK \n") ;
	else {
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM f .................. FAILED \n") ;
	}
	
	if( params->asph_min_size <= atof(args[4])+0.001
		&& params->asph_min_size >= atof(args[4])-0.001)
		fprintf(stdout, "    TEST FPARAM m .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM m .................. FAILED \n") ;
	}

	if( params->asph_max_size <= atof(args[6])+0.001
		&& params->asph_max_size >= atof(args[6])-0.001)
		fprintf(stdout, "    TEST FPARAM M .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM M .................. FAILED \n") ;
	}

	if(atoi(args[8]) == params->min_apol_neigh)
		fprintf(stdout, "    TEST FPARAM A .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM A .................. FAILED \n") ;
	}

	if( atof(args[10]) <= params->clust_max_dist + 0.001 &&
		atof(args[10]) >= params->clust_max_dist - 0.001)
		fprintf(stdout, "    TEST FPARAM D .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM D .................. FAILED \n") ;
	}



	if(atoi(args[16]) == params->min_pock_nb_asph)
		fprintf(stdout, "    TEST FPARAM i .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM i .................. FAILED \n") ;
	}


	if( atof(args[20]) <= params->refine_min_apolar_asphere_prop + 0.001 &&
		atof(args[20]) >= params->refine_min_apolar_asphere_prop - 0.001)
		fprintf(stdout, "    TEST FPARAM p .................. OK \n") ;
	else{
		nfails ++ ;
		fprintf(stdout, "    TEST FPARAM p .................. FAILED \n") ;
	}
	
	for(i = 0 ; i < N ; i++) my_free(args[i]) ;
	my_free(args) ;

	return nfails ;
}

/**
   ## FUNCTION:
	int check_pdb_reader(void)

   ## SPECIFICATION:
        function to check pdb parser

*/
int check_pdb_reader(void)
{
	int nfails = 0 ;

	fprintf(stdout, "\n--> TESTING PDB READER  <--\n") ;

	/* Test some routines used by the reader */
	nfails += check_is_valid_element() ;

	/* Test several single record cases: */
/*
			"ATOM      1  N  BALA A   1      11.104   6.134  -6.504  1.00  0.00           N  ",
			"ATOM      2  CA  ALA A   1      11.639   6.071  -5.147  1.00  0.00           C-1",
			"ATOM    293 1HG  GLU A   18    -14.861  -4.847   0.361  1.00  0.00           H  ",
			"HETATM 3835 FE   HEM A   1      17.140   3.115  15.066  1.00 14.14          FE  ",
			"HETATM 8238  S   SO4 A2001      10.885 -15.746 -14.404  1.00 47.47           S  ",
			"HETATM 8239  O1  SO4 A2001      11.191 -14.833 -15.531  1.00 50.12           O  "
*/

	/*
	 * FIRST TEST
	 */

	char test_case1[] = "ATOM      1  N  BALA A   1      11.104   6.134  -6.504  1.00  0.00           N  " ;
	test_pdb_line(  test_case1, "ATOM", 1, "N", 'B', 'A', 1, ' ',
					11.104, 6.134, -6.504, 1.0, 0.0, "N", 0, 1) ;
	
	char test_case2[] = "ATOM      2  CA  ALA A   1      11.639   6.071  -5.147  1.00  0.00           C-1" ;
	test_pdb_line(  test_case2, "ATOM", 2, "CA", ' ', 'A', 1, ' ',
					11.639, 6.071, -5.147, 1.0, 0.0, "C", -1, 2) ;

	return nfails ;
	
}

/**
   ## FUNCTION:
	int test_pdb_line(void)

   ## SPECIFICATION:
        test pdb line parsing

*/
void test_pdb_line( char test_case[], const char entry[], int id, const char name[],
					char aloc, char chain, int resid, char insert,
					float x, float y, float z, float occ, float bfactor,
				    const char symbol[], int charge, int N)
{
	/*
	 * FIRST TEST
	 */
	s_atm *atom = my_calloc(1, sizeof(s_atm)) ;
	load_pdb_line(atom, test_case) ;

	fprintf(stdout, "\n    TEST PDB READER (%d) ............ \n", N) ;

	fprintf(stdout, "      *TEST PDB READER (ENTRY) ..... ") ;
	if(	strcmp(atom->type, entry) == 0) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%s VS %s)\n", atom->type, entry) ;


	fprintf(stdout, "      *TEST PDB READER (ID) ........ ") ;
	if(atom->id == id) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%d VS %d)\n", atom->id, id) ;

	fprintf(stdout, "      *TEST PDB READER (NAME) ...... ") ;
	if(strcmp(atom->name, name) == 0) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%s VS %s)\n", atom->name, name) ;

	fprintf(stdout, "      *TEST PDB READER (ALTLOC) .... ") ;
	if(atom->pdb_aloc == aloc) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%c VS %c)\n", atom->pdb_aloc, aloc) ;

	fprintf(stdout, "      *TEST PDB READER (CHAIN) ..... ") ;
	if(atom->chain[0] == chain) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%c VS %c)\n", atom->chain[0], chain) ;

	fprintf(stdout, "      *TEST PDB READER (RESID) ..... ") ;
	if(atom->res_id == resid) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%d VS %d)\n", atom->res_id , resid) ;

	fprintf(stdout, "      *TEST PDB READER (INSERT) .... ") ;
	if(atom->pdb_insert == insert) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%c VS %c)\n", atom->pdb_insert, insert) ;

	fprintf(stdout, "      *TEST PDB READER (X) ......... ") ;
	if((atom->x < x+0.001 && atom->x > x-0.001)) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%.2f VS %.2f)\n", atom->x, x) ;

	fprintf(stdout, "      *TEST PDB READER (Y) ......... ") ;
	if((atom->y < y+0.001 && atom->y > y-0.001)) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%.2f VS %.2f)\n", atom->y, y) ;

	fprintf(stdout, "      *TEST PDB READER (Z) ......... ") ;
	if((atom->z < z+0.001 && atom->z > z-0.001)) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%.2f VS %.2f)\n", atom->z, z) ;

	fprintf(stdout, "      *TEST PDB READER (OCCUPANCY) . ") ;
	if((atom->occupancy < occ+0.001 && atom->occupancy > occ-0.001)) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%.2f VS %.2f)\n", atom->occupancy, occ) ;

	fprintf(stdout, "      *TEST PDB READER (BFACTOR) ... ") ;
	if((atom->bfactor < bfactor+0.001 && atom->bfactor > bfactor-0.001)) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%.2f VS %.2f)\n", atom->bfactor, bfactor) ;

	fprintf(stdout, "      *TEST PDB READER (SYMBOL) .... ") ;
	if(strcmp(atom->symbol, symbol) == 0) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%s VS %s)\n", atom->symbol, symbol) ;

	fprintf(stdout, "      *TEST PDB READER (CHARGE) .... ") ;
	if(atom->charge == charge) fprintf(stdout, "OK \n") ;
	else fprintf(stdout, "FAILED (%d VS %d)\n", atom->charge, charge) ;

	my_free(atom) ;
}


void load_pdb_line(s_atm *atom, char *line)
{
    /*int trash;*/
        int guess_flag=0;
	rpdb_extract_pdb_atom(line, atom->type, &(atom->id),
						atom->name, &(atom->pdb_aloc), atom->res_name,
						atom->chain, &(atom->res_id), &(atom->pdb_insert),
						&(atom->x), &(atom->y), &(atom->z),
						&(atom->occupancy), &(atom->bfactor), atom->symbol,
						&(atom->charge),&guess_flag) ;

	str_trim(atom->type) ;
	str_trim(atom->name) ;
	str_trim(atom->chain) ;
	str_trim(atom->symbol) ;
}

int check_is_valid_element(void)
{
	int nfails = 0 ;

	/* Testing if the ignore element is taken into account */
	fprintf(stdout, "    TEST ELEMENT COMPARATOR (1) .... ") ;
	int idx1 = is_valid_element("He", 1) ;
	int idx2 = is_valid_element("He", 0) ;
	int idx3 = is_valid_element("he", 1) ;
	int idx4 = is_valid_element("he", 0) ;
	
	if(idx1 != 2 || idx2 != 2 || idx3 != 2 || idx4 != -1) {
		nfails ++ ;
		fprintf(stdout, "FAILED \n") ;
	}
	else fprintf(stdout, "OK \n") ;
	
	/* Testing thje automatic removal of space */
	fprintf(stdout, "    TEST ELEMENT COMPARATOR (2) .... ") ;
	int idx5 = is_valid_element("Fe  ", 1) ;
	int idx6 = is_valid_element("   Fe  ", 1) ;
	int idx7 = is_valid_element("  S", 1) ;
	int idx8 = is_valid_element("  S ", 1) ;
	if(idx5 == -1 || idx6 == -1 || idx7 == -1 || idx8 == -1) {
		nfails ++ ;
		fprintf(stdout, "FAILED \n") ;
	}
	else fprintf(stdout, "OK \n") ;
	
	/* Testing non valid elements */
	fprintf(stdout, "    TEST ELEMENT COMPARATOR (3) .... ") ;
	int idx9 = is_valid_element(" sdzqqs ", 1) ;
	int idx10 = is_valid_element(" 92 ", 1) ;

	if(idx9 != -1 || idx10 != -1) {
		nfails ++ ;
		fprintf(stdout, "FAILED \n") ;
	}
	else fprintf(stdout, "OK \n") ;
	
	return nfails ;
}
