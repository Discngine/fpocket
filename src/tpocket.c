#include "../headers/tpocket.h" 

/*

## GENERAL INFORMATION
##
## FILE 					tpocket.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##  This file contains all routines used to execute tpocket and test the fpocket
##  performance, given a set of complexe-apo-ligand structure stored in a single
##  text file.
##
## MODIFICATIONS HISTORY
##
##	10-03-09	(v)  Mean number of atom per pocket + ligand volume added
##	05-03-09	(v)  Mean pocket volume added to tpocket output
##	19-01-09	(v)  Minor modif (status output printed on the same line)
##	28-11-08	(v)  Relooking + comments UTD
##	27-11-08	(v)  Write fpocket output if asked + relooking
##	15-10-08	(v)  Fixed bad count when PDB file not found.
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) CLEAN THE CODE! It's such a mess here...
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
	test_fpocket
  
   ## SPECIFICATION: 
	Test fpocket for a set of pdb files. The output is writen in this function,
	and consists of two files (see documentation for details)
  
   ## PARAMETRES:
	@ s_tparams *par: Parameters, contain the fpocket parameters, and the list
					  of data set information.
  
   ## RETURN:
	void
  
*/
void test_fpocket(s_tparams *par)
{
	if(! par || par->nfiles <= 0)  return ;
	
	int nranks = 15,  novlp = 8, novlp2 = 9,novlp3 = 8,
		i, j, k, nok = 0  ;
	int ranks [] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 50,100,200} ;
	float ovlp[] = {20.0,30.0,40.0,50.0, 60.0, 70.0, 80.0,90.0} ;
	float ovlp2[] = {0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.9, 1.0} ;
	float ovlp3[] = {0.2, 0.25, 0.3, 0.35, 0.4, 0.5, 0.6, 0.7} ;
	
	float mean_ov1 = 0.0, mean_ov2 = 0.0, mean_dst = 0.0, mean_ov4 = 0.0, mean_ov5 = 0.0,
		  mean_ovr1 = 0.0, mean_ovr2 = 0.0, mean_ovr3 = 0.0, mean_ovr4 = 0.0, mean_ovr5 = 0.0, mean_ovr6 = 0.0,
		  mean_pvol3 = 0.0, mean_pvol6 = 0.0 ;

	float mean_lvol = 0.0 ;
	int mean_nbatm3 = 0, mean_nbatm6 = 0 ;
	
	int n1, n2, n3, n4, n5, n6, N = 0 ;

	/* Store statistics for each files: */
	int status[par->nfiles] ;
	float ddata [par->nfiles][M_NDDATA];
	int idata [par->nfiles][M_NIDATA];

	/* Test all files */
	for(i = 0 ; i < par->nfiles ; i++) {
		strcpy(par->fpar->pdb_path, par->fapo[i]) ;
                fprintf(stdout,"currently testing on %s\n",par->fpar->pdb_path);
                fflush(stdout);
		status [i] = test_set(par, i, ddata, idata) ;
		fprintf(stdout, "> %3d : %s output code %d", i+1, par->fapo[i],
													   status [i]) ;
		if(i == par->nfiles - 1) fprintf(stdout, "\n") ;
		else fprintf(stdout, "\r") ;
		fflush(stdout) ;

		if(status[i] == M_OK) N++ ;
	}

	/* Printing each complexe statistics */
	FILE *fp = fopen(par->p_output, "w") ;
	if(fp) {
		n1 = 0, n2 = 0, n3 = 0, n4 = 0, n5 = 0, n6 = 0 ;
		fprintf(fp, "LIG COMPLEXE APO NB_PCK CRIT1 CRIT2 CRIT3 CRIT4 CRIT5 CRIT6 POS1 POS2 POS3 POS4 POS5 POS6 REL_OVLP1 REL_OVLP2 REL_OVLP3 REL_OVLP4 REL_OVLP5 REL_OVLP6 LIGMASS LIGVOL PVOL3 NATM3 PVOL6 NATM6\n") ;
		for(i = 0 ; i < par->nfiles ; i++) {
			remove_path(par->fcomplex[i]) ;
			remove_path(par->fapo[i]) ;
			if(status[i] == M_OK) {
				fprintf(fp, "%s %s %s %5d %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %4d %4d %4d %4d %4d %4d %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f %9.2f %9.2f %12.2f %4d %12.2f %4d\n",
						par->fligan[i], par->fcomplex[i], par->fapo[i], idata[i][M_NPOCKET],
						ddata[i][M_MAXPCT1], ddata[i][M_MAXPCT2], ddata[i][M_MINDST], ddata[i][M_CRIT4], ddata[i][M_CRIT5], ddata[i][M_CRIT6],
						idata[i][M_POS1], idata[i][M_POS2], idata[i][M_POS3], idata[i][M_POS4], idata[i][M_POS5], idata[i][M_POS6],
						ddata[i][M_OREL1], ddata[i][M_OREL2], ddata[i][M_OREL3], ddata[i][M_OREL4], ddata[i][M_OREL5], ddata[i][M_OREL6],
						ddata[i][M_LIGMASS], ddata[i][M_LIGVOL], ddata[i][M_POCKETVOL_C3], idata[i][M_NATM3], ddata[i][M_POCKETVOL_C6], idata[i][M_NATM6]) ;

				if(idata[i][M_POS1] > 0) {
					mean_ov1 += ddata[i][M_MAXPCT1] ;
					mean_ovr1 += ddata[i][M_OREL1];
					n1++ ;
				}

				if(idata[i][M_POS2] > 0) {
					mean_ov2 += ddata[i][M_MAXPCT2] ;
					mean_ovr2 += ddata[i][M_OREL2];
					n2++ ;
				}

				if(idata[i][M_POS3] > 0) {
					mean_dst += ddata[i][M_MINDST];
					mean_ovr3 += ddata[i][M_OREL3];
					mean_pvol3 += ddata[i][M_POCKETVOL_C3] ;
					mean_nbatm3 += idata[i][M_NATM3] ;
					n3 ++ ;
				}

				if(idata[i][M_POS4] > 0) {
					mean_ov4 += ddata[i][M_CRIT4];
					mean_ovr4 += ddata[i][M_OREL4];
					n4 ++ ;
				}

				if(idata[i][M_POS5] > 0) {
					mean_ov5 += ddata[i][M_CRIT5];
					mean_ovr5 += ddata[i][M_OREL5];
					n5 ++ ;
				}

				if(idata[i][M_POS6] > 0) {
					mean_ovr6 += ddata[i][M_OREL5];
					mean_pvol6 += ddata[i][M_POCKETVOL_C6] ;
					mean_nbatm6 += idata[i][M_NATM6] ;
					n6 ++ ;
				}
			}
			else {
				fprintf(fp, "%s %s %s %5d %7.2f %7.2f %7.2f %7.2f %7.2f %7.2f %4d %4d %4d %4d %4d %4d %8.2f %8.2f %8.2f %8.2f %8.2f %8.2f %9.2f %9.2f %12.2f %4d %12.2f %4d \n",
						par->fligan[i], par->fcomplex[i], par->fapo[i], -1, 
						-1.0, -1.0, -1.0, -1.0, -1.0, -1.0,
						-1, -1, -1, -1, -1, -1,
						-1.0, -1.0, -1.0, -1.0, -1.0, -1.0,
						-1.0, -1.0, -1.0, -1, -1.0, -1) ;
			}
			mean_lvol += ddata[i][M_LIGVOL] ;
		}

		mean_ov1 /= (float) n1 ; mean_ovr1 /= (float) n1 ;
		mean_ov2 /= (float) n2 ; mean_ovr2 /= (float) n2 ;

		mean_dst /= (float) n3 ; mean_ovr3 /= (float) n3 ;
		mean_pvol3 /= (float) n3 ;
		mean_nbatm3 /= (float) n3 ;

		mean_ov4 /= (float) n4 ; mean_ovr4 /= (float) n4 ;
		mean_ov5 /= (float) n5 ; mean_ovr5 /= (float) n5 ;
		
		mean_ovr6 /= (float) n6 ;
		mean_pvol6 /= (float) n6 ;
		mean_nbatm6 /= (float) n6 ;

		mean_lvol /= (float) par->nfiles ;

		fclose(fp) ;
	}
	else fprintf(stdout, "The file %s could not be opened\n", par->p_output) ;

	/* Printing global statistics */
	FILE *fg = fopen(par->g_output, "w") ;
	if(fg) {
		/* Write the first criteria statistics */
		fprintf(fg, "===================== General statistics on all complexes =======================\n") ;


		/* Write the first criteria statistics */
		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t-                       _ Distance criteria _                      -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg, "   Ratio of good predictions (dist = 4A) \n") ;
		fprintf(fg, "\n") ;

		for(i = 0 ; i < nranks ; i++) {
			nok = 0 ;
			for(k = 0 ; k < par->nfiles ; k++) {
				if(status[k] == M_OK && idata[k][M_POS3] <= ranks[i]
				&& idata[k][M_POS3] > 0) {
					nok ++ ;
				}
			}
			//printf("%d NOK: %d, %d, %f\n", ranks[i], nok, N, ((float)nok) / ((float) N)) ;
			fprintf(fg, "Rank <= %2d  :\t\t%6.2f\n", ranks[i],
					((float)nok) / ((float) N)) ;
		}

		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean distance                   : %8.2f\n", mean_dst) ;
		fprintf(fg, "Mean relative overlap           : %8.2f\n", mean_ovr3) ;
		fprintf(fg, "Mean pocket volume (estimation) : %8.2f\n", mean_pvol3) ;
		fprintf(fg, "Mean ligand volume (estimation) : %8.2f\n", mean_lvol) ;
		fprintf(fg, "Mean number of pocket atom      : %4d\n", mean_nbatm3) ;


		/* Write the 2nd criteria statistics */
		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t- _ 1st overlap criteria (use of ligand's alpha sphere neighbors)_ -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg,"           :");
		for( j = 0 ; j < novlp ; j++) {
				fprintf(fg, "  >%5.2f  :", ovlp[j]) ;
		}
		fprintf(fg,"\n");
		fprintf(fg,"--");
		for( j = 0 ; j < novlp ; j++) {
			fprintf(fg, "-") ;
		}
		fprintf(fg,"\n");
		
		for(i = 0 ; i < nranks ; i++) {
			fprintf(fg, "Rank <= %2d :", ranks[i]) ;
			for( j = 0 ; j < novlp ; j++) {
				nok = 0 ;
				for(k = 0 ; k < par->nfiles ; k++) {
					if( status[k] == M_OK &&
						ddata[k][M_MAXPCT2] >= ovlp[j] &&
						idata[k][M_POS2] <= ranks[i] &&
						idata[k][M_POS2] > 0) {
						nok ++ ;
					}
				}
				fprintf(fg, "  %6.2f  :", ((float)nok) / ((float) N)) ;
			}
			fprintf(fg, "\n") ;
		}
		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean overlap          : %8.2f\n", mean_ov2) ;
		fprintf(fg, "Mean relative overlap : %8.2f\n", mean_ovr2) ;

		/* Write the 3rd criteria statistics */
		
		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t-        _ 2nd overlap criteria (simple distance criteria) _       -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg,"           :");

		for( j = 0 ; j < novlp ; j++) {
				fprintf(fg, "  >%5.2f  :", ovlp[j]) ;
		}

		fprintf(fg,"\n");
		fprintf(fg,"---");

		for( j = 0 ; j < novlp ; j++) {
			fprintf(fg, "-") ;
		}
		fprintf(fg,"\n");

		for(i = 0 ; i < nranks ; i++) {
			fprintf(fg, "Rank <= %2d :", ranks[i]) ;
			for( j = 0 ; j < novlp ; j++) {
				nok = 0 ;
				for(k = 0 ; k < par->nfiles ; k++) {
					if( status[k] == M_OK
						&& ddata[k][M_MAXPCT1] >= ovlp[j]
						&& idata[k][M_POS1] <= ranks[i]
						&& idata[k][M_POS1] > 0) {
						nok ++ ;
					}
				}
				fprintf(fg, "  %6.2f  :", ((float)nok) / ((float) N)) ;
			}
			fprintf(fg, "\n") ;
		}
		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean overlap          : %f\n", mean_ov1) ;
		fprintf(fg, "Mean relative overlap : %f\n", mean_ovr1) ;

		/* Write the 4th criteria statistics */
		
		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t-          _ 4th overlap criteria (alpha sphere overlap) _         -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg,"           :");
		for( j = 0 ; j < novlp2 ; j++) {
				fprintf(fg, "  >%5.2f  :", ovlp2[j]) ;
		}
		fprintf(fg,"\n");
		fprintf(fg,"----");
		for( j = 0 ; j < novlp2 ; j++) {
			fprintf(fg, "-") ;
		}
		fprintf(fg,"\n");

		for(i = 0 ; i < nranks ; i++) {
			fprintf(fg, "Rank <= %2d :", ranks[i]) ;
			for( j = 0 ; j < novlp2 ; j++) {
				nok = 0 ;
				for(k = 0 ; k < par->nfiles ; k++) {
					if( status[k] == M_OK &&
						ddata[k][M_CRIT4] >= ovlp2[j] &&
						idata[k][M_POS4] <= ranks[i] &&
						idata[k][M_POS4] > 0) {
						nok ++ ;
					}
				}
				fprintf(fg, "  %6.2f  :", ((float)nok) / ((float) N)) ;
			}
			fprintf(fg, "\n") ;
		}
		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean overlap          : %f\n", mean_ov4) ;
		fprintf(fg, "Mean relative overlap : %f\n", mean_ovr4) ;

		/* Write the 4th criteria statistics */
		
		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t-          _ 5th overlap criteria (alpha sphere overlap) _         -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg,"           :");
		for( j = 0 ; j < novlp3 ; j++) {
				fprintf(fg, "  >%5.2f  :", ovlp3[j]) ;
		}
		fprintf(fg,"\n");
		fprintf(fg,"----");
		for( j = 0 ; j < novlp3 ; j++) {
			fprintf(fg, "-") ;
		}
		fprintf(fg,"\n");

		for(i = 0 ; i < nranks ; i++) {
			fprintf(fg, "Rank <= %2d :", ranks[i]) ;
			for( j = 0 ; j < novlp3 ; j++) {
				nok = 0 ;
				for(k = 0 ; k < par->nfiles ; k++) {
					if( status[k] == M_OK &&
						ddata[k][M_CRIT5] >= ovlp3[j] &&
						idata[k][M_POS5] <= ranks[i] &&
						idata[k][M_POS5] > 0) {
						nok ++ ;
					}
				}
				fprintf(fg, "  %6.2f  :", ((float)nok) / ((float) N)) ;
			}
			fprintf(fg, "\n") ;
		}
		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean overlap          : %f\n", mean_ov5) ;
		fprintf(fg, "Mean relative overlap : %f\n", mean_ovr5) ;


		fprintf(fg, "\n\t--\n") ;
		fprintf(fg,   "\t-      _ Concensus overlap criteria (alpha sphere overlap) _       -\n") ;
		fprintf(fg,   "\t--\n\n") ;
		fprintf(fg, "   Ratio of good predictions (dist = 3A) \n") ;
		fprintf(fg, "\n") ;

		for(i = 0 ; i < nranks ; i++) {
			nok = 0 ;
			for(k = 0 ; k < par->nfiles ; k++) {
				if(status[k] == M_OK && idata[k][M_POS6] <= ranks[i]
				&& idata[k][M_POS6] > 0) {
					nok ++ ;
				}
			}
			//printf("%d NOK: %d, %d, %f\n", ranks[i], nok, N, ((float)nok) / ((float) N)) ;
			fprintf(fg, "Rank <= %2d  :\t\t%6.2f\n", ranks[i],
					((float)nok) / ((float) N)) ;
		}

		fprintf(fg, "-\n") ;
		fprintf(fg, "Mean relative overlap           : %7.2f\n", mean_ovr6) ;
		fprintf(fg, "Mean pocket volume (estimation) : %10.2f\n", mean_pvol6) ;
		fprintf(fg, "Mean number of pocket atom      : %4d\n", mean_nbatm6) ;

		fclose(fg) ;
	}
	else fprintf(stdout, "The file %s could not be opened\n", par->g_output) ;
}

/**
   ## FUNCTION: 
	void test_set(s_tparams *par)
  
   ## SPECIFICATION: 
	Test fpocket for a single set of apo/complexe/ligand.
  
   ## PARAMETRES:
	@ s_tparams *par  : Parameters, contain the fpocket parameters, and the list
					    of data set to test. 
    @ int i           : ID if the current test set. Used to fill the two following
 					    statistic arrays
    @ float ddata[][] : Used to store statistics for the evaluation (float)
    @ float idata[][] : Used to store statistics for the evaluation (integers)
  
   ## RETURN:
	int - A flag saying whether or not the evaluation is successfull. Values:
		M_LIGNOTFOUND -2
		M_PDBOPENFAILED -1
		M_OK 0 
		M_NOPOCKETFOUND 1
  
*/
int test_set(s_tparams *par, int i, float ddata [][M_NDDATA], int idata [][M_NIDATA]) 
{
	s_atm **accpck = NULL,
		  **accpck2 = NULL ;
	
	char *fa = par->fapo[i], 
		 *fc = par->fcomplex[i],
		 *lig = par->fligan[i] ;
	
	int naccpck = 0,
		naccpck2 = 0 ;

	/** Load the apo form, the holo form, and the complex form 
	  * without ligand. The complex without ligand will allow us to get exact 
	  * atoms contacted by voronoi vertices detected by fpocket on the complexe 
	  * form and then detect which atoms are involved in the interaction.
	 **/
	s_pdb *apdb = rpdb_open(fa, lig, M_DONT_KEEP_LIG, 0,par->fpar);
	s_pdb *cpdb = rpdb_open(fc, lig, M_KEEP_LIG, 0,par->fpar);
	s_pdb *cpdb_nolig = rpdb_open(fc, lig, M_DONT_KEEP_LIG, 0,par->fpar) ;
	
	/* Check that both pdb files are opened */
	if(! apdb || !cpdb) {
		fprintf(stderr, "!! PDB loading failed for %s-%s ligand %s... %p %p\n", 
						fc, fa, lig, apdb, cpdb) ;
		if(cpdb) free_pdb_atoms(cpdb) ;
		if(apdb) free_pdb_atoms(apdb) ;
		
		return M_LIGNOTFOUND ;
	}
	
	/* Check now if the ligand has been found */
	if(cpdb->natm_lig <= 0) {
		
		fprintf(stderr, "! Ligand '%s' not found in the complex %s...\n",
						lig, fc) ;
		
		return M_LIGNOTFOUND ;
	}
	
	
	/* PDBs and ligand OK, now read PDB and launch fpocket */
	
	/* Get rid of HETATM in the apo structure*/
	rpdb_read(apdb, lig, M_DONT_KEEP_LIG, 0,par->fpar) ;
	rpdb_read(cpdb, lig, M_KEEP_LIG, 0,par->fpar) ;
	rpdb_read(cpdb_nolig, lig, M_DONT_KEEP_LIG, 0,par->fpar) ;
        print_number_of_objects_in_memory();
	c_lst_pockets *pockets = search_pocket(apdb, par->fpar,cpdb);
        print_number_of_objects_in_memory();
        set_pockets_bary(pockets) ;
	
	/* Check that at least one pocket has been found */
	if(!pockets || pockets->n_pockets <= 0) {
		if(pockets) c_lst_pocket_free(pockets) ;
		return M_NOPOCKETFOUND ;
	}
	
	/* Everything is OK, so now perform the evaluation*/
	
	/* We found pocket on the apo form get volume and mass of the ligand */
	idata[i][M_NPOCKET] = pockets->n_pockets ;
	ddata[i][M_LIGMASS] = get_mol_mass_ptr(cpdb->latm_lig, cpdb->natm_lig) ;
	ddata[i][M_LIGVOL]  = get_mol_volume_ptr(cpdb->latm_lig, cpdb->natm_lig, 
											 par->fpar->nb_mcv_iter);

	/* Get atoms involved in the actual pocket */
	accpck = get_actual_pocket_DEPRECATED(cpdb, M_CRIT2_D, &naccpck) ;
	accpck2 = get_actual_pocket(cpdb, cpdb_nolig, i, par, &naccpck2) ;

	fflush(stdout) ;
	if (naccpck2 <= 0) {
		fprintf(stdout, "! Warning: actual pocket has 0 atoms!! %s %d\n", fa,
						naccpck2) ;
	}
        
	/* Calculate evaluation criterias */
	check_pockets(pockets, accpck2, naccpck2, cpdb->latm_lig, cpdb->natm_lig, 
				  accpck, naccpck, ddata, idata, i) ;

	if(par->keep_fpout != 0) {
		write_out_fpocket(pockets, apdb, par->fapo[i]) ;
	}
	/* write_pdb_com(cpdb, par->fcomplex[i]) ; */
	
	/* Free memory */
        print_number_of_objects_in_memory();
	c_lst_pocket_free(pockets) ;
	my_free(accpck) ;
        my_free(accpck2);
	free_pdb_atoms(apdb) ;
	free_pdb_atoms(cpdb) ;
	free_pdb_atoms(cpdb_nolig) ;
	print_number_of_objects_in_memory();
	return M_OK ;
}

/**
   ## FUNCTION: 
	get_actual_pocket
  
   ## SPECIFICATION: 
	Get atoms contacted by voronoi vertices present in the actual pocket and 
	situated at a distance of M_DST_CRIT from each ligand atoms.
	This way of finding exact atoms contacted by the ligand is more accurate,
	but need an extra search by fpocket to find voronoi vertices in the complexe
	form without the ligand...
  
   ## PARAMETRES:
	@ s_pdb *cpdb       : The pdb structure of the complexe.
	@ s_pdb *cpdb_nolig : The pdb structure of the complexe WITHOUT the ligand
 	@ int i             : ID of the current test set
	@ s_tparams *par    : Parameters
	@ int *nb_atm       : Number of atom (this an output, it should be set here)
  
   ## RETURN:
	s_atm **: A 2D table containing pointers to atoms which defines the pocket.
  
*/
s_atm** get_actual_pocket(s_pdb *cpdb, s_pdb *cpdb_nolig, int i, s_tparams *par, int *nb_atm) 
{
	s_atm **neigh = NULL ;
        
	c_lst_pockets *pockets = search_pocket(cpdb_nolig, par->fpar,cpdb);
        if(pockets && pockets->n_pockets > 0) {
		/* */
		/* Get the list of atoms contacted by the vertices near the ligand. */
            

		neigh = get_mol_ctd_atm_neigh(cpdb->latm_lig, cpdb->natm_lig,
									  pockets->vertices->pvertices,
									  pockets->vertices->nvert, M_CRIT1_D,
									  M_INTERFACE_SEARCH, nb_atm) ;

		c_lst_pocket_free(pockets) ;
	}
	else {
		fprintf(stderr, "! No pocket found for apo %s and complex %s ligand %s...\n", 
						par->fapo[i], par->fcomplex[i], par->fligan[i]) ;

		if(pockets) c_lst_pocket_free(pockets) ;
	}

	return neigh ;
}

/**
   ## FUNCTION: 
	get_actual_pocket
  
   ## SPECIFICATION: 
	Get atoms situated at a distance of lig_dist_crit from each ligand atoms.
    This is a quite inacurate way of defining the pocket -> DEPRECATED
    If the distance criteria used does not allow any identification, we will
    test a larger distance until 6A. 
  
   ## PARAMETRES:
	@ s_pdb *cpdb         : The pdb structure of the complexe.
	@ float lig_dist_crit : The distance criteria
	@ int *nb_atm         : OUTPUT: Number of atom found in the pocket
  
   ## RETURN:
	s_atm **: A 2D table containing pointers to atoms which defines the pocket.
  
*/
s_atm** get_actual_pocket_DEPRECATED(s_pdb *cpdb, float lig_dist_crit, int *nb_atm) 
{
	/* Getting the ligan's neighbors. */
	s_atm **alneigh = get_mol_atm_neigh(cpdb->latm_lig, cpdb->natm_lig,
										cpdb->latoms_p, cpdb->natoms,
										lig_dist_crit, nb_atm) ;
	if(*nb_atm <= 0) {
		if(alneigh) my_free(alneigh) ;
		alneigh = get_mol_atm_neigh(cpdb->latm_lig, cpdb->natm_lig,
									cpdb->latoms_p, cpdb->natoms,
									lig_dist_crit+1.0, nb_atm) ;

		if(*nb_atm <= 0) {
			if(alneigh) my_free(alneigh) ;
			alneigh = get_mol_atm_neigh(cpdb->latm_lig, cpdb->natm_lig,
										cpdb->latoms_p, cpdb->natoms,
										lig_dist_crit+2.0, nb_atm) ;
			if(*nb_atm <= 0) {
				if(alneigh) my_free(alneigh) ;
				alneigh = NULL ;
			}
		}
	}
	
	return alneigh ;
}

/**
   ## FUNCTION: 
	check_pockets
  
   ## SPECIFICATION: 
	Checking the pocket prediction for one data set. (apo+complex+ligand)
	This function will calculate three criterias:
		1 - Overlap using the first definition of the pocket (atoms contacted
 			by vertices next to the ligand)
		2 - Overlap using the second definition of the pocket (atoms situated
 			at N A of the ligand)
		3 - Smallest distance of each ligand atom from the barycenter of the
 			pocket. Cutoff: 4A
  
   The two arrays ddata and idata given in paramet are used as output.
  
   ## PARAMETRES:
	@ c_lst_pockets *pockets: The pockets found for this set.
    @ s_atm accpck          : The actual pocket using first definition
    @ int naccpckk          : Number of atoms in the actual pocket definition 1
    @ s_atm lig             : Ligand atoms
    @ int nalig             : Number of ligand atoms
    @ s_atm alneigh         : The actual pocket using second definition
    @ int nlneigh           : Number of atoms in the actual pocket definition 2
    @ float ddata[][]       : Used to store statistics for the evaluation (float)
    @ float idata[][]       : Used to store statistics for the evaluation (integers)
    @ int i                 : ID if the current test set. Used to fill the two 
 							  following statistic arrays
  
   ## RETURN:
	void
  
*/
void check_pockets(c_lst_pockets *pockets, s_atm **accpck, int naccpck, s_atm **lig, 
				   int nalig, s_atm **alneigh, int nlneigh, 
				   float ddata [][M_NDDATA], int idata [][M_NIDATA], int i)
{
	int found [] = {0, 0, 0, 0, 0, 0} ;
	int npneigh = 0, pos, j ;
	float ov1, ov2, ov3, ov4, dst = 0.0 ;
	/* float ovol ; */
	
	s_atm **pneigh = NULL ;
	s_vvertice **pvert = NULL ;
	
	node_pocket *ncur = NULL ;
	s_pocket *pcur = NULL ;
	
	/* Check the correspondance for each pocket found */
	ncur = pockets->first ;

        int n_lig_molecules=1;
        char chain_tmp[2];
        int resnumber_tmp;
        strcpy(chain_tmp,lig[0]->chain);
        resnumber_tmp = lig[0]->res_id;
        
        for (j = 1 ; j < nalig ; j++) {
            if(strcmp(chain_tmp,lig[j]->chain) !=0 || resnumber_tmp!=lig[j]->res_id){
                n_lig_molecules++;
                strcpy(chain_tmp,lig[j]->chain);
                resnumber_tmp =lig[j]->res_id;
            }
        }
        
	pos = 0 ;
	while(ncur) {
		pos ++ ;
		pcur = ncur->pocket ;

		/*
			TEST THE FIRST CRITERIA (DISTANCE TO BARYCENTER)
		 */
		if(! found[0]) {
			for (j = 0 ; j < nalig ; j++) {
				dst = dist(lig[j]->x, lig[j]->y, lig[j]->z, 
							pcur->bary[0], pcur->bary[1], pcur->bary[2]) ;
                                
				if(dst < M_CRIT3_VAL) {
				/* Criteria 3 OK  */
					ddata[i][M_MINDST] = dst ;
					ddata[i][M_OREL3] = (naccpck <= 0.0)?-1.0 :(float)npneigh/(float)naccpck*100.0 ;
					ddata[i][M_POCKETVOL_C3] = pcur->pdesc->volume ;
					idata[i][M_POS3] = pos ;
					idata[i][M_NATM3] = count_pocket_contacted_atms(pcur) ;
					found[0] = 1 ; break ;
				}
			}
		}

		/*
			TEST THE 2nd and 3rd CRITERIA (ATOMIC OVERLAP)
		 */
		if(!found[1] || !found[2]) {
			pneigh = get_pocket_contacted_atms(pcur, &npneigh) ;
			if(! found[1]) {
				ov1 = atm_corsp(alneigh, nlneigh, pneigh, npneigh) ;
				if(ov1 > M_CRIT1_VAL) {
					idata[i][M_POS1] = pos ;
					ddata[i][M_MAXPCT1] = ov1 ;
					ddata[i][M_OREL1] = (nlneigh <= 0.0)? -1.0 : (float)npneigh/(float)nlneigh*100.0 ;
					found[1] = 1 ;
				}
			}

			if(! found[2]) {
				ov2 = atm_corsp(accpck, naccpck, pneigh, npneigh) ;
				if(ov2 > M_CRIT2_VAL) {
					idata[i][M_POS2] = pos ;
					ddata[i][M_MAXPCT2] = ov2 ;
					ddata[i][M_OREL2] = (naccpck <= 0.0)?-1.0 : (float)npneigh/(float)naccpck*100.0 ;
					found[2] = 1 ;
				}
			}
			my_free(pneigh) ;
		}

		/*
			TEST THE 4th and 5th CRITERIA (VERTICE OVERLAPS)
		 */
		if(!found[3] || !found[4] || !found[5]) {
			pvert = get_pocket_pvertices(pcur) ;
			if(!found[3]){
				/* Calculate proportion of ligand atom that lies within 3A
				   of at least one vertice */
                            
                                ov3 = count_atm_prop_vert_neigh( lig, nalig,pvert, pcur->size, M_CRIT4_D,n_lig_molecules) ;
				if(ov3 > M_CRIT4_VAL) {
					idata[i][M_POS4] = pos ;
					ddata[i][M_CRIT4] = ov3 ;
					ddata[i][M_OREL4] = ov3*100 ;
					found[3] = 1 ;
				}
			}

			if(!found[4]){
				/* Calculate proportion of pocket vertice that lies within 3A
				   of at least one ligand atom */
				ov4 = count_pocket_lig_vert_ovlp(lig, nalig,
												 pvert, pcur->size, M_CRIT5_D) ;
				if(ov4 > M_CRIT5_VAL) {
					idata[i][M_POS5] = pos ;
					ddata[i][M_CRIT5] = ov4 ;
					ddata[i][M_OREL5] = ov4*100 ;
					found[4] = 1 ;
				}
			}

			if(!found[5]){
				ov3 = count_atm_prop_vert_neigh( lig, nalig,
											 pvert, pcur->size, M_CRIT4_D,n_lig_molecules );
				ov4 = count_pocket_lig_vert_ovlp(lig, nalig,
												 pvert, pcur->size, M_CRIT5_D) ;
				if(ov4 > M_CRIT5_VAL && ov3 > M_CRIT4_VAL) {
					idata[i][M_POS6] = pos ;
					ddata[i][M_CRIT6] = 1.0 ;
					ddata[i][M_POCKETVOL_C6] = pcur->pdesc->volume ;
					ddata[i][M_OREL6] = ov4*100 ;
					idata[i][M_NATM6] = count_pocket_contacted_atms(pcur) ;
					found[5] = 1 ;
				}
			}
			my_free(pvert) ;
		}
		
		ncur = ncur->next ;

		/* Break the loop if all criteria are OK */
		if(found[0] && found[1] && found[2] && found[3] && found[4] && found[5]) break ;
		
	}

	if (! found[0]) {
		ddata[i][M_MINDST] = 0.0 ;
		ddata[i][M_OREL3] = 0.0 ;
		idata[i][M_POS3] = 0 ;
		idata[i][M_NATM3] = -1 ;
		ddata[i][M_POCKETVOL_C3] = 0.0 ;
	}

	if (! found[1]) {
		ddata[i][M_MAXPCT1] = 0.0 ;
		ddata[i][M_OREL1] = 0.0 ;
		idata[i][M_POS1] = 0 ;
	}

	if (! found[2]) {
		ddata[i][M_MAXPCT2] = 0.0 ;
		ddata[i][M_OREL2] = 0.0 ;
		idata[i][M_POS2] = 0 ;
	}

	if (! found[3]) {
		ddata[i][M_CRIT4] = 0.0 ;
		ddata[i][M_OREL4] = 0.0 ;
		idata[i][M_POS4] = 0 ;
	}

	if (! found[4]) {
		ddata[i][M_CRIT5] = 0.0 ;
		ddata[i][M_OREL5] = 0.0 ;
		idata[i][M_POS5] = 0 ;
	}
	
	if (! found[5]) {
		ddata[i][M_CRIT6] = 0.0 ;
		ddata[i][M_OREL6] = 0.0 ;
		idata[i][M_POS6] = 0 ;
		idata[i][M_NATM6] = -1 ;
		ddata[i][M_POCKETVOL_C6] = 0.0 ;
	}
}

/**
	--
	--

	ALL THE FOPLLOWING FUNCTIONS SHOULD BE USED TO CALCULATE AN OVERLAP VOLUME
	BETWEEN A GIVEN POPCKET AND THE REAL POCKET.

	THE FUNCTION set_overlap_volumes WILL SET AN OVERLAP VOLUME FOR EACH POCKET
	IN THE LIST GIVEN IN ARGUMENT, USING MONTE-CARLO OR BASIC DISCRETE ALGORITHM 
	DEPENDING ON THE PARAMETERS OF THE PROGRAM.

	BOTH ALGORITHM CAN BE USED INDEPENDENLTLY WITHOUT THE NEED OF A PARAMETER
	STRUCTURE (s_fparams)

	--
	--
   
*/

/**
   ## FUNCTION: 
	void set_overlap_volumes
  
   ## SPECIFICATION: 
	This function will set an overlap volume between a pocket, defined here by
    its voronoi vertices, and the ligand.
	Depending on the parameters, the method used will be either Monte Carlo 
	approximation, or discret basic approximation.
  
   ## PARAMETRES:
	@ s_pocket *pockets : The pocket
	@ s_atm **lig       : The ligand atoms.
	@ int natoms natoms : Number of atoms of the ligand.
	@ float lig_vol     : Volume of the ligand
	@ s_fparams *params : Parameters, giving the algorithm to use and the 
 					      corresponding parameter.
  
   ## RETURN:
	float: The overlap volume found
  
*/
float set_overlap_volumes(s_pocket *pocket, s_atm **lig, int natoms, float lig_vol, 
						  s_fparams *params) 
{
	/* The function to use for calculation */
	float (*pf_set_vol)(s_atm**, int, float, s_pocket*, int ) = NULL ;	
	int crit = 0,
		method = 0 ;

	if(params->basic_volume_div <= 0) {
		pf_set_vol = set_mc_overlap_volume ;
		crit = params->nb_mcv_iter ;
	}
	else {
		pf_set_vol = set_basic_overlap_volume ;
		crit = params->basic_volume_div ;
		method = 1 ;
	}

	if(pocket->v_lst->n_vertices > 150) {
		if(method == 0 && crit < 20000) crit = 20000 ;
	}
	
	return pf_set_vol(lig, natoms, lig_vol, pocket, crit) ;
}

/**
   ## FUNCTION:
	set_mc_overlap_volume
  
   ## SPECIFICATION: 
	This function will set an overlap volume between each pocket and the ligand.
	Method: monte Carlo aproximation.
  
   ## PARAMETRES:
	@ s_atm **lig       : The ligand atoms.
	@ int natoms natoms : Number of atoms of the ligand.
	@ float lig_vol     : Volume of the ligand
	@ s_pocket *pockets : The pocket
	@ int niter         : Number of monte-carlo iterations
  
   ## RETURN:
  
*/
float set_mc_overlap_volume(s_atm **lig, int natoms, float lig_vol, 
							s_pocket *pocket, int niter)
{
	c_lst_vertices *vertices = pocket->v_lst ;
	s_vvertice *vcur = NULL ;

	int i = 0, j = 0,
		nb_in = 0,
		found = 0 ;

	float xmin = 0.0, xmax = 0.0,
		  ymin = 0.0, ymax = 0.0,
		  zmin = 0.0, zmax = 0.0,
		  xtmp = 0.0, ytmp = 0.0, ztmp = 0.0,
		  xr   = 0.0, yr   = 0.0, zr   = 0.0,
		  vbox = 0.0, full_vol = 0.0;

	s_atm *acur = NULL ;

	/* First, search extrems coordinates in the ligan */
	for(i = 0 ; i < natoms ; i++) {
		acur = lig[i] ;
		if(i == 0) {
			xmin = acur->x - acur->radius ; xmax = acur->x + acur->radius ;
			ymin = acur->y - acur->radius ; ymax = acur->y + acur->radius ;
			zmin = acur->z - acur->radius ; zmax = acur->z + acur->radius ;
		}
		else {
		/* Update the minimum and maximum extreme point */
			if(xmin > (xtmp = acur->x - acur->radius)) xmin = xtmp ;
			else if(xmax < (xtmp = acur->x + acur->radius)) xmax = xtmp ;
	
			if(ymin > (ytmp = acur->y - acur->radius)) ymin = ytmp ;
			else if(ymax < (ytmp = acur->y + acur->radius)) ymax = ytmp ;
	
			if(zmin > (ztmp = acur->z - acur->radius)) zmin = ztmp ;
			else if(zmax < (ztmp = acur->z + acur->radius)) zmax = ztmp ;
		}
	}

	node_vertice *cur = vertices->first ;
	/* Continue with the pocket */
	while(cur) {
		vcur = cur->vertice ;
		if(xmin > (xtmp = vcur->x - vcur->ray)) xmin = xtmp ;
		else if(xmax < (xtmp = vcur->x + vcur->ray)) xmax = xtmp ;
	
		if(ymin > (ytmp = vcur->y - vcur->ray)) ymin = ytmp ;
		else if(ymax < (ytmp = vcur->y + vcur->ray)) ymax = ytmp ;
	
		if(zmin > (ztmp = vcur->z - vcur->ray)) zmin = ztmp ;
		else if(zmax < (ztmp = vcur->z + vcur->ray)) zmax = ztmp ;

		cur = cur->next ;
	}


	/* Next calculate the box volume */
	vbox = (xmax - xmin)*(ymax - ymin)*(zmax - zmin) ;

	/* Then apply monte carlo approximation of the volume */
	for(i = 0 ; i < niter ; i++) {
		found = 0 ;
		xr = rand_uniform(xmin, xmax) ;
		yr = rand_uniform(ymin, ymax) ;
		zr = rand_uniform(zmin, zmax) ;

		cur = vertices->first ;
		while(cur) {
			vcur = cur->vertice ;
			xtmp = vcur->x - xr ;
			ytmp = vcur->y - yr ;
			ztmp = vcur->z - zr ;

		/* Compare r^2 and dist(center, random_point)^2 */
			if((vcur->ray*vcur->ray) > (xtmp*xtmp + ytmp*ytmp + ztmp*ztmp)) {
			/* The point is inside one of the vertice!!*/ 
				nb_in ++ ; found = 1 ; break ;
			}
			cur = cur->next ;
		}

		if(!found) {
			for(j = 0 ; j < natoms ; j++) {
				acur = lig[j] ;
				xtmp = acur->x - xr ;
				ytmp = acur->y - yr ;
				ztmp = acur->z - zr ;
	
			/* Compare r^2 and dist(center, random_point)^2 */
				if((acur->radius*acur->radius) > (xtmp*xtmp + ytmp*ytmp + ztmp*ztmp)) {
				/* The point is inside one of the vertice!! */
					nb_in ++ ; break ;
				}
			}
		}
	}

	full_vol = ((float)nb_in)/((float)niter)*vbox ;	
	pocket->vol_corresp = ((pocket->pdesc->volume + lig_vol) - full_vol)/lig_vol ;

	return pocket->vol_corresp ;
}

/**
   ## FUNCTION: 
	set_basic_overlap_volume
  
   ## SPECIFICATION: 
	This function will set an overlap volume between each pocket and the ligand.
	Discrete aproximation. (algo in idiscret*idiscret*idiscret operation minimum)
  
   ## PARAMETRES:
	@ s_atm **lig       : The ligand atoms.
	@ int natoms natoms : Number of atoms of the ligand.
	@ float lig_vol     : Volume of the ligand
	@ s_pocket *pockets : The pocket
	@ int idiscret      : Discretisation of the space: splitt the space in N*N*N
						  cubes.
  
   ## RETURN:
  
*/
float set_basic_overlap_volume(s_atm **lig, int natoms, float lig_vol,
							   s_pocket *pocket, int idiscret)
{
	c_lst_vertices *vertices = pocket->v_lst ;
	s_vvertice *vcur = NULL ;

	int i = 0, j = 0,
		nb_in = 0,
		found = 0,
		niter = 0 ;

	float discret = 1.0/(float)idiscret ;

	float x = 0.0, y = 0.0, z = 0.0,
		  xstep = 0.0, ystep = 0.0, zstep = 0.0 ;

	float xmin = 0.0, xmax = 0.0,
		  ymin = 0.0, ymax = 0.0,
		  zmin = 0.0, zmax = 0.0,
		  xtmp = 0.0, ytmp = 0.0, ztmp = 0.0,
		  vbox = 0.0, full_vol = 0.0;

	s_atm *acur = NULL ;

	/* First, search extrems coordinates in the ligan */
	for(i = 0 ; i < natoms ; i++) {
		acur = lig[i] ;
		if(i == 0) {
			xmin = acur->x - acur->radius ; xmax = acur->x + acur->radius ;
			ymin = acur->y - acur->radius ; ymax = acur->y + acur->radius ;
			zmin = acur->z - acur->radius ; zmax = acur->z + acur->radius ;
		}
		else {
		/* Update the minimum and maximum extreme point */
			if(xmin > (xtmp = acur->x - acur->radius)) xmin = xtmp ;
			else if(xmax < (xtmp = acur->x + acur->radius)) xmax = xtmp ;
	
			if(ymin > (ytmp = acur->y - acur->radius)) ymin = ytmp ;
			else if(ymax < (ytmp = acur->y + acur->radius)) ymax = ytmp ;
	
			if(zmin > (ztmp = acur->z - acur->radius)) zmin = ztmp ;
			else if(zmax < (ztmp = acur->z + acur->radius)) zmax = ztmp ;
		}
	}

	node_vertice *cur = vertices->first ;
	/* Continue with the pocket */
	while(cur) {
		vcur = cur->vertice ;
		if(xmin > (xtmp = vcur->x - vcur->ray)) xmin = xtmp ;
		else if(xmax < (xtmp = vcur->x + vcur->ray)) xmax = xtmp ;
	
		if(ymin > (ytmp = vcur->y - vcur->ray)) ymin = ytmp ;
		else if(ymax < (ytmp = vcur->y + vcur->ray)) ymax = ytmp ;
	
		if(zmin > (ztmp = vcur->z - vcur->ray)) zmin = ztmp ;
		else if(zmax < (ztmp = vcur->z + vcur->ray)) zmax = ztmp ;

		cur = cur->next ;
	}


	/* Next calculate the box volume */
	vbox = (xmax - xmin)*(ymax - ymin)*(zmax - zmin) ;

	xstep = discret * (xmax - xmin) ;
	ystep = discret * (ymax - ymin) ;
	zstep = discret * (zmax - zmin) ;

	/* Then apply monte carlo approximation of the volume */
	for(x = xmin ; x < xmax ; x += xstep) {
		for(y = ymin ; y < ymax ; y += ystep) {	
			for(z = zmin ; z < zmax ; z += zstep) {
				found = 0 ;
				cur = vertices->first ;
				while(cur) {
					vcur = cur->vertice ;
					xtmp = vcur->x - x ;
					ytmp = vcur->y - y ;
					ztmp = vcur->z - z ;
		
				/* Compare r^2 and dist(center, random_point)^2 */
					if((vcur->ray*vcur->ray) > (xtmp*xtmp + ytmp*ytmp + ztmp*ztmp)) {
					/* The point is inside one of the vertice!! */
						nb_in ++ ; found = 1 ; break ;
					}
					cur = cur->next ;
				}
		
				if(!found) {
					for(j = 0 ; j < natoms ; j++) {
						acur = lig[j] ;
						xtmp = acur->x - x ;
						ytmp = acur->y - y ;
						ztmp = acur->z - z ;
			
					/* Compare r^2 and dist(center, random_point)^2 */
						if((acur->radius*acur->radius) > (xtmp*xtmp + ytmp*ytmp + ztmp*ztmp)) {
						/* The point is inside one of the vertice!! */
							nb_in ++ ; break ;
						}
					}
				}
				niter++ ;
			}
		}
	}

	full_vol = ((float)nb_in)/((float)niter)*vbox ;	
	pocket->vol_corresp = ((pocket->pdesc->volume + lig_vol) - full_vol)/lig_vol ;

	/* Ok lets just return the volume Vpok = Nb_in/Niter*Vbox */
	return pocket->vol_corresp ;
}
