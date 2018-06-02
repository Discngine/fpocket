/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
#ifndef DH_ATOM
#define DH_ATOM

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "utils.h"

// --------------------------------MACROS------------------------------------ */



// -------------------------- PUBLIC STRUCTURES ----------------------------- */

/**
	A structure for the modelisation of an atom
*/
typedef struct s_atm
{
    int sort_x;                 /**< Index in the sorted tab by X coord */
    float vdw_radius;           /**< van der waals radius*/
    float vdw_eps;              /**< van der waals well depth */
    float radius;               /**< radii*/
    float guessed_charge;       /**< guessed atom charge, careful this is very far from classical FF's*/
    float x, y, z ;		/**< Coords */
    char name[5],		/**< Atom name */
         type[7],		/**< Atom type */
         chain[2],		/**< Chain name */
         symbol[3],		/**< Chemical symbol of the atom */
         res_name[8];		/**< Atom residue name */

    int id,			/**< Atom id */
        seen,                   /**< Say if we have seen this atom during a neighbor search */
        res_id,			/**< Atom residue ID */
        atype,
        charge,                 /**< Atom charge */
        abpa;                   /**< 1 if atom is an abpa, 0 otherwise*/	
    
    //short mm_type;     /**< crqppily assigned MM types to heavy atoms*/

    /* Optional fields */
    float mass,			/**< Mass */
          electroneg,		/**< Electronegativity */
          occupancy,		/**< Occupancy */
          bfactor,		/**< B-factor for christal structures */
          a0,                   /**< ASA of the atom at vdw+1.4A atom radius*/ 
          dA,                   /**< concavity of the atom environment (if <0 concave, >0 convex)*/
          abpa_sourrounding_prob;     /**< probability that the sourrounding of an atom (maybe abpa) corresponds to a putative apba sourrounding (hydrophobic)*/
            
    char pdb_insert, 		/**< PDB insertion code */
         pdb_aloc;		/**< PDB alternate location code */

    /*force field related things coming from topology files*/
    float ff_mass,              /**< FF Mass */
            ff_radius,		/**< Vdw radius */
            ff_charge;          /**< FF Partial charge*/
    float   ff_well_depth;      /**< van der waals well depth*/
    short ff_well_depth_set;    /**< flag if well depth correctly set or not*/
    char *ff_type;              /**< Atom type used for parameter lookup*/
            
    
    int atomic_num ;   		/**< Atomic number */

} s_atm ;

typedef struct s_mm_atom_type_a
{
	char name[2] ; /**< name of the type*/
	float radius;   /**< vdw radius */
        float w;        /**< well depth of LJ potential*/

} s_mm_atom_type_a ;

typedef struct s_mm_atom_charge_a
{
	char name[3] ; /**< name of the type*/
	float charge;   /**< vdw radius */
        
} s_mm_atom_charge_a ;


/* --------------------------------PROTOTYPES--------------------------------- */

float get_mol_mass(s_atm *latoms, int natoms) ;
float get_mol_mass_ptr(s_atm **latoms, int natoms);
void set_mol_barycenter_ptr(s_atm **latoms, int natoms, float bary[3]) ;
float get_mol_volume_ptr(s_atm **atoms, int natoms, int niter) ;

int is_in_lst_atm(s_atm **lst_atm, int nb_atm, int atm_id) ;	
float atm_corsp(s_atm **al1, int nl1, s_atm **pocket_neigh, int nal2) ; 

void print_atoms(FILE *f, s_atm *atoms, int natoms) ;
float get_charge_from_mm_atom_charge_ST(char c[2]);
float get_receptor_atom_charge(s_atm *a);
#endif