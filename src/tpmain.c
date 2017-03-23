 
#include "../headers/tpmain.h"

/*

## GENERAL INFORMATION
##
## FILE 					tpmain.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
## MODIFICATIONS HISTORY
##
##	28-11-08	(v)  Comments OK
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

/**
   ## FUNCTION:
	int main(int argc, char *argv[])
  
   ## SPECIFICATION:
	Main program for tpocket!
  
*/
int main(int argc, char *argv[])
{
	s_tparams *par = get_tpocket_args(argc, argv) ;
        
	if(par && par->nfiles > 0) {
            printf("%d files\n",par->nfiles);
		test_fpocket(par) ;
	}

	free_tparams(par) ;
  	free_all() ;

	return 0 ;
}

