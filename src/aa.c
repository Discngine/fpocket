#include "../headers/aa.h"

/*

## GENERAL INFORMATION
##
## FILE 				aa.c
## AUTHORS				P. Schmidtke and V. Le Guilloux
## LAST MODIFIED		21-04-12 (p)
##
## SPECIFICATIONS
##
##	This file contains severals functions that allow one to
##	deal with amino-acids and their properties. Properties
##	should be stored in the static variable ST_aa, that
##	contains for each amino-acids, several properties
##	stored in a specific structure.
##
## MODIFICATIONS HISTORY
##
##      21-04-12        (p)  modifications to amino acid ordering in s_amino_a ST_aa to match IDX values in header!
##	28-11-08	(v)  Comments UTD
##	20-11-08	(v)  Added molecular weight
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Get more accurate descriptors, namely for the volume and charge *score*
##	(v) Check and update if necessary comments of each function!!

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
	Several amino-acid properties, taken from:
	http://www.info.univ-angers.fr/~gh/Idas/proprietes.htm

	Hydrophobicity taken from :
	http://www.sigmaaldrich.com/Area_of_Interest/Biochemicals/PolyAmino_Acids/Reference_Chart.html

        Monera & al. Journal of Protein Science 1, 319-329 (1995)

	Molecular weight taken from:
	http://www.expasy.ch/tools/pscale/Molecularweight.html
 
*/
static const s_amino_a ST_aa[20] = 
{
	// Name Code Molecular weight VolumeScore Hydrophobicity Charge Polarity func_grp
	{ "ALA", 'A',  89.0, 2.0,  41.0,  0, 0, 2 },
	{ "ARG", 'R', 174.0, 7.0, -14.0,  1, 1, 5 },
	{ "ASN", 'N', 132.0, 3.0, -28.0,  0, 1, 3 },
	{ "ASP", 'D', 133.0, 3.0, -55.0, -1, 1, 3 },
	{ "CYS", 'C', 121.0, 3.0,  49.0,  0, 0, 6 },
	{ "GLN", 'Q', 146.0, 4.0, -10.0,  0, 1, 3 },
	{ "GLU", 'E', 147.0, 4.0, -31.0, -1, 1, 3 },
	{ "GLY", 'G',  75.0, 1.0,   0.0,  0, 0, 2 },
	{ "HIS", 'H', 155.0, 4.0,   8.0,  1, 1, 1 },
	{ "ILE", 'I', 131.0, 5.0,  99.0,  0, 0, 2 },
	{ "LEU", 'L', 131.0, 5.0,  97.0,  0, 0, 2 },
	{ "LYS", 'K', 146.0, 6.0, -23.0,  1, 1, 5 },
	{ "MET", 'M', 149.0, 5.0,  74.0,  0, 0, 5 },
	{ "PHE", 'F', 165.0, 6.0, 100.0,  0, 0, 1 },
	{ "PRO", 'P', 115.0, 3.0, -46.0,  0, 0, 2 },
	{ "SER", 'S', 105.0, 2.0,  -5.0,  0, 1, 4 },
	{ "THR", 'T', 119.0, 3.0,  13.0,  0, 1, 4 },
	{ "TRP", 'W', 204.0, 8.0,  97.0,  0, 1, 1 },
	{ "TYR", 'Y', 181.0, 7.0,  63.0,  0, 1, 1 },
	{ "VAL", 'V', 117.0, 4.0,  76.0,  0, 0, 2 }
} ;

//be careful to keep amino-acid order with above list !!!

/*#define M_ALA_IDX 0 *< 0 for ALA*/
/*#define M_ARG_IDX 1 *< 1 for ARG*/
/*#define M_ASN_IDX 2 *< 2 for ASN*/
/*#define M_ASP_IDX 3 *< 3 for ASP*/
/*#define M_CYS_IDX 4 *< 4 for CYS*/
/*#define M_GLN_IDX 5 *< 5 for GLN*/
/*#define M_GLU_IDX 6 *< 6 for GLU*/
/*#define M_GLY_IDX 7 *< 7 for GLY*/
/*#define M_HIS_IDX 8 *< 8 for HIS*/
/*#define M_ILE_IDX 9 *< 9 for ILE*/
/*#define M_LEU_IDX 10 *< 10 for LEU*/
/*#define M_LYS_IDX 11 *< 11 for LYS*/
/*#define M_MET_IDX 12 *< 12 for MET*/
/*#define M_PHE_IDX 13 *< 13 for PHE*/
/*#define M_PRO_IDX 14 *< 14 for PRO*/
/*#define M_SER_IDX 15 *< 15 for SER*/
/*#define M_THR_IDX 16 *< 16 for THR*/
/*#define M_TRP_IDX 17 *< 17 for TRP*/
/*#define M_TYR_IDX 18 *< 18 for TYR*/
/*#define M_VAL_IDX 19 *< 19 for VAL*/
/**
   ## FUNCTION: 
	get_aa_name3
   
   ## SPECIFICATION: 
	Return the name of AA given in argument (index in the static table)
   
   ## PARAMETRES:
	@ const int index: Index of the AA in the tab
   
   ## RETURN:
	char *: Name if index is valid, NULL if not.
   
*/
char* get_aa_name3(const int index) 
{
	if(index < M_NB_AA && index >= 0) {
		return (char*)ST_aa[index].name3 ;
	}
	return NULL ;
}

/**
   ## FUNCTION: 
	get_aa_index
   
   ## SPECIFICATION: 
	Return the index of AA given in argument (3letter code representation) in the
	static AA tab.
   
   ## PARAMETRES:
	@ const char *name: Amno acid name (3 letter code representation)
   
   ## RETURN:
	int: index of the given amino acid, -1 if not found in the tab
   
*/
int get_aa_index(const char *name) 
{
	int i,
		aa_index = -1 ;

	for(i = 0 ; i < M_NB_AA ; i++) {
		if(toupper(name[0]) == ST_aa[i].name3[0] && toupper(name[1]) == ST_aa[i].name3[1] 
		&& toupper(name[2]) == ST_aa[i].name3[2]   ) {
			aa_index = i ;
			break ;
		}
	}

	return aa_index ;
}

/*********** Getting information from an AA name in the static tab ***********/


/**
   ## FUNCTION: 
	get_aa_mw
  
   ## SPECIFICATION: 
	Return the molecular weight of AA given in argument
  
   ## PARAMETRES:
	@ const int index: Index of the AA in the tab
  
   ## RETURN:
	float: Molecular weight if the index is valid, NULL if not.
  
*/
float get_aa_mw(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].mw ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return -1.0 ;
}

/**
   ## FUNCTION: 
	get_aa_volume_score
  
   ## SPECIFICATION: 
	Return the volume score of given amino acid (very approximative...)
  
   ## PARAMETRES:
	@ const char *name: Amno acid name (3 letter code representation)
  
   ## RETURN:
	float: volume score, -1 if aa not found in the tab
  
*/
float get_aa_volume_score(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].volume ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return -1.0 ;
}

/**
   ## FUNCTION: 
	get_aa_hydrophobicity_score
  
   ## SPECIFICATION: 
	Return the hydrophobicity score of given amino acid
  
   ## PARAMETRES:
	@ const char *name: Amno acid name (3 letter code representation)
  
   ## RETURN:
	float: hydrophobicity score, -1 if aa not found in the tab
  
*/
float get_aa_hydrophobicity_score(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].hydrophobicity ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return -1.0 ;
}

/**
   ## FUNCTION: 
	get_aa_charge
  
   ## SPECIFICATION: 
	Return the charge score of given amino acid
  
   ## PARAMETRES:
	const char *name: Amno acid name (3 letter code representation)
  
   ## RETURN:
	charge (positiv, negativ, neutral, see header for more details), 0 if aa 
	not found in the tab
  
*/
int get_aa_charge(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].charge ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return 0 ;
}

/**
   ## FUNCTION: 
	get_aa_polarity
  
   ## SPECIFICATION: 
	Return the polarity score of given amino acid
  
   ## PARAMETRES:
	@ const char *name: Amno acid name (3 letter code representation)
  
   ## RETURN:
	int polarity (polar, apolar), 0 if aa not found in the tab
  
*/
int get_aa_polarity(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].polarity ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return -1 ;
}

/**
   ## FUNCTION: 
	get_func_grp_from_idx
  
   ## SPECIFICATION: 
	Return the functional group type of the given amino acid
  
   ## PARAMETRES:
	@ const char *name: Amno acid name (3 letter code representation)
  
   ## RETURN:
	int: functional group id
  
*/
int get_aa_func_grp(const char *name) 
{
	int aa_index = get_aa_index(name) ;

	if(aa_index != -1) {
		return ST_aa[aa_index].func_grp ;
	}/*
	else {
		fprintf(stderr, "! Amino acid '%s' could not be found in property table...\n", name);
	}*/

	return -1 ;
}


/************** Getting information from an AA index in the static tab **************/


/**
   ## FUNCTION: 
	get_volume_score_from_idx
  
   ## SPECIFICATION: 
	Return the volume score of given amino acid
  
   ## PARAMETRES:
	@ int aa_index: Index of the amino acid in the tab
  
   ## RETURN:
	float: volume score, -1 if aa not found in the tab
  
*/
float get_volume_score_from_idx(int aa_index) 
{
	if(aa_index < M_NB_AA && aa_index >= 0){
		return ST_aa[aa_index].volume ;
	}/*
	else {
		fprintf(stderr, "! Amino acid %d could not be found in property table...\n", aa_index);
	}*/

	return -1.0 ;
}

/**
   ## FUNCTION: 
	get_hydrophobicity_score_from_idx
  
   ## SPECIFICATION: 
	Return the hydrophobicity score of given amino acid
  
   ## PARAMETRES:
	@ int aa_index: Index of the amino acid in the tab
  
   ## RETURN:
	float hydrophobicity score, -1 if aa not found in the tab
  
*/
float get_hydrophobicity_score_from_idx(int aa_index) 
{
	if(aa_index < M_NB_AA && aa_index >= 0) {
		return ST_aa[aa_index].hydrophobicity ;
	}/*
	else {
		fprintf(stderr, "! Amino acid %d could not be found in property table...\n", aa_index);
	}*/

	return -1.0 ;
}

/**
   ## FUNCTION: 
	get_charge_from_idx
  
   ## SPECIFICATION: 
	Return the charge score of given amino acid
  
   ## PARAMETRES:
	@ int aa_index: Index of the amino acid in the tab
  
   ## RETURN:
	int charge (positiv, negativ, neutral, see header for more details), 0 if aa 
	not found in the tab
  
*/
int get_charge_from_idx(int aa_index) 
{
	if(aa_index < M_NB_AA && aa_index >= 0){
		return ST_aa[aa_index].charge ;
	}/*
	else {
		fprintf(stderr, "! Amino acid %d could not be found in property table...\n", aa_index);
	}*/

	return 0 ;
}

/**
   ## FUNCTION: 
	get_polarity_from_idx
  
   ## SPECIFICATION: 
	Return the polarity score of given amino acid
  
   ## PARAMETRES:
	@ int aa_index: Index of the amino acid in the tab
  
   ## RETURN:
	int: polarity (polar, apolar), -1 if aa not found in the tab
  
*/
int get_polarity_from_idx(int aa_index) 
{
	if(aa_index < M_NB_AA && aa_index >= 0) {
		return ST_aa[aa_index].polarity ;
	}/*
	else {
		fprintf(stderr, "! Amino acid %d could not be found in property table...\n", aa_index);
	}*/

	return -1 ;
}

/**
   ## FUNCTION: 
	get_func_grp_from_idx
  
   ## SPECIFICATION: 
	Return the functional group type of the given amino acid
  
   ## PARAMETRES:
	@ int aa_index: Index of the amino acid in the tab
  
   ## RETURN:
	int: functional group id
  
*/
int get_func_grp_from_idx(int aa_index) 
{
	if(aa_index < M_NB_AA && aa_index >= 0) {
		return ST_aa[aa_index].func_grp ;
	}/*
	else {
		fprintf(stderr, "! Amino acid %d could not be found in property table...\n", aa_index);
	}*/

	return -1 ;
}
