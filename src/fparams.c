
#include "../headers/fparams.h"
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
## FILE 					fparams.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-02-14
##
## SPECIFICATIONS
##
##	Handle parameters (parse the command line and sore values)
##	for the fpocket programm.
##
## MODIFICATIONS HISTORY
##   26-03-17           (p)  introducing explicit pocket detection
##   04-04-16           (p)  Introduced NMR model numbers
##   28-08-14           (p)  Introduced novel argument handling + exposure
##   28-10-12           (p)  Exposing novel arguments to the user for new clustering
##	17-03-09	(v)  Segfault avoided when freeing pdb list
##	15-12-08	(v)  Added function to check if a single letter is a fpocket
##					 command line option (usefull for t/dpocket) + minor modifs
##	28-11-08	(v)  List of pdb taken into account as a single file input.
##					 Comments UTD
##	27-11-08	(v)  PDB file check moved in fpmain + minor modif + relooking
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
        init_def_fparams

   ## SPECIFICATION:
        Initialisation of default parameters

   ## PARAMETRES: void

   ## RETURN:
        s_fparams*: Pointer to allocated paramers.

 */

char write_mode[10] = "d"; /*write mode : d -> default | b -> both pdb and mmcif |
                        p ->pdb | m  -> mmcif*/

s_fparams *init_def_fparams(void)
{
    s_fparams *par = (s_fparams *)my_malloc(sizeof(s_fparams));

    par->min_apol_neigh = M_MIN_APOL_NEIGH_DEFAULT;
    par->asph_min_size = M_MIN_ASHAPE_SIZE_DEFAULT;
    par->asph_max_size = M_MAX_ASHAPE_SIZE_DEFAULT;
    par->pdb_path[0] = 0;
    par->basic_volume_div = M_BASIC_VOL_DIVISION;
    par->nb_mcv_iter = M_MC_ITER;
    par->min_pock_nb_asph = M_MIN_POCK_NB_ASPH;
    par->refine_min_apolar_asphere_prop = M_REFINE_MIN_PROP_APOL_AS;
    par->clust_max_dist = M_CLUST_MAX_DIST;
    par->distance_measure = M_DISTANCE_MEASURE;
    par->clustering_method = M_CLUSTERING_METHOD;
    par->flag_do_grid_calculations = 0;
    par->npdb = 0;
    par->model_number = 0; /**by default consider we do not have an NMR structure*/
    par->pdb_lst = NULL;
    par->flag_do_asa_and_volume_calculations = 1;
    par->db_run = M_DB_RUN;
    par->min_as_density = M_MIN_AS_DENSITY;
    par->topology_path[0] = 0;
    par->fpocket_running = 0;
    par->xlig_resnumber = -1;
    par->chain_is_kept = 0;
    par->write_par[0] = 'd';
    par->xpocket_n = 0;
    par->min_n_explicit_pocket_atoms = M_MIN_N_EXPLICIT_POCKET;
    return par;
}

/**
   ## FUNCTION:
        get_fpocket_args

   ## SPECIFICATION:
        This function analyse the user's command line and parse it to store parameters
        for the pocket finder programm.

   ## PARAMETRES:
        @ int nargs   :  Number of arguments
        @ char **args : Arguments of main program

   ## RETURN:
        s_params*: Pointer to parameters

 */
s_fparams *get_fpocket_args(int nargs, char **args)
{
    int status = 0;
    s_fparams *par = init_def_fparams(); /*default param initialy*/
    int c = 0;
    int apti = 0;
    int pti = 0;
    short j = 0;
    short xflag;
    opterr = 0;
    char *pt;
    char *apt;
    char *residue_string[M_MAX_CUSTOM_POCKET_LEN];
    short custom_ligand_i = 0;

    static struct option fplong_options[] = {/*long options args located in fparams.h*/
                                             {"file", required_argument, 0, M_PAR_PDB_FILE},
                                             {"min_alpha_size", required_argument, 0, M_PAR_MIN_ASHAPE_SIZE},
                                             {"max_alpha_size", required_argument, 0, M_PAR_MAX_ASHAPE_SIZE},
                                             {"min_spheres_per_pocket", required_argument, 0, M_PAR_MIN_POCK_NB_ASPH},
                                             {"min_ratio_apolar_spheres_per_pocket", required_argument, 0, M_PAR_REFINE_MIN_NAPOL_AS},
                                             {"clustering_distance", required_argument, 0, M_PAR_CLUST_MAX_DIST},
                                             {"clustering_method", required_argument, 0, M_PAR_CLUSTERING_METHOD},
                                             {"clustering_distance_measure", required_argument, 0, M_PAR_DISTANCE_MEASURE},
                                             {"pocket_descr_stdout", no_argument, 0, M_PAR_DB_RUN},
                                             {"calculate_interaction_grids", no_argument, 0, M_PAR_GRID_CALCULATION},
                                             {"number_apol_asph_pocket", required_argument, 0, M_PAR_MIN_APOL_NEIGH},
                                             {"iterations_volume_mc", required_argument, 0, M_PAR_MC_ITER},
                                             {"topology_file", required_argument, 0, M_PAR_TOPOLOGY},
                                             {"model_number", required_argument, 0, M_PAR_MODEL_FLAG},
                                             {"custom_ligand", required_argument, 0, M_PAR_CUSTOM_LIGAND},
                                             {"custom_pocket", required_argument, 0, M_PAR_CUSTOM_POCKET},
                                             {M_PAR_MIN_N_EXPLICIT_POCKET_LONG, required_argument, 0, M_PAR_MIN_N_EXPLICIT_POCKET},
                                             {M_PAR_DROP_CHAINS_LONG, required_argument, 0, M_PAR_DROP_CHAINS},         /*drop chains*/
                                             {M_PAR_CHAIN_AS_LIGAND_LONG, required_argument, 0, M_PAR_CHAIN_AS_LIGAND}, /*chain as ligand*/
                                             {M_PAR_KEEP_CHAINS_LONG, required_argument, 0, M_PAR_KEEP_CHAINS},         /*chain as ligand*/
                                             {M_PAR_WRITE_MODE_LONG, required_argument, 0, M_PAR_WRITE_MODE},
                                             {0, 0, 0, 0}};

    while (c != -1)
    {

        /* getopt_long stores the option index here. */
        int option_index = 0;
        optarg = 0;
        c = getopt_long(nargs, args, "f:m:M:i:p:D:C:e:dxp:v:y:l:r:P:u:c:a:k:w:",
                        fplong_options, &option_index);
        //        printf("C: %d nargs : %d optindex:%d\n", c, nargs, option_index);

        switch (c)
        {
        case 0:
            break;

        case M_PAR_WRITE_MODE: /*write mode : d -> default | b -> both pdb and mmcif | p ->pdb | m  -> mmcif*/
            status++;
            if (optarg[0] != 'd' && optarg[0] != 'b' && optarg[0] != 'p' && optarg[0] != 'm' && strcmp(optarg, "both") && strcmp(optarg, "pdb") && strcmp(optarg, "cif") && strcmp(optarg, "mmcif"))
            { /*if args is not a correct arg break*/
                printf("Writing mode invalid, set to default\n");
                break;
            }
            if (!strcmp(optarg, "cif"))
            {
                strcpy(par->write_par, "mmcif");
                strcpy(write_mode, par->write_par);
            }
            else
            {
                strcpy(par->write_par, optarg);
                strcpy(write_mode, par->write_par);
            }

            break;

        case M_PAR_CHAIN_AS_LIGAND: /*option with -a "name of the chain" to be specified as a ligand*/
            /*select the chains as ligand*/
            status++;
            strcpy(par->chain_as_ligand, optarg); /*par->chain_as_ligand contains the arg given in cmd line*/
            const char *separatorss = ",";        /* defining separators*/
            pt = strtok(par->chain_as_ligand, separatorss);
            int nn = 0;
            while (pt != NULL)
            {
                strncpy(&(par->chain_as_ligand[nn]), pt, 1);
                nn++;
                pt = strtok(NULL, separatorss);
            }
            par->xlig_resnumber = 0;
            // printf("lig %s\n",par->chain_as_ligand);
            break;

        case M_PAR_DROP_CHAINS:                /*option with -c "name of the chains"*/
                                               /*drop the selected chains from the pdb file*/
            strcpy(par->chain_delete, optarg); /*par->custom_ligand contains the arg given in cmd line*/
            // printf("%s and %s",par->custom_ligand,optarg);
            const char *separators = ",:"; /* defining separators for drop chains args*/
            pt = strtok(par->chain_delete, separators);
            int n = 0;
            while (pt != NULL)
            {
                strncpy(&(par->chain_delete[n]), pt, 1);

                n++;
                pt = strtok(NULL, separators);
            }
            par->chain_is_kept = 0;

            // printf("%s\n",par->chain_delete);
            status++;
            break;

        case M_PAR_KEEP_CHAINS: /*option with -k "name of the chains"*/
                                /*drop the selected chains from the pdb file*/

            strcpy(par->chain_delete, optarg); /*par->custom_ligand contains the arg given in cmd line*/
            // printf("%s and %s",par->custom_ligand,optarg);
            const char *separator = ",:"; /* defining separators for drop chains args*/
            pt = strtok(par->chain_delete, separator);
            int nk = 0;
            while (pt != NULL)
            {
                strncpy(&(par->chain_delete[nk]), pt, 1);
                nk++;
                pt = strtok(NULL, separator);
            }
            // printf("%s\n",par->chain_delete);
            par->chain_is_kept = 1;
            status++;
            break;

        case M_PAR_CUSTOM_LIGAND:

            // parse ligand specification that has to be given as
            // residuenumber:residuename:chain_code
            // for 1uyd for instance 1224:PU8:A

            status++;

            strcpy(par->custom_ligand, optarg);
            // printf("%s and %s",par->custom_ligand,optarg);
            pt = strtok(par->custom_ligand, ":");

            while (pt != NULL)
            {
                custom_ligand_i++;
                if (custom_ligand_i == 1)
                    par->xlig_resnumber = atoi(pt);
                else if (custom_ligand_i == 2)
                    strncpy(&(par->xlig_resname), pt, 3);
                else if (custom_ligand_i == 3)
                    strncpy(&(par->xlig_chain_code), pt, 1);
                /*int a = atoi(pt);
                    printf("%d\n", a);*/
                pt = strtok(NULL, ":");
            }

            break;

        case M_PAR_CUSTOM_POCKET:

            // parse pocket specification that has to be given as
            // residuenumber1:insertion_code1:chain_code1.residuenumber2:insertion_code2:chain_code2& ....
            // for 1uyd for instance 127::A.128::A

            status++;

            strcpy(par->custom_pocket_arg, optarg);
            char *rest = par->custom_pocket_arg;
            char *rest2;
            /*count residues first*/
            while ((pt = strtok_r(rest, ".", &rest)))
                par->xpocket_n++;

            par->xpocket_chain_code = (char *)my_malloc(par->xpocket_n * sizeof(char));
            par->xpocket_insertion_code = (char *)my_malloc(par->xpocket_n * sizeof(char));
            par->xpocket_residue_number = (unsigned short *)my_malloc(par->xpocket_n * sizeof(unsigned short));
            pti = 0;
            strcpy(par->custom_pocket_arg, optarg);
            rest = par->custom_pocket_arg;
            while ((pt = strtok_r(rest, ".", &rest)))
            {
                strcpy(&residue_string, pt);
                rest2 = residue_string;
                apti = 0;
                while (apt = strtok_r(rest2, ":", &rest2))
                {
                    switch (apti)
                    {
                    case 0:
                        par->xpocket_residue_number[pti] = (unsigned short)atoi(apt); // fprintf(stdout,"residuenumber: %d\n", atoi(apt));
                    case 1:
                        strncpy(&(par->xpocket_insertion_code[pti]), apt, 1);
                    case 2:
                        strncpy(&(par->xpocket_chain_code[pti]), apt, 1);
                    }
                    apti++;
                }
                pti++;
            }
            break;

        case M_PAR_MIN_N_EXPLICIT_POCKET:
            status++;
            par->min_n_explicit_pocket_atoms = (int)atoi(optarg);
            break;

        case M_PAR_PDB_FILE:
            //                printf("option -f with value `%s'\n", optarg);
            status++;
            strcpy(par->pdb_path, optarg);

            break;
        case M_PAR_MIN_ASHAPE_SIZE:
            //                printf("option -m with value `%s'\n", optarg);
            par->asph_min_size = (float)atof(optarg);
            status++;
            break;
        case M_PAR_MAX_ASHAPE_SIZE:
            //                printf("option -M with value `%s'\n", optarg);
            par->asph_max_size = (float)atof(optarg);
            status++;
            break;
        case M_PAR_MIN_POCK_NB_ASPH:
            //                printf("option -i with value `%s'\n", optarg);
            par->min_pock_nb_asph = (int)atoi(optarg);
            status++;
            break;
        case M_PAR_REFINE_MIN_NAPOL_AS:
            //                printf("option -p with value `%s'\n", optarg);
            par->refine_min_apolar_asphere_prop = (float)atof(optarg);
            status++;
            break;
        case M_PAR_CLUST_MAX_DIST:
            //                printf("option -D with value `%s'\n", optarg);
            par->clust_max_dist = (float)atof(optarg);
            status++;
            break;
        case M_PAR_DISTANCE_MEASURE:
            //                printf("option -e with value %s\n", optarg);
            // strcpy(par->distance_measure,optarg);      /*might be problematic*/
            strncpy(&(par->distance_measure), optarg, 1);
            status++;

            /*memcpy ( &(par->distance_measure), &optarg, sizeof(optarg) );*/
            break;
        case M_PAR_CLUSTERING_METHOD:
            //                printf("option -C with value %s\n", optarg);
            status++;
            strncpy(&(par->clustering_method), optarg, 1);
            /*memcpy ( (void *)par->clustering_method,optarg,sizeof(optarg));*/
            break;
        case M_PAR_TOPOLOGY:
            strcpy(par->topology_path, optarg);
            break;
        case M_PAR_DB_RUN:
            par->db_run = 1;
            break;
        case M_PAR_GRID_CALCULATION:
            //                printf("option -x with value `%s'\n", optarg);
            par->flag_do_grid_calculations = 1;
            status++;
            break;
        case M_PAR_MIN_APOL_NEIGH:
            //                printf("option -A with value %s", optarg);
            par->min_apol_neigh = (float)atof(optarg);
            status++;
            break;
        case M_PAR_MC_ITER:
            //                printf("option -v with value %s", optarg);
            par->nb_mcv_iter = (int)atoi(optarg);
            status++;
            break;
        case M_PAR_MODEL_FLAG:
            // printf("option -l with value %s", optarg);
            par->model_number = (int)atoi(optarg);
            status++;
            break;
        case 'L':
            status++;
            break;
        }
    }
    if (strstr(par->pdb_path, ".cif") && par->write_par[0] == 'd')
    {
        strcpy(par->write_par, "m");
        strcpy(write_mode, par->write_par);
        // printf("%c", write_mode[0]);
    }
    else if (strstr(par->pdb_path, ".pdb") && par->write_par[0] == 'd')
    {
        strcpy(par->write_par, "p");
        strcpy(write_mode, par->write_par);
    }

    if (par->xpocket_n > 0 && par->xlig_resnumber > -1)
    {
        fprintf(stderr, "\n\033[1mERROR:\033[0m you specified an explicit ligand (-r) AND an explicit pocke (-P) in the same fpocket run. This is currently not allowed, please use either the one or the other.\n\n");
        return NULL;
    }
    return (par);
    /*        if(status){
                return(par);
            }
            else {


                return(NULL);
            }*/
}

/**
   ## FUNCTION:
        get_fpocket_args

   ## SPECIFICATION:
        This function analyse the user's command line and parse it to store parameters
        for the pocket finder programm.

   ## PARAMETRES:
        @ int nargs   :  Number of arguments
        @ char **args : Arguments of main program

   ## RETURN:
        s_params*: Pointer to parameters

 */
s_fparams *DEPR_get_fpocket_args(int nargs, char **args)
{
    int i,
        npdb = 0,
        status = 0;

    s_fparams *par = init_def_fparams();
    char *pdb_lst = NULL;

    // read arguments by flags
    for (i = 1; i < nargs; i++)
    {
        if (strlen(args[i]) == 2 && args[i][0] == '-' && i <= (nargs - 1))
        {

            switch (args[i][1])
            {
            case M_PAR_MAX_ASHAPE_SIZE:
                status += parse_asph_max_size(args[++i], par);
                break;
            case M_PAR_MIN_ASHAPE_SIZE:
                status += parse_asph_min_size(args[++i], par);
                break;
            case M_PAR_MIN_APOL_NEIGH:
                status += parse_min_apol_neigh(args[++i], par);
                break;
            case M_PAR_CLUST_MAX_DIST:
                status += parse_clust_max_dist(args[++i], par);
                break;
            case M_PAR_CLUSTERING_METHOD:
                status += parse_clustering_method(args[++i], par);
                break;
            case M_PAR_DISTANCE_MEASURE:
                status += parse_distance_measure(args[++i], par);
                break;
            case M_PAR_MC_ITER:
                status += parse_mc_niter(args[++i], par);
                break;
            case M_PAR_BASIC_VOL_DIVISION:
                status += parse_basic_vol_div(args[++i], par);
                break;
            case M_PAR_MIN_POCK_NB_ASPH:
                status += parse_min_pock_nb_asph(args[++i], par);
                break;
            case M_PAR_REFINE_MIN_NAPOL_AS:
                status += parse_refine_minaap(args[++i], par);
                break;
            case M_PAR_DB_RUN:
                par->db_run = 1;
                break;
            case M_PAR_GRID_CALCULATION:
                par->flag_do_grid_calculations = 1;
                break;

            case M_PAR_PDB_LIST:
                pdb_lst = args[++i];
                break;

            case M_PAR_PDB_FILE:
                if (npdb >= 1)
                    fprintf(stderr,
                            "! Only first input pdb will be used.\n");
                else
                {
                    strcpy(par->pdb_path, args[++i]);
                    npdb++;
                }
                break;
            default:
                break;
            }
        }
    }

    if (status > 0)
    {
        free_fparams(par);
        print_pocket_usage(stdout);
        return NULL;
    }

    par->npdb = npdb;

    /* Handle a file containing a list of PDB */
    if (pdb_lst != NULL)
    {
        FILE *f = fopen(pdb_lst, "r");
        if (f != NULL)
        {
            /* Count the number of lines */
            int n = 0;
            char cline[M_MAX_PDB_NAME_LEN + 1];

            while (fgets(cline, M_MAX_PDB_NAME_LEN, f) != NULL)
            {
                if (strcmp("\n", cline) != 0)
                {
                    n++;
                }
            }
            fclose(f);
            if (n == 0)
            {
                return par;
            }

            /* Allocate memory and store each line */
            par->pdb_lst = (char **)my_malloc(n * sizeof(char *));

            f = fopen(pdb_lst, "r");
            int i = 0, l = 0;
            char *line;
            while (fgets(cline, M_MAX_PDB_NAME_LEN, f) != NULL)
            {
                if (strcmp("\n", cline) != 0)
                {
                    l = strlen(cline);
                    if (cline[l - 1] == '\n')
                    {
                        l--;
                        cline[l] = '\0';
                    }
                    line = (char *)my_malloc((l + 1) * sizeof(char));
                    memcpy(line, cline, l + 1);

                    par->pdb_lst[i] = line;
                    i++;
                }
            }

            par->npdb = n;
        }
    }

    return par;
}

/**
   ## FUNCTION:
        parse_clust_max_dist

   ## SPECIFICATION:
        Parsing function for the distance criteria first clustering algorithm.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid float), 1 if not

 */
int parse_clust_max_dist(char *str, s_fparams *p)
{
    if (str_is_float(str, M_NO_SIGN))
    {
        p->clust_max_dist = atof(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the single linkage max dist.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_sclust_max_dist

   ## SPECIFICATION:
        Parsing function for the distance criteria in the single linkage clustering.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid float), 1 if not

 */
int parse_clustering_method(char *str, s_fparams *p)
{
    if (str)
    {
        p->clustering_method = *str;
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for clustering method.\n", str);
        return 1;
    }

    return 0;
}

int parse_distance_measure(char *str, s_fparams *p)
{
    if (str)
    {
        p->distance_measure = *str;
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for distance measure.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_min_apol_neigh

   ## SPECIFICATION:
        Parsing function for the minimum number of apolar contacted atom for an alpha
        sphere to be considered as apolar.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid int), 1 if not

 */
int parse_min_apol_neigh(char *str, s_fparams *p)
{
    if (str_is_number(str, M_NO_SIGN))
    {
        p->min_apol_neigh = (int)atoi(str);
        if (p->min_apol_neigh < 0)
            p->min_apol_neigh = 0;
        if (p->min_apol_neigh > 4)
            p->min_apol_neigh = 4;
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the min radius of alpha shperes.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_asph_min_size

   ## SPECIFICATION:
        Parsing function for the minimum radius of each alpha shpere

   ## PARAMETERS:
        @ char *str: The string to parse
        @ s_fparams *p: The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid float), 1 if not

 */
int parse_asph_min_size(char *str, s_fparams *p)
{
    if (str_is_float(str, M_NO_SIGN))
    {
        p->asph_min_size = (float)atof(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the min radius of alpha shperes.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_asph_max_size

   ## SPECIFICATION:
        Parsing function for the maximum radius of each alpha shpere

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid float), 1 if not

 */
int parse_asph_max_size(char *str, s_fparams *p)
{
    if (str_is_float(str, M_NO_SIGN))
    {
        p->asph_max_size = (float)atof(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the max radius of alpha shperes.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_mc_niter

   ## SPECIFICATION:
        Parsing function for the number of iteration for the Monte Carlo volume
        calculation.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid float), 1 if not

 */
int parse_mc_niter(char *str, s_fparams *p)
{
    if (str_is_float(str, M_NO_SIGN))
    {
        p->nb_mcv_iter = (int)atoi(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the number of monte-carlo iteration for the volume.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_basic_vol_div

   ## SPECIFICATION:
        Parsing function for the number of iteration for the basic volume calculation.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid integer), 1 if not

 */
int parse_basic_vol_div(char *str, s_fparams *p)
{
    if (str_is_number(str, M_NO_SIGN))
    {
        p->basic_volume_div = (int)atoi(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the precision of the basic volume calculation.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_refine_min_apol

   ## SPECIFICATION:
        Parsing function for the minimum number of apolar sphere per pocket.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid integer), 1 if not

 */
int parse_refine_minaap(char *str, s_fparams *p)
{
    if (str_is_float(str, M_NO_SIGN))
    {
        p->refine_min_apolar_asphere_prop = (float)atof(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the refine distance.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        parse_min_pock_nb_asph

   ## SPECIFICATION:
        Parsing function for the minimum number of alpha sphere per pocket.

   ## PARAMETERS:
        @ char *str    : The string to parse
        @ s_fparams *p : The structure than will contain the parsed parameter

   ## RETURN:
        int: 0 if the parameter is valid (here a valid integer), 1 if not

 */
int parse_min_pock_nb_asph(char *str, s_fparams *p)
{
    if (str_is_number(str, M_NO_SIGN))
    {
        p->min_pock_nb_asph = (int)atoi(str);
    }
    else
    {
        fprintf(stdout, "! Invalid value (%s) given for the refine distance.\n", str);
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        is_fpocket_opt

   ## SPECIFICATION:
        Say either or not a single letter code is a fpocket option (excluding
        input file/list option.)

   ## PARAMETRES:
        @ const char opt: The one letter code option.

   ## RETURN:
        integer: 1 if it's a valid option parmeter, 0 if not.

 */

int is_fpocket_opt(const char opt)
{
    if (opt == M_PAR_MAX_ASHAPE_SIZE ||
        opt == M_PAR_MIN_ASHAPE_SIZE ||
        opt == M_PAR_MIN_APOL_NEIGH ||
        opt == M_PAR_CLUST_MAX_DIST ||
        opt == M_PAR_CLUSTERING_METHOD ||
        opt == M_PAR_MC_ITER ||
        opt == M_PAR_BASIC_VOL_DIVISION ||
        opt == M_PAR_MIN_POCK_NB_ASPH ||
        opt == M_PAR_REFINE_MIN_NAPOL_AS ||
        opt == M_PAR_PDB_FILE)
    {
        return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
        free_fparams

   ## SPECIFICATION:
        Free parameters

   ## PARAMETRES:
        @ s_params *p: Pointer to the structure to free

   ## RETURN:
        void

 */
void free_fparams(s_fparams *p)
{
    int i;
    if (p)
    {
        if (p->npdb > 0 && p->pdb_lst != NULL)
        {
            for (i = 0; i < p->npdb; i++)
            {
                if (p->pdb_lst[i] != NULL)
                    my_free(p->pdb_lst[i]);
            }
            my_free(p->pdb_lst);
        }
        my_free(p);
    }
}

/**
   ## FUNCTION:
        print_pocket_usage

   ## SPECIFICATION:
        Displaying usage of the programm in the given buffer

   ## PARAMETRES:
        @ FILE *f: buffer to print in

   ## RETURN:
    void

 */
void print_pocket_usage(FILE *f)
{
    f = (f == NULL) ? stdout : f;

    /*fprintf(f, M_FP_USAGE) ;*/

    fprintf(f, "\n\
:||: \033[1mfpocket 4.0\033[0m :||:\n\
        \n");
    fprintf(f, "\033[1mMandatory parameters\033[0m : \n\
\tfpocket -%c --%s pdb or cif file                                      \n\
\t[ fpocket -%c --%s fileList ]                                  \n",
            M_PAR_PDB_FILE, M_PAR_LONG_PDB_FILE, M_PAR_PDB_LIST, M_PAR_LONG_PDB_LIST);

    fprintf(f, "\n\n\033[1mOptional output parameters\033[0m\n");
    fprintf(f, "\t-%c --%s\t: Specify this flag if you want fpocket to     \n\
\t\t\t\t\t\t  calculate VdW and Coulomb grids for each pocket\n",
            M_PAR_GRID_CALCULATION, M_PAR_LONG_GRID_CALCULATION);
    fprintf(f, "\t-%c --%s\t\t: Put this flag if you want to write fpocket\n\
\t\t\t\t\t\t  descriptors to the standard output\n",
            M_PAR_DB_RUN, M_PAR_LONG_DB_RUN);

    fprintf(f, "\n\n\033[1mOptional input parameters\033[0m\n");
    fprintf(f, "\t-%c --%s (int)\t\t\t: Number of Model to analyze.\t\n", M_PAR_MODEL_FLAG, M_PAR_MODEL_FLAG_LONG);
    fprintf(f, "\t-%c --%s (string)\t\t: File name of a topology file (Amber prmtop).\t\n", M_PAR_TOPOLOGY, M_PAR_LONG_TOPOLOGY);
    fprintf(f, "\t-%c --%s (string)\t\t: String specifying a ligand like: \n\
\t\t\t\t\t\t  residuenumber:residuename:chain_code (ie. 1224:PU8:A).\t\n",
            M_PAR_CUSTOM_LIGAND, M_PAR_CUSTOM_LIGAND_LONG);
    fprintf(f, "\t-%c --%s (string)\t\t: String specifying a pocket like: \n\ 
\t\t\t\t\t\t  residuenumber1:insertion_code1('-' if empty):chain_code1.residuenumber2:insertion_code2:chain_code2 (ie. 138:-:A.139:-:A).\t\n",
            M_PAR_CUSTOM_POCKET, M_PAR_CUSTOM_POCKET_LONG);
    fprintf(f, "\t-%c --%s (int)\t: If explicit pocket provided, minimum number \n\ 
\t\t\t\t\t\t  of atoms of an alpha sphere that have to be in the selected pocket.\t\n",
            M_PAR_MIN_N_EXPLICIT_POCKET, M_PAR_MIN_N_EXPLICIT_POCKET_LONG);
    fprintf(f, "\t-%c --%s (char)\t\t: Character specifying a chain as a ligand\t\n", M_PAR_CHAIN_AS_LIGAND, M_PAR_CHAIN_AS_LIGAND_LONG);

    fprintf(f, "\n\n\033[1mOptional pocket detection parameters\033[0m (default parameters)           \n\
\t-%c --%s (float)\t\t: Minimum radius of an alpha-sphere.\t(%.1f)\n",
            M_PAR_MIN_ASHAPE_SIZE, M_PAR_LONG_MIN_ASHAPE_SIZE, M_MAX_ASHAPE_SIZE_DEFAULT);
    fprintf(f, "\t-%c --%s (float)\t\t: Maximum radius of an alpha-sphere.\t(%.1f)\n", M_PAR_MAX_ASHAPE_SIZE, M_PAR_LONG_MAX_ASHAPE_SIZE, M_MIN_ASHAPE_SIZE_DEFAULT);
    fprintf(f, "\t-%c --%s (float)\t: Distance threshold for clustering algorithm\t(%.1f)\n", M_PAR_CLUST_MAX_DIST, M_PAR_LONG_CLUST_MAX_DIST, M_CLUST_MAX_DIST);
    fprintf(f, "\t-%c --%s (char)\t\t: Specify the clustering method wanted for     \n\
\t\t\t\t\t\t  grouping voronoi vertices together (%c)\n\
\t\t\t\t\t\t  s : single linkage clustering\n\
\t\t\t\t\t\t  m : complete linkage clustering\n\
\t\t\t\t\t\t  a : average linkage clustering \n\
\t\t\t\t\t\t  c : centroid linkage clustering\n",
            M_PAR_CLUSTERING_METHOD, M_PAR_LONG_CLUSTERING_METHOD, M_CLUSTERING_METHOD);
    fprintf(f, "\t-%c --%s (char)\t\t: Specify the distance measure for clustering\t(%c) \n\
\t\t\t\t\t\t  e : euclidean distance\n\
\t\t\t\t\t\t  b : Manhattan distance\n",
            M_PAR_DISTANCE_MEASURE, M_PAR_LONG_DISTANCE_MEASURE, M_DISTANCE_MEASURE);
    fprintf(f, "\t-%c --%s (int)\t: Minimum number of a-sphere per pocket.\t(%d)\n", M_PAR_MIN_POCK_NB_ASPH, M_PAR_LONG_MIN_POCK_NB_ASPH, M_MIN_POCK_NB_ASPH);
    fprintf(f, "\t-%c --%s (float)\t: Minimum proportion of apolar sphere in       \n\
\t\t\t\t\t\t  a pocket (remove otherwise) (%.1f)\n",
            M_PAR_REFINE_MIN_NAPOL_AS, M_PAR_LONG_REFINE_MIN_NAPOL_AS, M_REFINE_MIN_PROP_APOL_AS);
    fprintf(f, "\t-%c --%s (int)\t: Minimum number of apolar neighbor for        \n\
\t\t\t\t\t\t  an a-sphere to be considered as apolar.   (%d)\n",
            M_PAR_MIN_APOL_NEIGH, M_PAR_LONG_MIN_APOL_NEIGH, M_MIN_APOL_NEIGH_DEFAULT);
    fprintf(f, "\t-%c --%s (integer)\t: Number of Monte-Carlo iteration for the      \n\
\t\t\t\t\t\t  calculation of each pocket volume.(%d)\n",
            M_PAR_MC_ITER, M_PAR_LONG_MC_ITER, M_MC_ITER);
    fprintf(f, "\t-%c --%s (char)\t\t\t: Name of the chains to be deleted before pocket detection,      \n\
\t\t\t\t\t\t  able to delete up to (%d) chains (ie : -c A,B,E)\n",
            M_PAR_DROP_CHAINS, M_PAR_DROP_CHAINS_LONG, M_MAX_CHAINS_DELETE);
    fprintf(f, "\t-%c --%s (char)\t\t\t: Name of the chains to be kept before pocket detection,      \n\
\t\t\t\t\t\t  able to keep up to (%d) chains (ie : -k A,B,C,E)\n",
            M_PAR_KEEP_CHAINS, M_PAR_KEEP_CHAINS_LONG, M_MAX_CHAINS_DELETE);
    fprintf(f, "\t-%c --%s (char)\t\t: consider this chain as a ligand explicitly (i.e. -%c D)\n",
            M_PAR_CHAIN_AS_LIGAND, M_PAR_CHAIN_AS_LIGAND_LONG, M_PAR_CHAIN_AS_LIGAND);
    fprintf(f, "\t-%c --%s (char)\t\t\t: Writing mode to be used after pocket detection,      \n\
\t\t\t\t\t\t  d -> default (same format outpout as input)\n\
\t\t\t\t\t\t  b or both -> both pdb and mmcif | p or pdb ->pdb | m or cif or mmcif-> mmcif\n",
            M_PAR_WRITE_MODE, M_PAR_WRITE_MODE_LONG);
    fprintf(f, "\n\033[1mFor more information: http://fpocket.sourceforge.net\033[0m\n");
}
/*write mode : d -> default | b -> both pdb and mmcif | p ->pdb | m  -> mmcif*/
/**
   ## FUNCTION:
        print_fparams

   ## SPECIFICATION:
        Print function

   ## PARAMETRES:
    @ s_fparams *p : Parameters to print
        @ FILE *f      : Buffer to write in

   ## RETURN:

 */
void print_fparams(s_fparams *p, FILE *f)
{
    if (p)
    {
        fprintf(f, "==============\nParameters of fpocket: \n");
        fprintf(f, "> Minimum alpha sphere radius: %f\n", p->asph_min_size);
        fprintf(f, "> Maximum alpha sphere radius: %f\n", p->asph_max_size);
        fprintf(f, "> Minimum number of apolar neighbor: %d\n", p->min_apol_neigh);
        fprintf(f, "> Maximum distance for first clustering algorithm: %f \n", p->clust_max_dist);
        fprintf(f, "> Clustering method: %c \n", p->clustering_method);
        fprintf(f, "> Min number of apolar sphere in refine to keep a pocket: %f\n", p->refine_min_apolar_asphere_prop);
        fprintf(f, "> Monte Carlo iterations: %d\n", p->nb_mcv_iter);
        fprintf(f, "> Basic method for volume calculation: %d\n", p->basic_volume_div);
        fprintf(f, "> Calculate pocket energy grids: %d\n", p->flag_do_grid_calculations);
        fprintf(f, "> PDB file: %s\n", p->pdb_path);
        fprintf(f, "> Topology file path: %s\n", p->topology_path);
        fprintf(f, "==============\n");
    }
    else
        fprintf(f, "> No parameters detected\n");
}
