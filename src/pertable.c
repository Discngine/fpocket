
#include "../headers/pertable.h"
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
## FILE 					pertable.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
## This file defines the periodic element table. It's strongly based on the
## VMD source code.
##
## MODIFICATIONS HISTORY
##
##  17-03-09    (v)  Added function testing if a string is a valid element symbol
##	28-11-08	(v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Merge with atom.c
##

*/


static const int ST_nelem = 112 ; /**< number of elements in the @static const char *ST_pte_symbol list*/

static const char *ST_pte_symbol[] = { 
	"X",  "H",  "He", "Li", "Be", "B",  "C",  "N",  "O",  "F",  "Ne",
	"Na", "Mg", "Al", "Si", "P" , "S",  "Cl", "Ar", "K",  "Ca", "Sc",
	"Ti", "V",  "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", 
	"As", "Se", "Br", "Kr", "Rb", "Sr", "Y",  "Zr", "Nb", "Mo", "Tc",
	"Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I",  "Xe",
	"Cs", "Ba", "La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb",
	"Dy", "Ho", "Er", "Tm", "Yb", "Lu", "Hf", "Ta", "W",  "Re", "Os",
	"Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn", "Fr",
	"Ra", "Ac", "Th", "Pa", "U",  "Np", "Pu", "Am", "Cm", "Bk", "Cf",
	"Es", "Fm", "Md", "No", "Lr", "Rf", "Db", "Sg", "Bh", "Hs", "Mt",
	"Ds", "Rg"
} ; /**< element list*/


static const int ST_prot_nelem = 6 ;
static const char *ST_pte_prot_symbol[] = {
	"H",  "C",  "N",  "O", "S", "P"
} ;

static const int ST_nucl_acid_nelem = 5 ;
static const char *ST_pte_nucl_acid_symbol[] = {
	"H",  "C",  "N",  "O", "P"
} ;

static const int ST_n_standard_res_names = 26;
static const char *ST_standard_res_names [] = {
    "GLY", "LEU", "ILE", "TRP", "MET", "SER", "THR", "LYS", "ARG", "ASN",
    "GLN", "GLU", "ASP", "CYS", "PRO", "HIS", "TYR", "PHE", "VAL", "ALA",
    "HIE", "HID", "HIP", "HSD", "HSE", "HSP"
} ;

static const int ST_n_standard_nucl_acid_names = 9;
static const char *ST_standard_nucl_acid_names [] = {
    "dG","dC", "dT","dA","A","C","T","G","U"
} ;


static const float ST_pte_electronegativity[] = {
	 0.0,  2.1, 0.98,  1.0,  1.5,  2.0,  2.5,  3.0,  3.5,  4.0, -1.0,
	 0.9,  1.2,  1.5,  1.8,  2.1,  2.5,  3.0, -1.0,  0.8,  1.0,  1.3,
	 1.5,  1.6,  1.6,  1.5,  1.8,  1.8,  1.9,  1.9,  1.6,  1.8,  2.0,
	 2.2,  2.4,  2.9, -1.0,  0.8,  1.0,  1.2,  1.3,  1.6,  2.0,  1.9,
	 2.2,  2.2,  2.3,  1.9,  1.7,  1.7,  1.8,  2.0,  2.1,  2.6,  2.6,
	 0.8,  0.9, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0,
	-1.0, -1.0, -1.0, -1.0, -1.0, -1.0,  1.3,  1.5,  1.7,  1.9,  2.2,
	 2.2,  2.2,  2.4,  1.9,  1.8,  1.8,  1.9,  2.0,  2.2, -1.0,  0.7,
	 0.9,  1.1,  1.3,  1.5,  1.7,  1.3,  1.3,  1.3,  1.3,  1.3,  1.3,
	 1.3,  1.3,  1.3,  1.3, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0, -1.0,
	-1.0, -1.0
} ; /**< electronegativity list*/

static const float ST_pte_mass[] = { 
	/* X  */ 0.00000, 1.00794, 4.00260, 6.941, 9.012182, 10.811,  
	/* C  */ 12.0107, 14.0067, 15.9994, 18.9984032, 20.1797, 
	/* Na */ 22.989770, 24.3050, 26.981538, 28.0855, 30.973761,
	/* S  */ 32.065, 35.453, 39.948, 39.0983, 40.078, 44.955910,
	/* Ti */ 47.867, 50.9415, 51.9961, 54.938049, 55.845, 58.9332,
	/* Ni */ 58.6934, 63.546, 65.409, 69.723, 72.64, 74.92160, 
	/* Se */ 78.96, 79.904, 83.798, 85.4678, 87.62, 88.90585, 
	/* Zr */ 91.224, 92.90638, 95.94, 98.0, 101.07, 102.90550,
	/* Pd */ 106.42, 107.8682, 112.411, 114.818, 118.710, 121.760, 
	/* Te */ 127.60, 126.90447, 131.293, 132.90545, 137.327, 
	/* La */ 138.9055, 140.116, 140.90765, 144.24, 145.0, 150.36,
	/* Eu */ 151.964, 157.25, 158.92534, 162.500, 164.93032, 
	/* Er */ 167.259, 168.93421, 173.04, 174.967, 178.49, 180.9479,
	/* W  */ 183.84, 186.207, 190.23, 192.217, 195.078, 196.96655, 
	/* Hg */ 200.59, 204.3833, 207.2, 208.98038, 209.0, 210.0, 222.0, 
	/* Fr */ 223.0, 226.0, 227.0, 232.0381, 231.03588, 238.02891,
	/* Np */ 237.0, 244.0, 243.0, 247.0, 247.0, 251.0, 252.0, 257.0,
	/* Md */ 258.0, 259.0, 262.0, 261.0, 262.0, 266.0, 264.0, 269.0,
	/* Mt */ 268.0, 271.0, 272.0
}; /**< atomic masses*/

/*
	 A. Bondi, J. Phys. Chem., 68, 441 - 452, 1964, 
	.Phys.Chem., 100, 7384 - 7391, 1996.
 */
static const float ST_pte_rvdw[] = {
	/* X  */ 1.5, 1.2, 1.4, 1.82, 2.0, 2.0,  
	/* C  */ 1.7, 1.55, 1.52, 1.47, 1.54, 
	/* Na */ 2.27, 1.73, 2.0, 2.1, 1.8,
	/* S  */ 1.8, 1.75, 1.88, 2.75, 2.0, 2.0,
	/* Ti */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Ni */ 1.63, 1.4, 1.39, 1.07, 2.0, 1.85,
	/* Se */ 1.9, 1.85, 2.02, 2.0, 2.0, 2.0, 
	/* Zr */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Pd */ 1.63, 1.72, 1.58, 1.93, 2.17, 2.0, 
	/* Te */ 2.06, 1.98, 2.16, 2.0, 2.0,
	/* La */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Eu */ 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Er */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* W  */ 2.0, 2.0, 2.0, 2.0, 1.72, 1.66,
	/* Hg */ 1.55, 1.96, 2.02, 2.0, 2.0, 2.0, 2.0,
	/* Fr */ 2.0, 2.0, 2.0, 2.0, 2.0, 1.86,
	/* Np */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Md */ 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0,
	/* Mt */ 2.0, 2.0, 2.0
}; /**< VDW radii for different elements*/

/**
   ## FUNCTION:
	pte_get_mass
  
   ## SPECIFICATION:
	Returns the mass for a given element
  
   ## PARAMETERS:	
	@ const char *symbol: The symbol of the element in the periodic table
  
   ## RETURN:
	float: mass corresponding to symbol
  
*/
float pte_get_mass(const char *symbol)
{	
	char atom[3] ;
	if (symbol != NULL) {
		atom[0] = (char) toupper((int) symbol[0]);
		atom[1] = (char) tolower((int) symbol[1]);	
		atom[2] = '\0' ;
	
		int i ;
		for (i = 0; i < ST_nelem ; i++) {
			if ( (ST_pte_symbol[i][0] == atom[0]) && (ST_pte_symbol[i][1] == atom[1]) ) {
				
				return ST_pte_mass[i] ;
			}
		}
	}


	return -1 ;
}

/**
   ## FUNCTION:
	pte_get_vdw_ray
  
   ## SPECIFICATION:
	Returns the van der walls radius for a given element
  
   ## PARAMETERS:	
	@ const char *symbol: The symbol of the element in the periodic table
  
   ## RETURN:
	float: vdw radius corresponding to symbol
  
*/
float pte_get_vdw_ray(const char *symbol)
{
	char atom[3] ;

	if (symbol != NULL) {
		atom[0] = (char) toupper((int) symbol[0]);
		atom[1] = (char) tolower((int) symbol[1]);
		atom[2] = '\0' ;
	
		int i ;
		for (i = 0; i < ST_nelem ; i++) {
			if ( (ST_pte_symbol[i][0] == atom[0]) && (ST_pte_symbol[i][1] == atom[1]) ) {
				return ST_pte_rvdw[i] ;
			}
		}
	}

	return -1 ;
}

/**
   ## FUNCTION:
	pte_get_enegativity
  
   ## SPECIFICATION:
	Returns the electronegativity (Pauling) value for a given element
  
   ## PARAMETERS:	
	@ const char *symbol: The symbol of the element in the periodic table
  
   ## RETURN:
	float: electrobegativity of Pauling corresponding to symbol
  
*/
float pte_get_enegativity(const char *symbol)
{
	char atom[3] = "" ;

	if (symbol != NULL) {
		atom[0] = (char) toupper((int) symbol[0]);
		atom[1] = (char) tolower((int) symbol[1]);
		atom[2] = '\0' ;
	
		int i ;
		for (i = 0; i < ST_nelem ; i++) {
			if ( (ST_pte_symbol[i][0] == atom[0]) && (ST_pte_symbol[i][1] == atom[1]) ) {
				return ST_pte_electronegativity[i] ;
			}
		}
	}

	return -1 ;
}



/**
   ## FUNCTION:
	pte_get_element_from_number
  
   ## SPECIFICATION:
	Returns the symbol for a given element through the atomic number
  
   ## PARAMETERS:	
	@ const char *symbol: The symbol of the element in the periodic table
  
   ## RETURN:
	char*: atom element symbol
  
*/
char *pte_get_element_from_number(int atomicnumber)
{
	char *tmp=malloc(sizeof(char)*3) ;
	if(atomicnumber>0 && atomicnumber<112){
	
		tmp[0] = ST_pte_symbol[atomicnumber][0] ;
		tmp[1] = ST_pte_symbol[atomicnumber][1] ;
		return tmp;
	} else {
		tmp[0]='-';
		tmp[1]='1';
	}
	tmp[2]='\0';
	return tmp;
}

/**
   ## FUNCTION:
	pte_get_enegativity_from_number
  
   ## SPECIFICATION:
	Returns the electronegativity (Pauling) value for a given element
  
   ## PARAMETERS:	
	@ const char *symbol: The symbol of the element in the periodic table
  
   ## RETURN:
	float: electrobegativity of Pauling corresponding to symbol
  
*/
float pte_get_enegativity_from_number(int atomicnumber)
{
	if(atomicnumber>0 && atomicnumber<112)
		return ST_pte_electronegativity[atomicnumber] ;
		
	

	return -1 ;
}


/**
   ## FUNCTION:
	is_valid_element
  
   ## SPECIFICATION:
	Check if a given string corresponds to an atom element.
  
   ## PARAMETERS:
	@ const char *str : The string to test
	@ int tcase       : If = 1, dont take into account the case.
  
   ## RETURN:
	int: -1 if the strig is not an atom element, the index in the periodic table if so.
  
*/
int is_valid_element(const char *str, int ignore_case)
{
	if(str == NULL) return -1 ;
	if(strlen(str) <= 0) return -1 ;

	/* Use temporary variable to work on the string */
	int i ;
	char str_tmp[strlen(str)+1] ;
	strcpy(str_tmp, str) ;

	/* Remove spaces and case if asked*/
	str_trim(str_tmp) ;
	if(ignore_case == 1) {
		str_tmp[0] = tolower(str_tmp[0]) ;
		str_tmp[1] = tolower(str_tmp[1]) ;
	}

	/* Loop over */
	for (i = 0; i < ST_nelem ; i++) {
		char tmp[3] ;
		tmp[0] = ST_pte_symbol[i][0] ;
		tmp[1] = ST_pte_symbol[i][1] ;

		/* Remove case if asked */
		if(ignore_case == 1) {
			tmp[0] = tolower(tmp[0]) ;
			tmp[1] = tolower(tmp[1]) ;
		}
		tmp[2] = '\0' ;

		/* Do the comparison*/
		if(strcmp(str_tmp, tmp) == 0) return i ;
	}
	
	return -1 ;
}

/**-----------------------------------------------------------------------------
   ## FUNCTION:
	int element_in_std_res(char *res_name)
   -----------------------------------------------------------------------------
   ## SPECIFICATION:
	Compare resname to the list of standard protein resnames. Return 1 if
        resname is in this list, 0 else.
   -----------------------------------------------------------------------------
   ## PARAMETRES:
	@ char *res_name	: The current residue name
   -----------------------------------------------------------------------------
   ## RETURN: int
   -----------------------------------------------------------------------------
*/
int element_in_std_res(char *res_name){
    int i;
    for(i=0;i<ST_n_standard_res_names;i++){
        if(!strncmp(res_name, ST_standard_res_names[i],3)) return 1;
    }
    return 0;
}

/**-----------------------------------------------------------------------------
   ## FUNCTION:
	int element_in_nucl_acid(char *res_name)
   -----------------------------------------------------------------------------
   ## SPECIFICATION:
	Compare resname to the list of standard nucleic acid residues. Return 1 if
        resname is in this list, 0 else.
   -----------------------------------------------------------------------------
   ## PARAMETRES:
	@ char *res_name	: The current residue name
   -----------------------------------------------------------------------------
   ## RETURN: int
   -----------------------------------------------------------------------------
*/
int element_in_nucl_acid(char *res_name){
    int i;
    for(i=0;i<ST_n_standard_nucl_acid_names;i++){
        if(!strncmp(res_name, ST_standard_nucl_acid_names[i],3)) return 1;
    }
    return 0;
}

int is_water(char *res_name){
    if(!strncmp(res_name, "HOH",3)||!strncmp(res_name, "WAT",3)) return 1;
    return 0;
}


/**-----------------------------------------------------------------------------
   ## FUNCTION:
	is_valid_prot_element
   -----------------------------------------------------------------------------
   ## SPECIFICATION:
	Check if a given string corresponds to an atom element.
   -----------------------------------------------------------------------------
   ## PARAMETERS:
	@ const char *str : The string to test
	@ int tcase       : If = 1, dont take into account the case.
   -----------------------------------------------------------------------------
   ## RETURN:
	int: -1 if the strig is not an atom element, the index in the periodic table if so.
   -----------------------------------------------------------------------------
*/
int is_valid_prot_element(const char *str, int ignore_case)
{
	if(str == NULL) return -1 ;
	if(strlen(str) <= 0) return -1 ;
	/* Use temporary variable to work on the string */
	int i ;
	char str_tmp[strlen(str)+1] ;
	strcpy(str_tmp, str) ;


	/* Remove spaces and case if asked*/
	str_trim(str_tmp) ;
	if(ignore_case == 1) {
		str_tmp[0] = tolower(str_tmp[0]) ;
		str_tmp[1] = tolower(str_tmp[1]) ;
	}

	/* Loop over standard protein element table*/
	for (i = 0; i < ST_prot_nelem ; i++) {
		char tmp[3] ;
		tmp[0] = ST_pte_prot_symbol[i][0] ;
		tmp[1] = ST_pte_prot_symbol[i][1] ;

		/* Remove case if asked */
		if(ignore_case == 1) {
			tmp[0] = tolower(tmp[0]) ;
			tmp[1] = tolower(tmp[1]) ;
		}
		tmp[2] = '\0' ;

		/* Do the comparison*/
		if(strncmp(str_tmp, tmp,1) == 0) return i ;
	}

	return -1 ;
}


/**-----------------------------------------------------------------------------
   ## FUNCTION:
	is_valid_nucl_acid_element
   -----------------------------------------------------------------------------
   ## SPECIFICATION:
	Check if a given string corresponds to an atom element.
   -----------------------------------------------------------------------------
   ## PARAMETERS:
	@ const char *str : The string to test
	@ int tcase       : If = 1, dont take into account the case.
   -----------------------------------------------------------------------------
   ## RETURN:
	int: -1 if the strig is not an atom element, the index in the periodic table if so.
   -----------------------------------------------------------------------------
*/
int is_valid_nucl_acid_element(const char *str, int ignore_case)
{
	if(str == NULL) return -1 ;
	if(strlen(str) <= 0) return -1 ;
	/* Use temporary variable to work on the string */
	int i ;
	char str_tmp[strlen(str)+1] ;
	strcpy(str_tmp, str) ;


	/* Remove spaces and case if asked*/
	str_trim(str_tmp) ;
	if(ignore_case == 1) {
		str_tmp[0] = tolower(str_tmp[0]) ;
		str_tmp[1] = tolower(str_tmp[1]) ;
	}

	/* Loop over standard protein element table*/
	for (i = 0; i < ST_nucl_acid_nelem ; i++) {
		char tmp[3] ;
		tmp[0] = ST_pte_nucl_acid_symbol[i][0] ;
		tmp[1] = ST_pte_nucl_acid_symbol[i][1] ;

		/* Remove case if asked */
		if(ignore_case == 1) {
			tmp[0] = tolower(tmp[0]) ;
			tmp[1] = tolower(tmp[1]) ;
		}
		tmp[2] = '\0' ;

		/* Do the comparison*/
		if(strncmp(str_tmp, tmp,1) == 0) return i ;
	}

	return -1 ;
}


