
#include "../headers/dpocket.h"
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
## FILE 					dpocket.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##	This file contains all main routines of the dpocket program.
##	Given a set of protein-ligand PDB file, those routines will
##	calculate several descriptors on the pocket using two
##	different way to define what is the pocket:
##
##	1 - EXPLICIT DEFINITION:
##		The pocket will be defined explicitely using a distance
##		criteria with respect to the ligand. Two way of defining
##		the pockets are available:
##
##		a - The pocket is defined as all atoms contacted by
##		alpha spheres situated a distance lower or equal that
##		D (defined by the user or 4.0 by default in dparams.h)
##		of each ligand's atoms. 
##
##		b - The pocket is defined as all atoms situated at
##		a distance D (defined by the user or 4.5 by default in 
##		dparams.h) of each ligand's atoms.
##
##		This way, one can define a more or less accurate zone 
##		of interaction between the ligand and the protein. 
##		Descriptors are then calculated using alpha spheres 
##		retained and contacted atoms.
##
##	2 - IMPLICIT DEFINITION
##		The pocket will be defined as the one having the greater
##		atomic overlap, using the fpocket algorithm.
##
##	Pockets described using the explicit and the implicit definition
##	will be stored in a different file. Additionnaly, pockets found by
##	fpocket and having an overlap < 50% will be stored in an additional 
##	file.
##
##	Default file name are given in dparams.h. Currently and respectively:
##	"dpout_explicitp.txt"
##	"dpout_fpocketp.txt"
##	"dpout_fpocketnp.txt"
##
## MODIFICATIONS HISTORY
##
##	06-03-09	(v)  Criteria 4, 5, 6 added to dpocket output
##	09-02-09	(v)  Maximum distance between two alpha sphere added
##	21-01-09	(v)  Density descriptor added
##	19-01-09	(v)  Minor change (input file name no longer const)
##	14-01-09	(v)  Added some normalized descriptors and pockerpicker criteria
##	01-04-08	(v)  Comments UTD
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Clean the structure of the code... It could be done in a much better way

*/




/**
   ## FUNCTION: 
	dpocket
  
   ## SPECIFICATION: 
	Dpocket main function. Simple loop is performed over all files.
  
   ## PARAMETRES:
	@ s_dparams *par: Parameters of the programm
  
   ## RETURN:
	void
  
*/
void dpocket(s_dparams *par)
{
	int i, j ;
	FILE *fout[3] ;

	if(par) {
	/* Opening output file file */

		fout[0] = fopen(par->f_exp,"w") ;
		fout[1] = fopen(par->f_fpckp,"w") ;
		fout[2] = fopen(par->f_fpcknp,"w") ;

		if(fout[0] && fout[1] && fout[2]) {

		/* Writing column names */
	
			for( i = 0 ; i < 3 ; i++ ) {
				fprintf(fout[i], M_DP_OUTP_HEADER) ;
				for( j = 0 ; j < 20 ; j++ ) fprintf(fout[i], " %s", get_aa_name3(j));
				fprintf(fout[i], "\n");
			}
	
		/* Begins dpocket */
			for(i = 0 ; i < par->nfiles ; i++) {
				fprintf(stdout, "<dpocket>s %d/%d - %s:",
						i+1, par->nfiles, par->fcomplex[i]) ;

                                print_number_of_objects_in_memory();

				desc_pocket(par->fcomplex[i], par->ligs[i], par, fout) ;
                                print_number_of_objects_in_memory();

				if(i == par->nfiles - 1) fprintf(stdout,"\n") ;
				else fprintf(stdout,"\r") ;

				fflush(stdout) ;
			}

			for( i = 0 ; i < 3 ; i++ ) fclose(fout[i]) ;
		}
		else {
			if(! fout[0]) {
				fprintf(stdout, "! Output file <%s> couldn't be opened.\n", 
						par->f_exp) ;
			}
			else if (! fout[1]) {
				fprintf(stdout, "! Output file <%s> couldn't be opened.\n", 
						par->f_fpckp) ;
			}
			else {
				fprintf(stdout, "! Output file <%s> couldn't be opened.\n", 
						par->f_fpcknp) ;
			}
		}
	}
}

/**
   ## FUNCTION: 
    desc_pocket
  
   ## SPECIFICATION: 
	@ const char fcomplexe[] : File containing the PDB
	@ const char ligname[]   : Ligand resname identifier
	@ s_dparams *par         : Parameters
	@ FILE *f[3]             : The 3 FILE * to write output in
  
   ## PARAMETRES:
  
   ## RETURN:
  
*/
void desc_pocket(char fcomplexe[], const char ligname[], s_dparams *par, 
				 FILE *f[3]) 
{
	c_lst_pockets *pockets = NULL ;
	s_lst_vvertice *verts = NULL ;
	
	s_atm **interface = NULL ;
	s_desc *edesc ;
	s_atm **lig = NULL,
		  **patoms ;

	float vol, ovlp, dst = 0.0, tmp, c4, c5 ;
	int nal = 0,
		nai = 0,	/* Number of atoms in the interface */
		nbpa ;
	int j ;

/*
	fprintf(stdout, "dpocket: Loading pdb... ") ; fflush(stdout) ;
*/
	s_pdb *pdb_cplx_l = rpdb_open(fcomplexe, ligname, M_KEEP_LIG, 0,par->fpar);
	s_pdb *pdb_cplx_nl = rpdb_open(fcomplexe, ligname, M_DONT_KEEP_LIG, 0,par->fpar) ;
	
	if(! pdb_cplx_l || !pdb_cplx_nl || pdb_cplx_l->natm_lig <= 0) {
		if(pdb_cplx_l->natm_lig <= 0) {
			fprintf(stdout, "ERROR - No ligand %s found in %s.\n", ligname, fcomplexe) ;

		}
		else fprintf(stdout, "ERROR - PDB file %s could not be opened\n", fcomplexe) ;
		
		return ;
	}

	rpdb_read(pdb_cplx_l, ligname, M_KEEP_LIG, 0,par->fpar) ;
	rpdb_read(pdb_cplx_nl, ligname, M_DONT_KEEP_LIG, 0,par->fpar) ;
/*
	fprintf(stdout, " OK\n") ;
*/

	lig = pdb_cplx_l->latm_lig ;
	nal = pdb_cplx_l->natm_lig ;

        /*check if there are multiple ligand mols*/
        int n_lig_molecules=1;
        char chain_tmp[2];
        int resnumber_tmp;
        strcpy(chain_tmp,lig[0]->chain);
        resnumber_tmp = lig[0]->res_id;
        
        for (j = 1 ; j < nal ; j++) {
            if(strcmp(chain_tmp,lig[j]->chain) !=0 || resnumber_tmp!=lig[j]->res_id){
                n_lig_molecules++;
                strcpy(chain_tmp,lig[j]->chain);
                resnumber_tmp =lig[j]->res_id;
            }
        }
        
		/* Getting explicit interface using the known ligand */
/*
		fprintf(stdout, "dpocket: Explicit pocket definition... \n") ; 
		fflush(stdout) ;
*/
	pockets = search_pocket(pdb_cplx_nl, par->fpar,pdb_cplx_l) ;
	if(pockets == NULL) {
		fprintf(stdout, "ERROR - No pocket found for %s\n", fcomplexe) ;
		return ;
	}
        else write_out_fpocket(pockets, pdb_cplx_nl, fcomplexe);
/*
	verts = load_vvertices(pdb_cplx_nl, 3, par->fpar->asph_min_size,
						   par->fpar->asph_max_size) ;
*/

	verts = pockets->vertices ;
	edesc = allocate_s_desc() ;
	interface = get_explicit_desc(pdb_cplx_l, verts, lig, nal, par,
								   &nai, edesc) ;

	/* Writing output */
	vol = get_mol_volume_ptr(lig, nal, par->fpar->nb_mcv_iter) ;
	write_pocket_desc(fcomplexe, ligname, edesc, vol, 100.0, 0.0, 1.0, 1.0, f[0]) ;

	node_pocket *cur = pockets->first ;
	s_vvertice **pvert = NULL ;
	while(cur) {
		/* Get the natomic overlap */
		patoms = get_vert_contacted_atms(cur->pocket->v_lst, &nbpa) ;
		ovlp = atm_corsp(interface, nai, patoms, nbpa) ;

		/* Get the smallest distance of the ligand to the pocket
		   (PocketPicker criteria) */
		for (j = 0 ; j < nal ; j++) {
			tmp = dist(lig[j]->x, lig[j]->y, lig[j]->z,
					   cur->pocket->bary[0], cur->pocket->bary[1],
					   cur->pocket->bary[2]) ;
			if(j == 0) dst = tmp ;
			else {
				if(tmp < dst) dst = tmp ;
			}
		}

		/* Get the consensus criteria too */
		pvert = get_pocket_pvertices(cur->pocket) ;

		c4 = count_atm_prop_vert_neigh( lig, pdb_cplx_l->natm_lig,
									    pvert, cur->pocket->size, M_CRIT4_D,n_lig_molecules) ;
		c5 = count_pocket_lig_vert_ovlp(lig, pdb_cplx_l->natm_lig,
										pvert, cur->pocket->size, M_CRIT5_D) ;

		/* */
		if(ovlp > 40.0 || dst < 4.0) {
			write_pocket_desc(fcomplexe, ligname, cur->pocket->pdesc, vol,
							  ovlp, dst, c4, c5, f[1]) ;
		}
		else {
			write_pocket_desc(fcomplexe, ligname, cur->pocket->pdesc, vol,
							  ovlp, dst, c4, c5, f[2]) ;
		}
		my_free(patoms) ;
                my_free(pvert);
		cur = cur->next ;
	}

	/* Free memory */
	c_lst_pocket_free(pockets) ;
	my_free(interface) ;
        my_free(edesc);
	free_pdb_atoms(pdb_cplx_l) ;
	free_pdb_atoms(pdb_cplx_nl) ;
	
}

/**
   ## FUNCTION: 
	get_explicit_desc
  
   ## SPECIFICATION: 
	Determine the explicit pocket (see comments at the top of the file), and
	calculate descriptors (and fill the input structure) 
  
   ## PARAMETRES:
	@ s_pdb *pdb_cplx_l     : The pdb structure
	@ s_lst_vvertice *verts : The vertices found
	@ s_atm **lig           : Atoms of the ligand
	@ int nal               : Number of atom in the ligand
	@ s_dparams *par        : Parameters
	@ int *nai              : OUTPUT Number of atom in the interface
	@ s_desc *desc          : OUTPUT Descriptors
  
   ## RETURN:
	s_atm **: List of pointer to atoms defining the explicit pocket.
	plus nai and desc are filled.
  
*/
s_atm** get_explicit_desc(s_pdb *pdb_cplx_l, s_lst_vvertice *verts, s_atm **lig, 
						  int nal, s_dparams *par, int *nai, s_desc *desc)
{
	int nvn = 0 ;	/* Number of vertices in the interface */

	s_atm **interface = NULL ;

/*
	fprintf(stdout, "dpocket: Determning explicit interface... ") ; 
	fflush(stdout) ;
*/
	
	if(par->interface_method == M_INTERFACE_METHOD2) {
	/* Use the distance-based method to define the interface */
		interface = get_mol_atm_neigh(	lig, nal, pdb_cplx_l->latoms_p,
										pdb_cplx_l->natoms,
										par->interface_dist_crit, nai) ;
	}
	else {
	/* Use the voronoi vertices-based method to define the interface */
		
		interface = get_mol_ctd_atm_neigh(lig, nal, verts->pvertices, verts->nvert,
										  par->interface_dist_crit,
										  M_INTERFACE_SEARCH, nai) ;
	}

	/* Get a tab of pointer for interface's vertices to send a correct argument 
	 * type to set_descriptors */
	s_vvertice **tpverts = get_mol_vert_neigh(lig, nal, verts->pvertices, verts->nvert,
											  par->interface_dist_crit, &nvn) ;
	
	/* Ok we have the interface and the correct vertices list, now calculate 
	 * descriptors and write it.
	 **/
/*
	fprintf(stdout, "dpocket: Calculating descriptors... ") ; fflush(stdout) ;
*/
	set_descriptors(interface, *nai, tpverts, nvn, desc, par->fpar->nb_mcv_iter,pdb_cplx_l,par->fpar->flag_do_asa_and_volume_calculations);
/*
	fprintf(stdout, " OK\n") ;
*/

	/* Free memory */
	my_free(tpverts) ;

	return interface ;
}

/**
   ## FUNCTION: 
	write_pocket_desc
  
   ## SPECIFICATION: 
     Write pocket descriptors into a file.
  
   ## PARAMETRES:
    @ const char fc[] : Name of the pdb file
	@ const char l[]  : Resname of the ligand
	@ s_desc *d       : Stucture of descriptors
	@ float lv        : Ligand volume
	@ float ovlp      : Overlap
	@ FILE *f         : Buffer to write in
  
   ## RETURN:
    void
  
*/
void write_pocket_desc(const char fc[], const char l[], s_desc *d, float lv, 
					   float ovlp, float dst, float c4, float c5, FILE *f)
{
	int status = 0 ;
	if(dst < 4.0) status = 1 ;

	int c6 = (c4 >= M_CRIT4_VAL && c5 >= M_CRIT5_VAL) ?1:0 ;
	float c6_c = ((c4 - M_CRIT4_VAL)/ (1-M_CRIT4_VAL)) + ((c5 - M_CRIT5_VAL)/ (1-M_CRIT5_VAL)) ;

	fprintf(f, M_DP_OUTP_FORMAT, M_DP_OUTP_VAR(fc, l, ovlp, status, dst, c4, c5, c6, c6_c, lv, d)) ;

	int i ;
	for(i = 0 ; i < 20 ; i++) fprintf(f, " %3d", d->aa_compo[i]) ;
	
	fprintf(f, "\n") ;
}
