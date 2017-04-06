

#include "../headers/mdpmain.h"

/*

## -- GENERAL INFORMATION
##
## FILE 					mdpmain.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## -- SPECIFICATIONS
##
##	Top function to call dpocket routines. Get programm parameters,
##	call function and free memory.
##
## -- MODIFICATIONS HISTORY
##
##	28-11-08	(v)  Added COPYRIGHT DISCLAMER
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##
## -- TODO or SUGGESTIONS
##

*/

/*
    COPYRIGHT

    Peter Schmidtke, hereby
	claims all copyright interest in the program “mdpocket” (which
	performs protein cavity detection on multiple conformations of proteins) 
        written by Peter Schmidtke.

    Peter Schmidtke      01 Decembre 2012

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
	Main program for dpocket!

*/
int main(int argc, char *argv[])
{
    s_mdparams *par = get_mdpocket_args(argc, argv) ;
//    s_topology *topol=NULL;
//    print_mdparams(par, stdout) ;
    /*if(par->fpar->topology_path[0]!=0){
        topol=read_topology(par->fpar);
    }*/
    if(par && par->fwantedpocket[0]==0) mdpocket_detect(par) ; /* run only pocket detection, 1st way of running mdpocket*/
    else if(par) mdpocket_characterize(par);                    /* run pocket characterization 2nd way of running mdpocket*/

    free_mdparams(par) ;
    //free_all() ;

    return 0 ;
}

