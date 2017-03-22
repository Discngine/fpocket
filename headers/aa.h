
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

#ifndef DH_AA
#define DH_AA

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

/* ------------------------------MACROS---------------------------------------*/

#define M_NB_AA 20  /**< number of amino acid macros*/
#define M_ALA_IDX 0 /**< 0 for ALA*/
#define M_ARG_IDX 1 /**< 1 for ARG*/
#define M_ASN_IDX 2 /**< 2 for ASN*/
#define M_ASP_IDX 3 /**< 3 for ASP*/
#define M_CYS_IDX 4 /**< 4 for CYS*/
#define M_GLN_IDX 5 /**< 5 for GLN*/
#define M_GLU_IDX 6 /**< 6 for GLU*/
#define M_GLY_IDX 7 /**< 7 for GLY*/
#define M_HIS_IDX 8 /**< 8 for HIS*/
#define M_ILE_IDX 9 /**< 9 for ILE*/
#define M_LEU_IDX 10 /**< 10 for LEU*/
#define M_LYS_IDX 11 /**< 11 for LYS*/
#define M_MET_IDX 12 /**< 12 for MET*/
#define M_PHE_IDX 13 /**< 13 for PHE*/
#define M_PRO_IDX 14 /**< 14 for PRO*/
#define M_SER_IDX 15 /**< 15 for SER*/
#define M_THR_IDX 16 /**< 16 for THR*/
#define M_TRP_IDX 17 /**< 17 for TRP*/
#define M_TYR_IDX 18 /**< 18 for TYR*/
#define M_VAL_IDX 19 /**< 19 for VAL*/


/* --------------------------- PUBLIC STRUCTURES ------------------------------*/

/**
	A structure for the modelisation of an amino acid
*/
typedef struct s_amino_a
{
	char name3[4] ; /**< name of the amino-acid (3 letter code)*/
	char code ; /**< one letter code for the amino acid*/

	float mw ; /**< molecular weight of the amino acid*/
	float volume; /**< volume score for each aa taken from http://www.info.univ-angers.fr/~gh/Idas/proprietes.htm*/
	float hydrophobicity; /**< hydrophobicity score for each aa taken from Monera & al. Journal of Protein Science 1, 319-329 (1995)*/
	int charge, /**< crude net charge of each amino acid in pH 7*/
	 	polarity,  /**< polarity of each aa taken from http://www.info.univ-angers.fr/~gh/Idas/proprietes.htm*/
		func_grp ; /**< funct. groups of each aa taken from http://www.info.univ-angers.fr/~gh/Idas/proprietes.htm*/

} s_amino_a ;

/* -----------------------------PROTOTYPES------------------------------------*/

int get_aa_index(const char *name) ; 
char* get_aa_name3(const int index) ;

float get_aa_mw(const char *name) ;
float get_aa_volume_score(const char *name) ;
float get_aa_hydrophobicity_score(const char *name) ;
int get_aa_charge(const char *name)  ;
int get_aa_polarity(const char *name) ;
int get_aa_func_grp(const char *name) ;

float get_volume_score_from_idx(int aa_index) ;
float get_hydrophobicity_score_from_idx(int aa_index) ;
int get_charge_from_idx(int aa_index) ;
int get_polarity_from_idx(int aa_index) ;
int get_func_grp_from_idx(int aa_index) ;

#endif
