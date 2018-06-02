
#include "../headers/dparams.h"
/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
/**

## GENERAL INFORMATION
##
## FILE 					dparams.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##	Handle parameters (parse the command line and sore values)
##	for the dpocket programm.
##
## MODIFICATIONS HISTORY
##
##	28-11-08	(v)  Comments UTD + relooking
##	27-11-08	(v)  Minor Relooking
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Check and update if necessary comments of each function!!
##	(v) Review the main function and handle all possible crashes.
##

 */

/**
   ## FUNCTION:
        init_def_dparams
  
   ## SPECIFICATION:
        Initialisation of default parameters.
  
   ## PARAMETRES: void
  
   ## RETURN: 
        s_dparams*: Pointer to allocated paramers.
  
 */
s_dparams* init_def_dparams(void) {
    s_dparams *par = (s_dparams*) my_malloc(sizeof (s_dparams));

    par->f_exp = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_fpckp = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_fpcknp = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));

    strcpy(par->f_exp, M_OUTPUT_FILE1_DEFAULT);
    strcpy(par->f_fpckp, M_OUTPUT_FILE2_DEFAULT);
    strcpy(par->f_fpcknp, M_OUTPUT_FILE3_DEFAULT);

    par->fcomplex = NULL;
    par->ligs = NULL;
    par->nfiles = 0;
    par->interface_dist_crit = M_VERT_LIG_NEIG_DIST;
    par->interface_method = M_INTERFACE_METHOD1;

    return par;
}

/**
   ## FUNCTION: 
        get_dpocket_args
  
   ## SPECIFICATION: 
        This function analyse the user's command line and parse it to store 
        parameters for the descriptor calculator programm.
  
   ## PARAMETRES:
        @ int nargs   : Number of arguments
        @ char **args : Arguments of main program
  
   ## RETURN:
        s_dparams*: Pointer to parameters
  
 */
s_dparams* get_dpocket_args(int nargs, char **args) {
    int i,
            status = 0,
            nstats = 0,
            res;

    char *str_list_file = NULL;

    s_dparams *par = init_def_dparams();
    par->fpar = get_fpocket_args(nargs, args);

    /* Read arguments by flags */
    for (i = 1; i < nargs; i++) {
        if (strlen(args[i]) == 2 && args[i][0] == '-') {
            switch (args[i][1]) {
                case M_DPAR_DISTANCE_CRITERIA:
                    if (i < nargs - 1) status += parse_dist_crit(args[++i], par);
                    else {
                        fprintf(stdout, "! Distance criteria defining the protein-ligand interface is missing.\n");
                        status += 1;
                    }
                    break;

                case M_DPAR_INTERFACE_METHOD1:
                    par->interface_method = M_INTERFACE_METHOD1;
                    par->interface_dist_crit = M_VERT_LIG_NEIG_DIST;
                    break;

                case M_DPAR_INTERFACE_METHOD2:
                    par->interface_method = M_INTERFACE_METHOD2;
                    par->interface_dist_crit = M_LIG_NEIG_DIST;
                    break;

                case M_DPAR_OUTPUT_FILE:
                    if (nstats >= 1) fprintf(stdout, "! More than one single file for the stats output file has been given. Ignoring this one.\n");
                    else {
                        if (i < nargs - 1) {
                            if (strlen(args[++i]) < M_MAX_FILE_NAME_LENGTH) {
                                remove_ext(args[i]);
                                sprintf(par->f_exp, "%s_exp.txt", args[i]);
                                sprintf(par->f_fpckp, "%s_fp.txt", args[i]);
                                sprintf(par->f_fpcknp, "%s_fpn.txt", args[i]);
                            } else fprintf(stdout, "! Output file name is too long... Keeping default.");
                        } else {
                            fprintf(stdout, "! Invalid output file name argument missing.\n");
                            status += 1;
                        }
                    }
                    break;

                case M_DPAR_INPUT_FILE:
                    if (i < nargs - 1) str_list_file = args[++i];
                    else {
                        fprintf(stdout, "! Input file name argument missing.\n");
                        status += 1;
                    }
                    break;

                default:
                    //  Check fpocket parameters!
                    if (!is_fpocket_opt(args[i][1])) {
                        fprintf(stdout, "> Unknown option '%s'. Ignoring it.\n",
                                args[i]);
                    }
                    break;
            }
        }
    }

    if (status > 0) {
        free_dparams(par);
        par = NULL;
        print_dpocket_usage(stdout);
    } else {
        if (str_list_file) {
            res = add_list_complexes(str_list_file, par);
            if (res <= 0) {
                fprintf(stdout, "! No data has been read.\n");
                free_dparams(par);
                par = NULL;
                print_dpocket_usage(stdout);
            }
        }
        else {
            fprintf(stdout, "! No input file given... Try again :).\n");
            free_dparams(par);
            par = NULL;
            print_dpocket_usage(stdout);
        }
    }

    return par;
}

/**
   ## FUNCTION: 
        add_list_complexes
  
   ## SPECIFICATION: 
        Load a list of protein-ligand pdb file path. This file should have the 
        following format:

        complex_pdb_file	ligand_code
        complex_pdb_file2	ligand_code2
        complex_pdb_file3	ligand_code3
        (...)
 
        Each complexe-ligand set will be stored in the parameters structure.
  
   ## PARAMETRES:
        @ char *str_list_file : Path of the file containing all data
        @ s_dparams *par      : Structures that stores all thoses files
  
   ## RETURN: 
        int: Number of file read.
  
 */
int add_list_complexes(char *str_list_file, s_dparams *par) {
    FILE *f;
    int nread = 0,
            status;

    char buf[M_MAX_PDB_NAME_LEN * 2 + 6],
            complexbuf[M_MAX_PDB_NAME_LEN],
            ligbuf[5];

    /* Loading data. */
    f = fopen(str_list_file, "r");
    /*
            printf(str_list_file);
     */
    if (f) {
        while (fgets(buf, 210, f)) {
            /*
                                    printf("B: %s\n" , buf);
             */
            //			n = par->nfiles ;
            status = sscanf(buf, "%s\t%s", complexbuf, ligbuf);

            if (status < 2) {
                /*
                                                fprintf(stderr, "! Skipping row '%s' with bad format (status %d).\n",
                                                                                buf, status) ;
                 */
            } else {
                /*
                                                printf("%s %s\n", complexbuf, ligbuf );
                 */
                nread += add_complexe(complexbuf, ligbuf, par);
            }

        }
    } else {
        fprintf(stderr, "! File %s doesn't exists\n", str_list_file);
    }

    return nread;
}

/**
   ## FUNCTION: 
        add_complexe
  
   ## SPECIFICATION: 	
        Add a set of data to the list of set of data in the parameters. this function
        is used for the tpocket program only.
	
        The function will try to open the file, and data will be stored only if the
        file exists, and if the name of the ligand is valid.
  
   ## PARAMETERS:
        @ char *apo     : The apo path
        @ char *complex : The complex path
        @ char *ligan   : The ligand resname: a 4 letter (max!) 
        @ s_dparams *par: The structure than contains parameters.
  
   ## RETURN: 
        int: 1 if everything is OK, 0 if not.
  
 */
int add_complexe(char *complex, char *ligand, s_dparams *par) {
    int nm1, i, l;

    FILE *f = fopen_pdb_check_case(complex, "r");
    if (f) {
        l = strlen(ligand);
        if (strlen(ligand) >= 2) {
            for (i = 0; i < l; i++) ligand[i] = toupper(ligand[i]);

            nm1 = par->nfiles;
            par->nfiles += 1;

            par->ligs = (char**) my_realloc(par->ligs, (par->nfiles) * sizeof (char*));
            par->fcomplex = (char**) my_realloc(par->fcomplex, (par->nfiles) * sizeof (char*));

            par->fcomplex[nm1] = (char *) my_malloc((strlen(complex) + 1) * sizeof (char));
            par->ligs[nm1] = (char *) my_malloc((strlen(ligand) + 1) * sizeof (char));

            strcpy(par->fcomplex[nm1], complex);
            strcpy(par->ligs[nm1], ligand);

            fclose(f);
        } else {
            fprintf(stdout, "! The name given for the ligand is invalid or absent.\n");
            fclose(f);
            return 0;
        }

    } else {
        fprintf(stdout, "! The pdb file '%s' doesn't exists.\n", complex);
        return 0;
    }

    return 1;
}

/**
   ## FUNCTION: 
        parse_dist_crit
  
   ## SPECIFICATION: 	
        Parsing function for the distance criteria defining the protein-ligand 
        interface.
  
   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_dparams *p : The structure than will contain the parsed parameter
  
   ## RETURN: 
        0 if the parameter is valid (here a valid integer), 1 if not
  
 */
int parse_dist_crit(char *str, s_dparams *p) {
    if (str_is_float(str, M_NO_SIGN)) {
        p->interface_dist_crit = (float) atof(str);
    } else {
        fprintf(stdout, "! Invalid value (%s) given for the distance criteria defining the protein-ligand interface.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION: 
        print_dparams
  
   ## SPECIFICATION: 
        Print function, usefull to debug
  
   ## PARAMETRES:
        @ s_dparams *p : The structure than will contain the parsed parameter
        @ FILE *f      : The file to write in
  
   ## RETURN: 
    void
  
 */
void print_dparams(s_dparams *p, FILE *f) {

    if (p) {
        fprintf(f, "==============\nParameters of the program: \n");
        int i;
        for (i = 0; i < p->nfiles; i++) {
            fprintf(f, "> Protein %d: '%s', '%s'\n", i + 1, p->fcomplex[i], p->ligs[i]);
        }

        if (p->interface_method == M_INTERFACE_METHOD1)
            fprintf(f, "> Method used to define explicitely the interface atoms: contacted atom by alpha spheres.\n");
        else fprintf(f, "> Method used to define explicitely the interface atoms: ligand's neighbors.\n");

        fprintf(f, "> Distance used to define explicitely the interface: %f.\n",
                p->interface_dist_crit);

        fprintf(f, "==============\n");
    } else fprintf(f, "> No parameters detected\n");
}

/**
   ## FUNCTION: 
        print_dparams_usage
  
   ## SPECIFICATION: 
        Displaying usage of the programm in the given buffer
  
   ## PARAMETRES:
        @ FILE *f: buffer to print in
  
   ## RETURN: 
  
 */
void print_dpocket_usage(FILE *f) {
    f = (f == NULL) ? stdout : f;

    fprintf(f, M_DP_USAGE);
}

/**
   ## FUNCTION: 
        free_params
  
   ## SPECIFICATION: 
        Free parameters
  
   ## PARAMETRES: 
        @ s_dparams *p: Pointer to the structure to free
  
   ## RETURN: 
        void
  
 */
void free_dparams(s_dparams *p) {
    if (p) {
        if (p->ligs) {
            my_free(p->ligs);
            p->ligs = NULL;
        }

        if (p->fcomplex) {
            my_free(p->fcomplex);
            p->fcomplex = NULL;
        }

        if (p->f_exp) {
            my_free(p->f_exp);
            p->f_exp = NULL;
        }

        if (p->f_fpckp) {
            my_free(p->f_fpckp);
            p->f_fpckp = NULL;
        }

        if (p->f_fpcknp) {
            my_free(p->f_fpcknp);
            p->f_fpcknp = NULL;
        }

        free_fparams(p->fpar);

        my_free(p);
    }
}
