
#include "../headers/mdparams.h"
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
## FILE 					mdparams.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			25-11-2012
##
## SPECIFICATIONS
##
##	Handle parameters (parse the command line and sore values)
##	for the mdpocket programm.
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
        init_def_mdparams

   ## SPECIFICATION:
        Initialisation of default parameters.

   ## PARAMETRES: void

   ## RETURN:
        s_mdparams*: Pointer to allocated paramers.

 */
s_mdparams *init_def_mdparams(void) {
    s_mdparams *par = (s_mdparams*) my_malloc(sizeof (s_mdparams));

    par->f_pqr = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_freqdx = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_densdx = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_freqiso = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_densiso = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_desc = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_ppdb = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_apdb = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_appdb = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_traj = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_topo = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->traj_format = (char *) my_malloc(M_MAX_FORMAT_NAME_LENGTH * sizeof (char));
    par->topo_format = (char *) my_malloc(M_MAX_FORMAT_NAME_LENGTH * sizeof (char));
    par->f_elec = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    par->f_vdw = (char *) my_malloc(M_MAX_FILE_NAME_LENGTH * sizeof (char));
    strcpy(par->f_pqr, M_MDP_OUTPUT_FILE1_DEFAULT);
    strcpy(par->f_freqdx, M_MDP_OUTPUT_FILE2_DEFAULT);
    strcpy(par->f_freqiso, M_MDP_OUTPUT_FILE3_DEFAULT);
    strcpy(par->f_desc, M_MDP_OUTPUT_FILE4_DEFAULT);
    strcpy(par->f_ppdb, M_MDP_OUTPUT_FILE5_DEFAULT);
    strcpy(par->f_apdb, M_MDP_OUTPUT_FILE6_DEFAULT);
    strcpy(par->f_appdb, M_MDP_OUTPUT_FILE7_DEFAULT);
    strcpy(par->f_densdx, M_MDP_OUTPUT_FILE8_DEFAULT);
    strcpy(par->f_densiso, M_MDP_OUTPUT_FILE9_DEFAULT);
    strcpy(par->f_elec, M_MDP_OUTPUT_FILE10_DEFAULT);
    strcpy(par->f_vdw, M_MDP_OUTPUT_FILE11_DEFAULT);

    par->fsnapshot = NULL;
    par->flag_MD = 0;

    par->fwantedpocket[0] = 0;
    par->nfiles = 0;
    par->flag_scoring = 0;
    par->bfact_on_all = 0;
    par->grid_extent[0] = 0;
    par->grid_extent[1] = 0;
    par->grid_extent[2] = 0;
    par->grid_origin[0] = -999.0;
    par->grid_origin[1] = -999.0;
    par->grid_origin[2] = -999.0;
    par->grid_spacing = 0.0;

    return par;
}

int grid_user_data_missing(s_mdparams *par) {
    if (par->grid_origin[0] == -999.0 || par->grid_origin[1] == -999.0 || par->grid_origin[2] == -999.0) {
        return (1);
    }
    if (par->grid_extent[0] == 0 || par->grid_extent[1] == 0 || par->grid_extent[2] == 0) {
        return (1);
    }
    return (0);
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
        s_mdparams*: Pointer to parameters

 */
s_mdparams* get_mdpocket_args(int nargs, char **args) {
    int i,
            status = 0;
    int traj_file_defined = 0, traj_format_defined = 0, traj_topology_defined = 0, traj_topology_format_defined = 0;

    char *str_list_file = NULL;
    char **args_copy = my_malloc(sizeof (char**) *nargs);
    for (i = 0; i < nargs; i++) {
        args_copy[i] = my_malloc(sizeof (args[i]));
        strcpy(args_copy[i], args[i]);
    }


    s_mdparams *par = init_def_mdparams();
    //    for (i = 0; i < nargs; i++) printf(" %s ", args[i]);


    par->fpar = init_def_fparams();

    //    for (i = 0; i < nargs; i++) printf(" %s ", args_copy[i]);
    par->fpar = get_fpocket_args(nargs, args_copy);


    int c = 0;
    optind = 0;
    opterr = 0;
    //    optind = 1;
    //    optopt=0;
    static struct option long_options_mdpocket[] = {

        {"trajectory_file", required_argument, 0, M_MDPAR_TRAJECTORY},
        {"trajectory_format", required_argument, 0, M_MDPAR_TRAJECTORY_FORMAT},
        {"topology_file", required_argument, 0, M_MDPAR_TOPOLOGY_FILE},
        {"topology_format", required_argument, 0, M_MDPAR_TOPOLOGY_FORMAT},
        {"pdb_list", required_argument, 0, M_MDPAR_INPUT_FILE},
        {"selected_pocket", required_argument, 0, M_MDPAR_INPUT_FILE2},
        {"output_prefix", required_argument, 0, M_MDPAR_OUTPUT_FILE},
        {"druggability_score", required_argument, 0, M_MDPAR_SCORING_MODE},
        {"output_all_snapshots", required_argument, 0, M_MDPAR_OUTPUT_ALL_SNAPSHOTS},


        {0, 0, 0, 0}
    };

    while (c != -1) {
        //        int this_option_optind = optind ? optind : 1;
        /* getopt_long stores the option index here. */
        int option_index = 0;

        c = getopt_long(nargs, args, "t:O:P:T:L:w:o:Sa",
                long_options_mdpocket, &option_index);
//        printf("option index %d\n", option_index);
        switch (c) {
            case M_MDPAR_TRAJECTORY:
//                printf("option -t with value `%s'\n", optarg);
                status++;
                par->flag_MD = 1;
                strcpy(par->f_traj, optarg);
                traj_file_defined++;
                break;
            case M_MDPAR_TRAJECTORY_FORMAT:
//                printf("option -O with value `%s'\n", optarg);
                strcpy(par->traj_format, optarg);
                traj_format_defined++;
                status++;
                break;
            case M_MDPAR_TOPOLOGY_FILE:
//                printf("option -P with value `%s'\n", optarg);
                strcpy(par->f_topo, optarg);
                strcpy(par->fpar->topology_path, optarg);
                status++;
                traj_topology_defined++;
                break;
            case M_MDPAR_TOPOLOGY_FORMAT:
//                printf("option -T with value `%s'\n", optarg);
                strcpy(par->topo_format, optarg);
                traj_topology_format_defined++;
                status++;
                break;

            case M_PAR_TOPOLOGY:
                strcpy(par->fpar->topology_path, optarg);
                traj_topology_defined++;
                break;

            case M_MDPAR_INPUT_FILE:
                str_list_file = optarg;
				status++;
                break;

            case M_MDPAR_OUTPUT_FILE:
                sprintf(par->f_pqr, "%s.pqr", optarg);
                sprintf(par->f_freqdx, "%s_freq.dx", optarg);
                sprintf(par->f_densdx, "%s_dens.dx", optarg);
                sprintf(par->f_freqiso, "%s_freq_iso_0_5.pdb", optarg);
                sprintf(par->f_densiso, "%s_dens_iso_8.pdb", optarg);
                sprintf(par->f_desc, "%s_descriptors.txt", optarg);
                sprintf(par->f_ppdb, "%s_mdpocket.pdb", optarg);
                sprintf(par->f_apdb, "%s_mdpocket_atoms.pdb", optarg);
                sprintf(par->f_appdb, "%s_all_atom_pdensities.pdb", optarg);
                sprintf(par->f_elec, "%s_elec_grid.dx", optarg);
                sprintf(par->f_vdw, "%s_vdw_grid.dx", optarg);

                break;

            case M_MDPAR_INPUT_FILE2:
                strcpy(par->fwantedpocket, optarg);
                break;

            case M_MDPAR_SCORING_MODE:
                par->flag_scoring = 1;
                break;
        }
    }
    
    if (status == 0) {

        free_mdparams(par);
        par = NULL;
        print_mdpocket_usage(stdout);
    } else {
        if (str_list_file) {
            int res = add_list_snapshots(str_list_file, par);
            if (res <= 0) {
                fprintf(stdout, "! No data has been read.\n");
                free_mdparams(par);
                par = NULL;
                print_mdpocket_usage(stdout);
            }
        } else if ((!traj_file_defined || !traj_format_defined || !par->fpar->pdb_path)) {
            fprintf(stdout, "! No input file given... Try again :).%d %d %s\n",traj_file_defined,traj_format_defined,par->fpar->pdb_path);
            free_mdparams(par);
            par = NULL;
            print_mdpocket_usage(stdout);
        }
//        fprintf(stdout, "PDB PATH %s\n", par->fpar->pdb_path);
//        fflush(stdout);
    }




    return par;
}

/**
   ## FUNCTION:
        add_list_snapshots

   ## SPECIFICATION:
        Load a list of snapshot pdb file path. This file should have the
        following format:

        snapshot_pdb_file
        snapshot_pdb_file2
        snapshot_pdb_file3
        (...)

        Each snapshot file will be stored in the parameters structure.

   ## PARAMETRES:
        @ char *str_list_file : Path of the file containing all data
        @ s_mdparams *par      : Structures that stores all thoses files

   ## RETURN:
        int: Number of file read.

 */
int add_list_snapshots(char *str_list_file, s_mdparams *par) {
    FILE *f;
    int nread = 0,
            status;

    char buf[M_MAX_PDB_NAME_LEN * 2 + 6],
            snapbuf[M_MAX_PDB_NAME_LEN],
            infbuf[M_MAX_PDB_NAME_LEN * 2 + 6],
            origbuf1[20],
            origbuf2[20],
            origbuf3[20],
            resbuf[20],
            extbuf1[20],
            extbuf2[20],
            extbuf3[20];


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

            status = sscanf(buf, "%s", snapbuf);
            if (status < 1) {

                fprintf(stderr, "! Skipping row '%s' with bad format (status %d).\n",
                        buf, status);
            } else {
                if (strncmp(snapbuf, "#origin", 7) == 0) {
                    //status=sscanf(buf,"%s\t%d\t%d\t%d",infbuf,par->grid_origin[0],par->grid_origin[1],par->grid_origin[2]);
                    status = sscanf(buf, "%s\t%s\t%s\t%s", infbuf, origbuf1, origbuf2, origbuf3);

                    if (status >= 0) {
                        if (str_is_float(origbuf1, M_SIGN) && str_is_float(origbuf2, M_SIGN) && str_is_float(origbuf3, M_SIGN)) {
                            par->grid_origin[0] = atof(origbuf1);
                            par->grid_origin[1] = atof(origbuf2);
                            par->grid_origin[2] = atof(origbuf3);
                            fprintf(stdout, "Grid origin \t\t: %.3f %.3f %.3f\n", par->grid_origin[0], par->grid_origin[1], par->grid_origin[2]);
                        } else {
                            fprintf(stderr, "WARNING : failed to parse origin specified in the input, this calculaion will use an automatically detected origin\n");
                        }

                        //
                        fflush(stdout);
                    } else {
                        fprintf(stderr, "WARNING : failed to read the origin specified in the input file\n");
                    }
                } else if (strncmp(snapbuf, "#resolution", 11) == 0) {
                    //status=sscanf(buf,"%s\t%d\t%d\t%d",infbuf,par->grid_origin[0],par->grid_origin[1],par->grid_origin[2]);
                    status = sscanf(buf, "%s\t%s", infbuf, resbuf);

                    if (status >= 0) {
                        if (str_is_float(resbuf, M_NO_SIGN)) {

                            par->grid_spacing = atof(resbuf);
                            fprintf(stdout, "Grid resolution \t: %.3f\n", par->grid_spacing);
                        } else fprintf(stderr, "WARNING : failed to parse resolution specified in the input, this calculaion will use an automatically assigned resolution\n");

                        //
                        fflush(stdout);
                    } else fprintf(stderr, "WARNING : failed to read the resolution specified in the input file\n");
                } else if (strncmp(snapbuf, "#extent", 7) == 0) {
                    //status=sscanf(buf,"%s\t%d\t%d\t%d",infbuf,par->grid_origin[0],par->grid_origin[1],par->grid_origin[2]);
                    status = sscanf(buf, "%s\t%s\t%s\t%s", infbuf, extbuf1, extbuf2, extbuf3);

                    if (status >= 0) {
                        if (str_is_float(extbuf1, M_NO_SIGN) && str_is_float(extbuf2, M_NO_SIGN) && str_is_float(extbuf3, M_NO_SIGN)) {

                            par->grid_extent[0] = (int) atof(extbuf1), par->grid_extent[1] = (int) atof(extbuf2), par->grid_extent[2] = (int) atof(extbuf3);
                            fprintf(stdout, "Grid extent \t\t: %d %d %d\n", par->grid_extent[0], par->grid_extent[1], par->grid_extent[2]);
                        } else fprintf(stderr, "WARNING : failed to parse extent specified in the input, this calculaion will use an automatically assigned grid extent\n");

                        //
                        fflush(stdout);
                    } else fprintf(stderr, "WARNING : failed to read the extent specified in the input file\n");
                } else {
                    nread += add_snapshot(snapbuf, par);
                }
            }
        }
    } else {
        fprintf(stderr, "! File %s doesn't exists\n", str_list_file);
    }
    fclose(f);
    return nread;
}

/**
   ## FUNCTION:
        add_snapshot

   ## SPECIFICATION:
        Add a set of data to the list of set of data in the parameters. this function
        is used for the mdpocket program only.

        The function will try to open the file, and data will be stored only if the
        file exists, and if the name of the ligand is valid.

   ## PARAMETERS:
        @ char *snapbuf     : The snapshots path
        @ s_mdparams *par: The structure than contains parameters.

   ## RETURN:
        int: 1 if everything is OK, 0 if not.

 */
int add_snapshot(char *snapbuf, s_mdparams *par) {
    int nm1;

    FILE *f = fopen_pdb_check_case(snapbuf, "r");
    if (f) {
        nm1 = par->nfiles;
        par->nfiles += 1;


        par->fsnapshot = (char**) my_realloc(par->fsnapshot, (par->nfiles) * sizeof (char*));

        par->fsnapshot[nm1] = (char *) my_malloc((strlen(snapbuf) + 1) * sizeof (char));

        strcpy(par->fsnapshot[nm1], snapbuf);

        fclose(f);

    } else {
        fprintf(stdout, "! The pdb file '%s' doesn't exists.\n", snapbuf);
        return 0;
    }

    return 1;
}

/**
   ## FUNCTION:
        print_mdparams

   ## SPECIFICATION:
        Print function, usefull to debug

   ## PARAMETRES:
        @ s_mdparams *p : The structure than will contain the parsed parameter
        @ FILE *f      : The file to write in

   ## RETURN:
    void

 */
void print_mdparams(s_mdparams *p, FILE *f) {

    if (p) {
        fprintf(f, "==============\nParameters of the program: \n");
        int i;
        for (i = 0; i < p->nfiles; i++) {
            fprintf(f, "> Snaphot %d: '%s'\n", i + 1, p->fsnapshot[i]);
        }
        fprintf(f, "==============\n");
        if (p->fwantedpocket[0] != 0) {
            fprintf(f, "Wanted pocket given in file : %s\n", p->fwantedpocket);
            fprintf(f, "==============\n");
        }
        if (p->f_traj && p->traj_format) {
            printf("Trajectory file : %s\nTrajectory format : %s\n", p->f_traj, p->traj_format);
            //printf("Topology file? : %s\n", p->f_topo);
        }
    } else fprintf(f, "> No parameters detected\n");
}

/**
   ## FUNCTION:
        print_mdparams_usage

   ## SPECIFICATION:
        Displaying usage of the programm in the given buffer

   ## PARAMETRES:
        @ FILE *f: buffer to print in

   ## RETURN:

 */
void print_mdpocket_usage(FILE *f) {
    f = (f == NULL) ? stdout : f;

    //	fprintf(f, M_MDP_USAGE) ;

    fprintf(f, "\n\
:||: \033[1mmdpocket (fpocket 3.0)\033[0m :||:\n\
        \n");
    fprintf(f, "\033[1m1: Pocket Exploration: Mandatory parameters\033[0m : \n\
\t mdpocket --%s trajectory file \n\
\t          --%s trajectory format\n\
\t          -%c topology PDB file\n\
\t[mdpocket --%s pdb_list_file ]                                  \n", M_MDPAR_LONG_TRAJECTORY, M_MDPAR_LONG_TRAJECTORY_FORMAT, M_PAR_PDB_FILE, M_MDPAR_LONG_INPUT_FILE);

    fprintf(f, "\n\033[1m2: Pocket Characterization: Mandatory parameters\033[0m : \n\
\t mdpocket --%s md_trajectory_file \n\
\t          --%s md_trajectory_format\n\
\t          --%s selectedPocket.pdb\n\
\t          -%c topology PDB file\n\
\t[mdpocket --%s pdb_list_file --%s selectedPocket.pdb]                                  \n", M_MDPAR_LONG_TRAJECTORY, M_MDPAR_LONG_TRAJECTORY_FORMAT, M_MDPAR_LONG_INPUT_FILE2,  M_PAR_PDB_FILE,M_MDPAR_LONG_INPUT_FILE, M_MDPAR_LONG_INPUT_FILE2);
    fprintf(f, "\n\t\033[1m2.1: Optional energy calculation during pocket characterization:\033[0m : \n\
\t\t          --%s topology_file\n\
\t\t          --%s topology_format (currently only prmtop is supported)\n\
\t\t          -%c set this flag to perform interaction energy grid calculations\n", M_MDPAR_LONG_TOPOLOGY_FILE, M_MDPAR_LONG_TOPOLOGY_FORMAT, M_PAR_GRID_CALCULATION);

    fprintf(f, "\n\n\033[1mSupported trajectory formats\033[0m\n");
    fprintf(f, "\tTrajectory format :\n\
\t\tAmber MDCRD without box information (crd)      \n\
\t\tAmber MDCRD with box information    (crdbox)      \n\
\t\tNetCDF                              (netcdf)         \n\
\t\tDCD                                 (dcd)        \n\
\t\tDESRES DTR                          (dtr)        \n\
\t\tGromacs TRR                         (trr)        \n\
\t\tGromacs XTC                         (xtc)  \n");
    fprintf(f, "\n\n\033[1mOptional output parameters\033[0m\n");
    fprintf(f, "\t-%c --%s output_prefix\t: specify the prefix of all output files here\n", M_MDPAR_OUTPUT_FILE, M_MDPAR_LONG_OUTPUT_FILE);
    fprintf(f, "\t-%c --%s\t: put this flag to score pockets by druggability\n", M_MDPAR_SCORING_MODE, M_MDPAR_LONG_SCORING_MODE);

    fprintf(f, "\n\033[1mFor more information: http://fpocket.sourceforge.net\033[0m\n");

}

/**
   ## FUNCTION:
        free_params

   ## SPECIFICATION:
        Free parameters

   ## PARAMETRES:
        @ s_mdparams *p: Pointer to the structure to free

   ## RETURN:
        void

 */
void free_mdparams(s_mdparams *p) {
    if (p) {

        if (p->fsnapshot) {
            my_free(p->fsnapshot);
            p->fsnapshot = NULL;
        }
        if (p->f_pqr) {
            my_free(p->f_pqr);
            p->f_pqr = NULL;
        }
        if (p->f_densdx) {
            my_free(p->f_densdx);
            p->f_densdx = NULL;
        }
        if (p->f_freqdx) {
            my_free(p->f_freqdx);
            p->f_freqdx = NULL;
        }
        if (p->f_desc) {
            my_free(p->f_desc);
            p->f_desc = NULL;
        }
        if (p->traj_format) {
            my_free(p->traj_format);
            p->traj_format = NULL;
        }
        if (p->f_traj) {
            my_free(p->f_traj);
            p->f_traj = NULL;
        }
        free_fparams(p->fpar);
        my_free(p);
    }
}
