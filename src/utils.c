
#include "../headers/utils.h"

/*

## GENERAL INFORMATION
##
## FILE 					utils.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##  Some usefull functions
##
## MODIFICATIONS HISTORY
##
##	22-01-09	(v)  Added function to split a string using a given separator
##	02-12-08	(v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
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

**/




static int ST_is_rand_init = 0 ; /**< Says wether we have seeded the generator. */

#ifdef MD_USE_GSL	/* GSL */
static gsl_rng *ST_r = NULL ;
#endif				/* /GSL */

/**
   ## FONCTION: 
	start_rand_generator
  
   ## SPECIFICATION: 
	Initialize generator. This initialisation depends on the library to use.
  
   ## PARAMETRES:
  
   ## RETURN: 
	void
  
*/


short file_exists(const char * filename)
{
    FILE * file = fopen(filename, "r");
    if (file)
    {
        fclose(file);
        return 1;
    }
    return 0;
}

void start_rand_generator(void) 
{
	if(ST_is_rand_init == 0) {

	#ifdef MD_USE_GSL	/* use GSL if defined */
/* 		fprintf(stdout, "> GSL generator used\n"); */
		if(ST_r != NULL) {
			gsl_rng_free(ST_r);
		}

		gsl_rng_default_seed = time(NULL);

		const gsl_rng_type *T = M_GEN_MTWISTER ;
		ST_r = gsl_rng_alloc(T);
		gsl_rng_set (ST_r, gsl_rng_default_seed);

	#else				/* /GSL */

/* 		fprintf(stdout, "> Standard C generator used\n"); */
		srand((int)time(NULL));

	#endif
		ST_is_rand_init = 1 ;
	}
}


/**
   ## FONCTION: 
	rand_uniform
  
   ## SPECIFICATION: 
	Generate a random number between 0 and 1 using a uniform distribution.
  
   ## PARAMETRES:
    @ float min : Lower boundary 
    @ float max : Upper boundary
  
   ## RETURN: 
	double: A uniform random number between min and max
  
*/
float rand_uniform(float min, float max)
{
	if(ST_is_rand_init == 0){
		start_rand_generator() ;
	}

	float rnd = 0.0 ;	

	#ifdef MD_USE_GSL	/* GSL */
		rnd = gsl_rng_uniform(ST_r) * (max-min) ;
	#else				/* /GSL */
   		rnd = ((float)rand()/(float)RAND_MAX) * (max-min) ;
	#endif

	return min+rnd ;
}

/**
   ## FUNCTION: 
	 tab_str* f_readl(const char fpath[], int nchar_max) 
  
   ## SPECIFICATION: 
	Read file line and store them in a tab_str structure. The function skip empty
	lines.
  
   ## PARAMETRES:
	@ const char *fpath : Full path of the file.
	@ int nchar_max     : A number giving the max number of caractere in each line.
  
   ## RETURN: 
	tab_str* : Pointer to the sab_str structure containing lines of the file.
  
*/
tab_str* f_readl(const char *fpath, int nchar_max) 
{
/*  Variable declaration */

	FILE *f ;
	int i, n,
		nb_string ;
	char *cline,
		 **f_lines ;
	tab_str *lines ;

/*  Variable initialisation */

	i = nb_string = 0 ;
	cline = (char *) my_malloc(nchar_max*sizeof(char)) ;

/*  How many lines is there in the file? */

 	f = fopen(fpath, "r") ;
	if(f == NULL) {
		my_free(cline) ;
		return NULL ;
	}
	
	while(fgets(cline, nchar_max, f) != NULL) {
		if(strcmp("\n", cline) != 0) {
			nb_string ++ ;
		}
	}
	fclose(f) ;

/*  Once we have the number of lines, lets allocate memory and get the lines */

	f = fopen(fpath, "r") ;
	if(f == NULL) {
		my_free(cline) ;
		return NULL ;
	}

	lines = (tab_str *)my_malloc(sizeof(tab_str)) ;
	f_lines = (char **)my_malloc(nb_string*sizeof(char*)) ;
	
/*  Getting lines. */

	while(fgets(cline, nchar_max, f) != NULL) {
		if(strcmp("\n", cline) != 0) {
			n = strlen(cline) ;
			if(cline[n-1] == '\n') {
				n-- ;
				cline[n] = '\0' ;
			}
			
			char *line =(char *) my_malloc((n+1)*sizeof(char)) ;
			memcpy (line, cline, n+1);
	
			f_lines[i] = line ;
			i++ ;
		}
	}

	lines->nb_str  = nb_string ;
	lines->t_str = f_lines ;

/*  Free memory and close file */

	fclose(f) ;
	my_free(cline);
 
	return lines ;
}

/**
   ## FUNCTION:
	float_get_max_in_2D_array

   ## SPECIFICATION:
	receive the maximum value in a give column in a 2D float array

   ## PARAMETRES:
	@ **t float : pointer to pointer to float (2D float array)
        @ n int : size of the array (number of lines)
        @ col int : column on which the maximum is to extract

   ## RETURN:
	float
 **/
/*TODO: replace this by a divde & conquer approach*/
float float_get_max_in_2D_array(float **t,size_t n,int col){
    float c=0.0,m=-1e15;
    size_t i;
    for(i=0;i<n;i++){
        c=t[i][col];
        if(c>m)m=c;
    }
    return m;
}

/**
   ## FUNCTION:
	float_get_min_in_2D_array

   ## SPECIFICATION:
	receive the minimum value in a give column in a 2D float array

   ## PARAMETRES:
	@ **t float : pointer to pointer to float (2D float array)
        @ n int : size of the array (number of lines)
        @ col int : column on which the minimum is to extract

   ## RETURN:
	float
 **/
/*TODO: replace this by a divde & conquer approach*/
float float_get_min_in_2D_array(float **t,size_t n,int col){
    float c=0.0,m=1e15;
    size_t i;
    for(i=0;i<n;i++){
        c=t[i][col];
        if(c<m)m=c;
    }
    return m;
}


/**
   ## FUNCTION: 
	free_tab_str
  
   ## SPECIFICATION: 
	Free the given structure
  
   ## PARAMETRES:
	@ tab_str* strings : Pointer to the tab_str to print
  
   ## RETURN:
	void
  
*/
void free_tab_str(tab_str *tstr) 
{
	if(tstr) {
		int i ;
		if(tstr->t_str) {
			for(i = 0 ; i < tstr->nb_str ; i++) {
				if(tstr->t_str[i]) {
					my_free(tstr->t_str[i]) ;
					tstr->t_str[i] = NULL ;
				}
			}
			my_free(tstr->t_str) ;
		}

		my_free(tstr) ;
	}
}

/**
   ## FUNCTION: 
	print_tab_str
  
   ## SPECIFICATION: 
	Print strings contained in the given tab_str.
  
   ## PARAMETRES:
	@ tab_str* strings : Pointer to the tab_str to print
  
   ## RETURN:
	void
  
*/
void print_tab_str(tab_str* strings)
{
	if(strings) {
		int i ;
		char **strs = strings->t_str ;
		
		printf("\n-- String tab: \n");
		for (i = 0 ; i < strings->nb_str ; i++) {
			fprintf(stdout, "<%s>\n", strs[i]) ;
		}
		printf("--\n") ;
	}
	else {
		fprintf(stderr, "! Argument NULL in print_tab_str().\n");
	}
}


/**
   ## FUNCTION: 
	str_is_number
  
   ## SPECIFICATION: 
	Check if the string given in argument is a number.
  
   ## PARAMETRES:
	@ char *str      : The string to deal with
	@ const int sign : The first caractere is the sign?
  
   ## RETURN:
	int: 1 if its a valid number, 0 else
  
*/
int str_is_number(const char *str, const int sign)
{
	int ok = 0 ;

	if (str != NULL) {
		const char *p = str ;
		int c = *p ;

		/* Checkthe first caractere if the sign has to be taken into account */
		if (sign) {

			if(isdigit (c) || ((c == '+' || c == '-') && str[1] != 0)) {
				ok = 1 ;
			}
			p++;
		}
		else {
			ok = 1 ;
		}

		if (ok) {
			while (*p != 0) {
 				if (!isdigit (*p)) {
					ok = 0;
					break ;
				}
				p++;
			}
		}
	}
	else {
		fprintf(stderr, "! Argument NULL in str_is_number().\n");
	}

	return ok;
}


/**
   ## FUNCTION: 
	str_is_float
  
   ## SPECIFICATION: 
	Check if the string given in argument is a valid float.
  
   ## PARAMETRES:
	@ char *str      : The string to deal with
	@ const int sign : The first caractere is the sign?
  
   ## RETURN:
	int:  1 if its a valid float, 0 else
  
*/
int str_is_float(const char *str, const int sign)
{
	int ok = 0 ;
	int nb_dot = 0 ;

	if (str != NULL) {
		const char *p = str ;
		int c = *p ;

		/* Checkthe first caractere if the sign has to be taken into account */
		if (sign) {	

			if(isdigit (c) || ((c == '+' || c == '-') && str[1] != 0)) {
				ok = 1 ;
			}
			p++;
		}
		else {
			ok = 1 ;
		}

		if (ok) {
			while (*p != 0) {
 				if (!isdigit (*p)) {
					if((*p) == '.') {
						nb_dot++ ;
						if(nb_dot > 1) {
							ok = 0;
							break ;
						}
					}
					else {
						ok = 0;
						break ;
					}
				}
				p++;
			}
		}
	}
	else {
		fprintf(stderr, "! Argument NULL in str_is_number().\n");
	}

	return ok;
}

/**
   ## FUNCTION: 
	in_tab
  
   ## SPECIFICATION: 
	Check if val is present in tab.
  
   ## PARAMETRES:
	@ int *tab: Tab
	@ int size: Size of the tab
	@ int val: Value to check
  
   ## RETURN:
	int: 1 if val is in tab, 0 if not
  
*/
int in_tab(int *tab, int size, int val)
{
	if(tab) {
		int i ;
		for(i = 0 ; i < size ; i++) {
			if(tab[i] == val) return 1 ;
		}
	}
	
	return 0 ;
}

/**
   ## FUNCTION: 
	index_of
  
   ## SPECIFICATION: 
	Check if val is present in tab and return its index if so
  
   ## PARAMETRES:
	@ int *tab: Tab
	@ int size: Size of the tab
	@ int val: Value to check
  
   ## RETURN:
	int: index if val is in tab, -1 if not
  
*/
int index_of(int *tab, int size, int val) 
{
	if(tab) {
		int i;
		for(i = 0 ; i < size ; i++) {
			if(val == tab[i]) return i ;
		}
	}
	
	return -1 ;
}

/**
   ## FUNCTION: 
	str_trim
  
   ## SPECIFICATION: 
	Remove spaces from a given string
  
   ## PARAMETRES:
	@ char *str: String to deal with
  
   ## RETURN:
  
*/
void str_trim(char *str) 
{
	int i, len;
	
	len = strlen(str);
	while (len > 0 && str[len-1] == ' ') {
		str[len-1] = '\0';
		len--;
	}
	
	while (len > 0 && str[0] == ' ') {
		for (i=0; i < len; i++) str[i] = str[i+1];
		len--;
	}
}

/**
   ## FUNCTION: 
	 extract_path
  
   ## SPECIFICATION: 
	 Extract path from a string
  
   ## PARAMETRES:
	@ char *str  : String to deal with
	@ char *dest : OUTPUT The destination string
  
   ## RETURN:
  
*/
void extract_path(char *str, char *dest) 
{
	char sav ;	
	char *pstr = str,
		 *last_backsl = NULL ;
	
	while(*pstr) {
	/* Advance in the path name while it is possible */
		if(*pstr == '/') {
		/* If we encounter a '/', save its position */
			last_backsl = pstr ;
		}
		pstr ++ ;
	}

	if(last_backsl) {
	/* If we have found one '/' at least, copy the path */
		sav = *(last_backsl) ;
		(*last_backsl) = '\0' ;

		strcpy(dest, str) ;
		(*last_backsl) = sav ;	
	}
	else {
	/* If no '/' has been found, just return a dot as current folder  */
		dest[0] = '\0' ;
	}
}

/**
   ## FUNCTION: 
	 extract_ext
  
   ## SPECIFICATION: 
	 Get rid of the extension of a string (.pdb eg.)
  
   ## PARAMETRES:
	@ char *str: String to deal with
	@ char *dest : OUTPUT The destination string
  
   ## RETURN:
  
*/
void extract_ext(char *str, char *dest) 
{
	char *pstr = str,
		 *last_dot = NULL ;
	
	while(*pstr) {
	/* Advance in the path name while it is possible */
		if(*pstr == '.') {
		/* If we encounter a '/', save its position */
			last_dot = pstr ;
		}
		pstr ++ ;
	}

	if(last_dot) {
		strcpy(dest, last_dot+1) ;
	}
	else {
	/* If no '/' has been found, just return a dot as current folder  */
		dest[0] = '\0' ;
	}
}

/**
   ## FUNCTION: 
	remove_path
  
   ## SPECIFICATION: 
	Remove the path from a string
  
   ## PARAMETRES:
	@ char *str: INOUT String to deal with
  
   ## RETURN:
     The input string is modified
  
*/
void remove_path(char *str) 
{
	int i, filelen ;
	char *pstr = str,
		 *last_backsl = NULL ;
	
	while(*pstr) {
	/* Advance in the path name while it is possible */
		if(*pstr == '/') {
		/* If we encounter a '/', save its position */
			last_backsl = pstr ;
		}
		pstr = pstr + 1 ;
	}

	if(last_backsl) {
	/* If we have found one '/' at least, copy the path, else dont do anything */
		last_backsl = last_backsl + 1 ;
		filelen = strlen(last_backsl) ;
		for(i = 0 ; i < filelen ; i++) {
			str[i] = *(last_backsl+i) ;
		}
		str[i] = '\0' ;
	}
}

/**
   ## FUNCTION: 
    remove_ext
  
   ## SPECIFICATION: 
    Remove the extention of a given string
  
   ## PARAMETRES:
	@ char *str: INOUT String to deal with
  
   ## RETURN:
    The input string is modified
  
*/
void remove_ext(char *str)
{
	char *pstr = str,
		 *last_dot = NULL ;
	
	while(*pstr) {
	/* Advance in the path name while it is possible */
		if(*pstr == '.') {
		/* If we encounter a '/', save its position */
			last_dot = pstr ;
		}
		pstr ++ ;
	}

	if(last_dot) {
		*last_dot = '\0' ;
	}
}

/**
   ## FUNCTION: 
	 fopen_pdb_check_case
  
   ## SPECIFICATION:
	Try to open a pdb file. If the open failed, put the 4 letter before extention
	at the lower case and try again.
	This function assume that the file name has the format path/file.pdb !
  
   ## PARAMETERS:
	@ char *name       : The string to parse
	@ const char *mode : Opening mode
  
   ## RETURN: 
	The file, NULL if the openning fails.
  
*/
FILE* fopen_pdb_check_case(char *name, const char *mode) 
{
	FILE *f = fopen(name, mode) ;
	if(!f) {
		int len = strlen(name) ;
		name[len-5] = toupper(name[len-5]);
		name[len-6] = toupper(name[len-6]);
		name[len-7] = toupper(name[len-7]);
		name[len-8] = toupper(name[len-8]);

		f = fopen(name, mode) ;
		if(!f) {
			name[len-5] = tolower(name[len-5]);
			name[len-6] = tolower(name[len-6]);
			name[len-7] = tolower(name[len-7]);
			name[len-8] = tolower(name[len-8]);
			f = fopen(name, mode) ;
			
		}
	}

	return f ;
	
}

/**
   ## FONCTION:
	tab_str* str_split_memopt(const char *str, const char sep)
  
   ## SPECIFICATION:
	Split the string given using a char separator. Every token will be stored in
	a tab_str structure which will be returned by the function.
	Empty tokens (two consecutives separator) will be stored as an empty string
	containing only the NULL caractere.

	We optimise here the memory, and allocate the exact memory for each token.

	!! MEMORY OF THE RETURNED ARGUMENT MUST BE FREED BY CALLING free_tab_str() !!

	COULD BE OPTIMISED.
  
   ## PARAMETRES:
	@ const char *str: The string to deal with
	@ const char sep: The separator
  
   ## RETURN:
	tab_str*: A pointer to a structure tab_str which will contain all elements of
	the string.
  
*/
tab_str* str_split(const char *str, const int sep)
{
	tab_str *ts = (tab_str*) my_calloc(1, sizeof(tab_str)) ;

	const char *pstr = str ;	// A temp pointer to str
	int n = 1 ;					// At least one token (no separator in the string)

	//  Count the number of token

	while(*pstr) {
		if(*pstr == sep) {
			n++ ;
		}
		pstr ++ ;
	}

	ts->nb_str = n ;
	ts->t_str = (char**)my_calloc(n, sizeof(char*)) ;

	//  If there is more than one token, split the string

	if(n > 1) {
		char **ptab_str = ts->t_str ;
		char *s_pctok = NULL ;			// A pointer to the current created token
		const char *s_beg = str ;		// A pointer used to copy each token from s_beg to next separator

		size_t tok_i = 0,
			   size_tok = 1 ;

		pstr = str ;

		//  Allocate exact memory and copy each tokens

		while(*pstr) {
			if(*pstr == sep) {
				ptab_str[tok_i] = (char*)my_calloc(size_tok, sizeof(char)) ;
				s_pctok = ptab_str[tok_i] ;

				while(*s_beg != *pstr) {
					*s_pctok = *s_beg ;
					s_pctok ++ ;
					s_beg ++ ;
				}
				*s_pctok = '\0' ;

				size_tok = 0 ;
				tok_i ++ ;
				s_beg ++ ;		// Skip the separator for next token
			}
			size_tok ++ ;
			pstr ++ ;
		}

	//  Copy the last token

		ptab_str[tok_i] =  (char*)my_calloc(size_tok, sizeof(char)) ;
		s_pctok = ptab_str[tok_i] ;
		while(*s_beg) {
			*s_pctok = *s_beg ;
			s_pctok ++ ;
			s_beg ++ ;
		}
		*s_pctok = '\0' ;
	}
	else {
	//  One token only, just copy the original string
		ts->t_str[0] =  (char*)my_calloc(strlen(str), sizeof(char));
		strcpy(ts->t_str[0], str);
	}

	return ts ;

}
