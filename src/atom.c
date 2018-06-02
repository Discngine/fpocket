
#include "../headers/atom.h"
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
## FILE 					atom.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##	This file should be used to deal with atoms. The corresponding
##	header contains a structure that define an atoms and its 
##	properties, like it's vdW radius, its coordinates ...
##	Several information related to the PDB format are also available.
##
##	In this file one will find most of functions that deal with atoms
##	structures.
##
## MODIFICATIONS HISTORY
##
##	28-11-08	(v)  Comments UTD
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Merge with pertable.c
##	(v) Add a function to write all known atomic properties for a given atom type
##	(v) Maybe implement a structure for a list of atoms instead of a tab.
##	(v) Check and update if necessary comments of each function!!

*/


/**
   ## FUNCTION: 
	get_mol_mass
  
   ## SPECIFICATION:
	Calculate mass of a molecule represented by a list of atoms. (structure)
	Perform a simple sum of atoms mass.
  
   ## PARAMETRES:
	@ s_atm *atoms : List of atoms structures
	@ int natoms   : Number of atoms
  
   ## RETURN:
	float: mass of the molecule
  
*/
float get_mol_mass(s_atm *latoms, int natoms)
{
	float mass = 00.0 ;
        int i ;
	if(latoms) {
		for(i = 0 ; i < natoms ; i++) {
			mass += latoms[i].mass ;
		}
	}
	return mass ; 
}

/**
   ## FUNCTION: 
	get_mol_mass_ptr
  
   ## SPECIFICATION:
	Same as previous, but using different input type (array of pointers)
  
   ## PARAMETRES:
	@ s_atm **atoms : List of pointers to atom structures
	@ int natoms    : Number of atoms
  
   ## RETURN:
	float: mass of the molecule
  
*/
float get_mol_mass_ptr(s_atm **latoms, int natoms)
{
	float mass = 00.0 ;
        int i ;
	if(latoms) {
		
		for(i = 0 ; i < natoms ; i++) {
			mass += latoms[i]->mass ;
		}
	}
	return mass ; 
}

/**
   ## FUNCTION: 
	set_mol_barycenter_ptr
  
   ## SPECIFICATION:
	Calculate the barycenter of a molecule represented by a list of atoms 
    pointers.
  
   ## PARAMETRES:
	@ s_atm **atoms	: List of pointers to atoms structures
	@ int natoms	: Number of atoms
	@ float bary[3]	: OUTPUT: Where to store the calculated barycenter
  
   ## RETURN:
	void (the OUTPUT is set using the input parameter bary)
  
*/
void set_mol_barycenter_ptr(s_atm **latoms, int natoms, float bary[3])
{
	float xsum = 0.0, 
		  ysum = 0.0,
		  zsum = 0.0 ;
        int i ;
	if(latoms) {
		
		for(i = 0 ; i < natoms ; i++) {
			xsum += latoms[i]->x ;
			ysum += latoms[i]->y ;
			zsum += latoms[i]->z ;
		}
	}

	bary[0] = xsum / natoms ;
	bary[1] = xsum / natoms ;
	bary[2] = xsum / natoms ;
}

/**
   ## FUNCTION: 
	get_mol_volume_ptr
  
   ## SPECIFICATION: 
	Get an monte carlo approximation of the volume occupied by the atoms given 
	in argument (list of pointers).
  
   ## PARAMETRES:
	@ s_atm **atoms : List of pointer to atoms
	@ int natoms    : Number of atoms
	@ int niter     : Number of monte carlo iteration to perform
  
   ## RETURN:
	float: calculated volume (approximation).
  
*/
float get_mol_volume_ptr(s_atm **atoms, int natoms, int niter)
{
	int i = 0, j = 0,
		nb_in = 0;

	float xmin = 0.0, xmax = 0.0,
		  ymin = 0.0, ymax = 0.0,
		  zmin = 0.0, zmax = 0.0,
		  xtmp = 0.0, ytmp = 0.0, ztmp = 0.0,
		  xr   = 0.0, yr   = 0.0, zr   = 0.0,
		  vbox = 0.0 ;

	s_atm *acur = NULL ;

	/* First, search extrems coordinates to get a contour box of the molecule */
	for(i = 0 ; i < natoms ; i++) {
		acur = atoms[i] ;

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

	/* Next calculate the contour box volume */
	vbox = (xmax - xmin)*(ymax - ymin)*(zmax - zmin) ;

	/* Then apply monte carlo approximation of the volume.	 */
	for(i = 0 ; i < niter ; i++) {
		xr = rand_uniform(xmin, xmax) ;
		yr = rand_uniform(ymin, ymax) ;
		zr = rand_uniform(zmin, zmax) ;

		for(j = 0 ; j < natoms ; j++) {
			acur = atoms[j] ;
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

	/* Ok lets just return the volume Vpok = Nb_in/Niter*Vbox */
	return ((float)nb_in)/((float)niter)*vbox;
}

/**
   ## FUNCTION: 
	is_in_lst_atm
  
   ## SPECIFICATION: 
	Says wether an atom of id atm_id is in a list of atoms or not 
  
   ## PARAMETRES:
	@ s_atm **lst_atm :  List of atoms
    @ int nb_atms     : Number of atoms in the list
    @ int atm_id      : ID of the atom to look for.
  
   ## RETURN:
	1 if the atom is in the tab, 0 if not
  
*/
int is_in_lst_atm(s_atm **lst_atm, int nb_atm, int atm_id) 
{
	int i ;
	for(i = 0 ; i < nb_atm ; i++) {
		if(atm_id == lst_atm[i]->id) return 1 ;
	}

	return 0 ;
}


/**
   ## FUNCTION: 
	atm_corsp
  
   ## SPECIFICATION: 
	Calculate correspondance between two list of atoms, using the first list as
	reference.
  
   ## PARAMETRES:
	@ s_atm **al1 : First list
	@ int nal1    : Number of atoms of the first list
	@ s_atm **al2 : Second list
	@ int nal2    : Number of atoms of the second list
  
   ## RETURN:
	float: % of atoms of the first list present in the second list
  
*/
float atm_corsp(s_atm **al1, int nal1, s_atm **al2, int nal2) 
{
	int i, j,
		nb_atm_found = 0 ;
	s_atm *cural = NULL,
		  *curap ;
	
	if(nal1 <=0 || nal2 <= 0){
		return 0.0 ;
	}

	for(i = 0 ; i < nal1 ; i++) {
		for(j = 0 ; j < nal2 ; j++) {
			cural = al1[i] ;
			curap = al2[j] ;

			if(curap->res_id == cural->res_id && 
			( (curap->id == cural->id) || strcmp(cural->name, curap->name) == 0 ) ) {
				nb_atm_found++ ;
				break ;
			}
		}
	}

	
	return ((float)nb_atm_found)/((float)nal1)*100.0 ;
}

/**
   ## FUNCTION: 
	void print_atoms(FILE *f, s_atm *atoms, int natoms) 
  
   ## SPECIFICATION:
	Print list of atoms...
  
   ## PARAMETRES:
	@ FILE *f      : File to write in.
	@ s_atm *atoms : List of atoms
	@ int natoms   : Number of atoms
  
   ## RETURN:
  
*/
void print_atoms(FILE *f, s_atm *atoms, int natoms) 
{
	s_atm *atom = NULL ;
	int i ;
	for(i = 0 ; i < natoms ; i++) {
		atom = atoms + i ; 
		fprintf(f, "======== Atom %s (%d) ========\n", atom->name, atom->id) ;
		fprintf(f, "Type: '%s', Residu: '%s' (%d), Chain: '%s'\n",
					atom->type, atom->res_name, atom->res_id, atom->chain);
		fprintf(f, "x: %f, y: %f, z: %f, occ: %f, bfact: %f\n", 
					atom->x, atom->y, atom->z, atom->occupancy, atom->bfactor);
		fprintf(f, "symbol: '%s', charge: %d, mass: %f, vdw: %f\n", 
					atom->symbol, atom->charge, atom->mass, atom->radius);
	}
}

static const unsigned short n_mm_atom_charge_ST=8;

static const s_mm_atom_charge_a mm_atom_charge_ST[8] = 
{
	// Generic type VdWradius Well depth
	{ "Cn", 0.0},
        { "Nd", 0.5},
        { "Na", -0.5},
        { "Nc", 1.0},
        { "Oa", -0.5},
        { "Od", 0.5},
        { "Oc", -1.0},
        { "Sn", 0.0}
};

float get_charge_from_mm_atom_charge_ST(char c[2]){
    unsigned short i;
    for(i=0;i<n_mm_atom_charge_ST;i++){
        if(strncmp(c,mm_atom_charge_ST[i].name,2)==0) return (mm_atom_charge_ST[i].charge);
    }
    return(0.0);
}


//float get_receptor_atom_charge(s_atm *a){
//    if(a->charge!=0.0) return(a->charge);
//    char a_name[2];
//    if(strncmp(a->symbol,"C",1)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Cn"));
//    if(strncmp(a->symbol,"S",1)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Sn"));
//    if(strncmp(a->symbol,"O",1)==0){
//        if(strncmp(a->name,"OH",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Od"));
//        if(strncmp(a->name,"OG",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Od"));
//        if(strncmp(a->name,"OE",2)==0 || strncmp(a->name,"OD",2)==0) {
//            if(strncmp(a->res_name,"ASP",3)==0 ||strncmp(a->res_name,"GLU",3)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Oc"));
//            if(strncmp(a->res_name,"ASN",3)==0 ||strncmp(a->res_name,"GLN",3)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Oa"));
//        }
//        return(get_charge_from_mm_atom_charge_ST((char *)"Oa")); //backbone
//    }
//    if(strncmp(a->symbol,"N",1)==0){
//        if(strncmp(a->name,"NZ",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Nc")); //lysines
//        if(strncmp(a->name,"NH",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Nc")); //arginines
//        if(strncmp(a->name,"NE",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Nd")); //asn
//        if(strncmp(a->name,"ND",2)==0) return(get_charge_from_mm_atom_charge_ST((char *)"Nd")); //gln
//        return(get_charge_from_mm_atom_charge_ST((char *)"Nd")); //backbone
//    }
//    
//    return(0.0);
//}
