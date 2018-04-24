#include "../headers/mdpocket.h"

/*

## GENERAL INFORMATION
##
## FILE 					mdpocket.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED                                01-12-2012
##
## SPECIFICATIONS
##
##	This file contains all main routines of the mdpocket program.
##	Given a set of snapshot PDB files, those routines will
##	calculate cavities on these snapshots and output these in a convenient
##      format. mdpocket currently has two different ways of running. The first
##      allows the user to explore transient and conserved cavities throughout
##      an MD trajectory. This first analysis is performed by the mdpocket_detect
##      function.
##      Once the analysis of the first run is done, the user can specify a zone
##      where he wants to measure some cavity descriptors. This task is performed
##      in a second run, but this time of the mdpocket_open_pdb_file function.
##      Both runs do not yield at all the same results and do not serve the same
##      purpose.
##      In order to get more informed about the mdpocket methodology, please refer
##      to the manual shipped with fpocket.
##
## MODIFICATIONS HISTORY
##
##      01-12-12        (p) included molfile plugin support for reading trajectories
##	01-08-09	(p) Created (random date...)
##
## TODO or SUGGESTIONS
##

 */


/*
    COPYRIGHT

    Peter Schmidtke, hereby
        claims all copyright interest in the program “mdpocket” (which
        performs protein cavity detection on multiple conformations of proteins) 
        written by Peter Schmidtke.

    Peter Schmidtke      01 Decembre 2012

 *     GNU GPL

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

static molfile_plugin_t *api;

static int register_cb(void *v, vmdplugin_t *p) {
    api = (molfile_plugin_t *) p;
    return 0;
}

/**
   ## FUNCTION:
        mdpocket_detect

   ## SPECIFICATION:
        Mdpocket main function. Perform pocket detection on all snapshots.
        Pockets will be merged in one single output file mdpout_concat.pqr and
        a grid file will be produced, containing Voronoi vertice densities on
        grid point positions

   ## PARAMETRES:
        @ s_mdparams *par: Parameters of the programm

   ## RETURN:
        void

 */
void mdpocket_detect(s_mdparams *par) {
    int i = 0, j, k;

    int n_snapshots = 0;
    FILE * fout[6]; /*output file handles*/
    FILE *timef; /*just an output for performance measurements*/
    c_lst_pockets *pockets = NULL; /*tmp handle for pockets*/
    s_mdgrid *freqgrid = NULL; /*init mdgrid structure*/
    s_mdgrid *refgrid = NULL; /*reference grid*/
    s_mdgrid *densgrid = NULL; /*density grid*/
    s_pdb *cpdb = NULL; /*handle for the current snapshot structure*/
    s_pdb *topology_pdb = NULL; /*handle for the current snapshot structure*/
    par->fpar->flag_do_asa_and_volume_calculations = 0; /*don't do ASA and volume calculations here as they are expensive and we don't need the results here*/
    FILE *cf; /*file handle for current bfact coloured file to write*/
    char cf_name[350] = "";
    char pdb_code[350] = "";

    if (!strncmp(par->traj_format, "net", 3)) {
        molfile_netcdfplugin_init();
        molfile_netcdfplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "dcd", 3)) {
        molfile_dcdplugin_init();
        molfile_dcdplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "crd", 3)) {
        molfile_crdplugin_init();
        molfile_crdplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "dtr", 3)) {
        molfile_dtrplugin_init();
        molfile_dtrplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "xtc", 3) || !strncmp(par->traj_format, "trr", 3)) {
        molfile_gromacsplugin_init();
        molfile_gromacsplugin_register(NULL, register_cb);
    }
    /*     if(par->f_topo){
             molfile_parm7plugin_init();
             molfile_parm7plugin_register(NULL, register_cb);
         }*/

    /*molfile_gromacsplugin_init();
    molfile_gromacsplugin_register(NULL, register_cb);
    molfile_lammpsplugin_init();
    molfile_lammpsplugin_register(NULL, register_cb);*/


    if (par) {
        /* Opening output files */
        //fout[0] = fopen(par->f_pqr,"w") ;   /*concat pqr output*/
        fout[1] = fopen(par->f_freqdx, "w"); /*grid dx output*/
        fout[2] = fopen(par->f_densdx, "w"); /*grid dx output*/
        fout[3] = fopen(par->f_freqiso, "w"); /*iso pdb output*/
        fout[4] = fopen(par->f_densiso, "w"); /*iso pdb output*/
        fout[5] = fopen(par->f_appdb, "w"); /*all atom -> pocket density output on bfactors*/
        timef = fopen("time.txt", "w"); /*performance measurement output*/
        if (fout[1] && fout[2] && fout[3] && fout[4] && fout[5]) {
            //mdconcat=init_md_concat();  /*alloc & init of the mdconcat structure*/
            clock_t b, e; /*for the calculation time measurements*/
            if (par->nfiles) {

                /* Begins mdpocket on list of PDB files*/
                for (i = 0; i < par->nfiles; i++) {
                    b = clock(); /*init starting time for this snapshot*/
                    fprintf(stdout, "<mdpocket>s %d/%d - %s:",
                            i + 1, par->nfiles, par->fsnapshot[i]);
                    cpdb = open_pdb_file(par->fsnapshot[i],par); /*open the snapshot*/
                    //printf("\navant %d\n",get_number_of_objects_in_memory());

                    pockets = mdprocess_pdb(cpdb, par, i + 1); /*perform pocket detection*/
                    if (pockets) {
                        if (i == 0) { /*TODO : this is a bit dangerous here*/
                            freqgrid = init_md_grid(pockets, par); /*initialize the md grid, memory allocation*/
                            densgrid = init_md_grid(pockets, par);
                            refgrid = init_md_grid(pockets, par);
                        } else {
                            reset_grid(refgrid);
                        }
                        calculate_md_dens_grid(densgrid, pockets, par); // calculate and update mdgrid with voronoi vertice local densities
                        update_md_grid(freqgrid, refgrid, pockets, par); //update mdgrid with frequency measurements
                    }
                    free_pdb_atoms(cpdb); /*free atoms of the snapshot*/
                    if (i == par->nfiles - 1) fprintf(stdout, "\n");
                    else fprintf(stdout, "\r");
                    fflush(stdout);
                    c_lst_pocket_free(pockets); /*free pockets of current snapshot*/
                    //printf("\napres %d\n",get_number_of_objects_in_memory());
                    //print_number_of_objects_in_memory();
                    e = clock(); /*snapshot analysis end time*/
                    /*output the time needed for analysis of this snapshots*/
                    fprintf(timef, "%f\n", ((double) e - b) / CLOCKS_PER_SEC);
                    fflush(timef);
                    if (DEBUG)print_number_of_objects_in_memory();

                }
                n_snapshots = par->nfiles;
            } else { /*trajectory format*/
                //                print_number_of_objects_in_memory();

                b = clock(); /*init starting time for this snapshot*/
                //                                topology_pdb=rpdb_open(par->fpar->pdb_path, NULL, M_DONT_KEEP_LIG);
                topology_pdb = open_pdb_file(par->fpar->pdb_path,par);
                //                fprintf(stdout, "topology pdb : %p\n", topology_pdb);
                //                fflush(stdout);

                /*open the snapshot*/
                rpdb_read(topology_pdb, NULL, M_KEEP_LIG, 0,par->fpar);

                //                s_topology *topol=NULL;
                //                if(par->fpar->topology_path[0]!=0){
                //                        topol=read_topology(par->fpar->topology_path,topology_pdb);
                //                }
                //        

                //                                rpdb_print(topology_pdb);
                //                print_number_of_objects_in_memory();
                void *h_in;
                int inatoms;
                molfile_timestep_t ts_in;
                int rc;
                if (!par->traj_format) {
                    fprintf(stderr, "Error : you did not specify the format of the MD trajectory with the Y option!\n");
                    return;
                }
                //                printf("Format of trajectory %s\n", par->traj_format);
                h_in = api->open_file_read(par->f_traj, par->traj_format, &inatoms);
                //print_number_of_objects_in_memory();

                if (!h_in) {
                    fprintf(stderr, "Error: could not open file '%s' for reading.\n", par->f_traj);
                    return;
                }

                if (inatoms != topology_pdb->natoms) {
                    if (strncmp(par->traj_format, "crd", 3)) {
                        fprintf(stderr, "Number of atoms in topology and MD trajectory do not coincide : %d vs %d\n", inatoms, topology_pdb->natoms);

                    } else {
                        fprintf(stderr, "Number of atoms in crd file formats cannot be determined, assuming that they correspond to the input PDB structure\n");
                        inatoms = topology_pdb->natoms;
                    }
                }
                ts_in.coords = (float *) malloc(3 * inatoms * sizeof (float));

                //                print_number_of_objects_in_memory();

                rc = api->read_next_timestep(h_in, inatoms, &ts_in);
                //print_number_of_objects_in_memory();                                
                if (rc == -1) {

                    api->close_file_read(h_in);
                }
                k = 0;
                s_atm *cur_atom;
                //                FILE *testxyz = fopen("test.xyz", "w");
                while (rc != -1) {
                    //                    print_number_of_objects_in_memory();
                    k++;
                    for (j = 0; j < inatoms; j++) {
                        cur_atom = topology_pdb->latoms_p[j];
                        cur_atom->x = ts_in.coords[3 * j];
                        cur_atom->y = ts_in.coords[3 * j + 1];
                        cur_atom->z = ts_in.coords[3 * j + 2];
                    }
                    //                    rpdb_print(topology_pdb);
                    fprintf(stdout, "<mdpocket> analysing snapshot %d", k);
                    pockets = mdprocess_pdb(topology_pdb, par, k); /*perform pocket detection*/
                    if (pockets) {
                        if (k == 1) { /*TODO : this is a bit dangerous here*/
                            freqgrid = init_md_grid(pockets, par); /*initialize the md grid, memory allocation*/
                            densgrid = init_md_grid(pockets, par);
                            refgrid = init_md_grid(pockets, par);
                        } else {
                            reset_grid(refgrid);
                        }
                        //                        writeAlphaSpheresToFile(testxyz, pockets);
                        calculate_md_dens_grid(densgrid, pockets, par); // calculate and update mdgrid with voronoi vertice local densities
                        update_md_grid(freqgrid, refgrid, pockets, par); //update mdgrid with frequency measurements
                    }
                    c_lst_pocket_free(pockets); /*free pockets of current snapshot*/
                    fprintf(stdout, "\r");
                    rc = api->read_next_timestep(h_in, inatoms, &ts_in);

                    //                    printf("reading snaps here %d - %d\n", k, rc);
                    e = clock(); /*snapshot analysis end time*/
                    /*output the time needed for analysis of this snapshots*/
                    fprintf(timef, "%f\n", ((double) e - b) / CLOCKS_PER_SEC);
                    fflush(timef);
                    //                    fflush(testxyz);

                }
                //                fclose(testxyz);
                free_pdb_atoms(topology_pdb); /*free atoms of the snapshot*/

                if (rc == -1) {
                    api->close_file_read(h_in);
                }
                n_snapshots = k;
            }
            freqgrid->n_snapshots = n_snapshots;
            densgrid->n_snapshots = n_snapshots;

            normalize_grid(freqgrid, n_snapshots);
            normalize_grid(densgrid, n_snapshots);

            if (par->nfiles) {
                cpdb = open_pdb_file(par->fsnapshot[0],par); /*open again the first snapshot*/
            } else cpdb = open_pdb_file(par->fpar->pdb_path,par); /*open again the first snapshot*/
            rpdb_read(cpdb, NULL, M_DONT_KEEP_LIG, 0,par->fpar);
            project_grid_on_atoms(densgrid, cpdb);
            write_first_bfactor_density(fout[5], cpdb);
            free_pdb_atoms(cpdb);
            if (par->bfact_on_all) {
                for (i = 0; i < par->nfiles; i++) {
                    strcpy(pdb_code, par->fsnapshot[i]);
                    remove_ext(pdb_code);
                    remove_path(pdb_code);
                    sprintf(cf_name, "%s_out.pdb", pdb_code);
                    cf = fopen(cf_name, "w");
                    cpdb = open_pdb_file(par->fsnapshot[i],par);
                    rpdb_read(cpdb, NULL, M_DONT_KEEP_LIG, 0,par->fpar);
                    project_grid_on_atoms(densgrid, cpdb);
                    write_first_bfactor_density(cf, cpdb);
                    free_pdb_atoms(cpdb);
                    fclose(cf);
                }

            }
            // fprintf(fout[0],"TER\nEND\n");          /*just to get a good pqr output file*/


            //   mdconcat->n_snapshots=par->nfiles;      /*updata a variable in the mdconcat structure*/
            //   mdgrid=calculate_md_grid(mdconcat);     /*calculate the actual md grid*/
            write_md_grid(freqgrid, fout[1], fout[3], par, M_MDP_DEFAULT_ISO_VALUE_FREQ); /*write the grid to a vmd readable dx file*/
            write_md_grid(densgrid, fout[2], fout[4], par, M_MDP_DEFAULT_ISO_VALUE_DENS); /*write the grid to a vmd readable dx file*/
            for (i = 1; i < 6; i++) fclose(fout[i]); /*close all output file handles*/

            /*free the memory for the grids noz*/
            free_md_grid(freqgrid);
            free_md_grid(densgrid);
            free_md_grid(refgrid);
            if (DEBUG) print_number_of_objects_in_memory();

        } else {
            /*if(! fout[0]) {
                    fprintf(stdout, "! Output file <%s> couldn't be opened.\n",
                                    par->f_pqr) ;
            }
            else */
            for (i = 1; i < 6; i++) {
                if (!fout[i]) {
                    fprintf(stdout, "! Output file couldn't be opened.\n");
                }
            }
        }
        fclose(timef); /*close the performance measurement file handle*/
        /*free_mdconcat(mdconcat);*/ /*should be freed by free_all*/
    }
}

/**
   ## FUNCTION:
        mdpocket_characterize

   ## SPECIFICATION:
        Mdpocket main function. Simple loop is performed over all files.

   ## PARAMETRES:
        @ s_mdparams *par: Parameters of the programm

   ## RETURN:
        void
   TODO : tidy this function a bit up, maybe split it in subfunctions
 */
void mdpocket_characterize(s_mdparams *par) {
    int i, natms, j, k;
    s_pdb *topology_pdb = NULL;
    s_fparams *params = par->fpar;
    FILE *null = fopen("/dev/null", "w"); /*open a /dev/null redir for the pqr concat output*/
    FILE *descfile = NULL; /*file handle for the descriptor file*/
    FILE * fout[2];
    FILE *elec_file = NULL;
    FILE *vdw_file = NULL;
    s_pocket *cpocket = NULL;
    s_atm **pocket_atoms;
    int *wanted_atom_ids = NULL;
    int nwanted_atom_ids = 0;
    c_lst_pockets *pockets = NULL; /*handle for the pockets found in one snapshots*/
    //  c_lst_pockets *mdpockets=c_lst_pockets_alloc();     /*handle for one pocket per snapshot in a chained list*/
    s_pdb *wantedpocket = rpdb_open(par->fwantedpocket, NULL, M_DONT_KEEP_LIG, 0,params); /*open in the reference pocket (grid points)*/
    rpdb_read(wantedpocket, NULL, M_DONT_KEEP_LIG, 0,params); /*read this pocket*/

    s_pdb *cpdb = NULL; /*pdb handle for the current snapshot structure*/


    char vdwgrid_path[350] = "";
    char elecgrid_path[350] = "";
    FILE *f_out_vdwgrid = NULL;
    FILE *f_out_elecgrid = NULL;
    if (!strncmp(par->traj_format, "net", 3)) {
        molfile_netcdfplugin_init();
        molfile_netcdfplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "dcd", 3)) {
        molfile_dcdplugin_init();
        molfile_dcdplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "crd", 3)) {
        molfile_crdplugin_init();
        molfile_crdplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "dtr", 3)) {
        molfile_dtrplugin_init();
        molfile_dtrplugin_register(NULL, register_cb);
    }
    if (!strncmp(par->traj_format, "xtc", 3) || !strncmp(par->traj_format, "trr", 3)) {
        molfile_gromacsplugin_init();
        molfile_gromacsplugin_register(NULL, register_cb);
    }


    if (par) {
        descfile = fopen(par->f_desc, "w"); /*open the descriptor output file*/
        fout[0] = fopen(par->f_ppdb, "w");
        fout[1] = fopen(par->f_apdb, "w");

        /*print all the headers in this file*/
        fprintf(descfile, M_MDP_OUTP_HEADER);
        for (j = 0; j < 20; j++) fprintf(descfile, " %s", get_aa_name3(j));
        fprintf(descfile, "\n");

        /* Begins mdpocket */
        if (par->nfiles) {
            for (i = 0; i < par->nfiles; i++) { /*loop over all snapshots*/
                //    print_number_of_objects_in_memory();
                cpocket = NULL; /*tmp for current pocket */

                fprintf(stdout, "<mdpocket>s %d/%d - %s:",
                        i + 1, par->nfiles, par->fsnapshot[i]);
                fflush(stdout);
                fprintf(fout[0], "MODEL        %d\n", i);
                cpdb = open_pdb_file(par->fsnapshot[i],par); /*open the snapshot pdb handle*/
                pockets = mdprocess_pdb(cpdb, par, i + 1); /*perform pocket detection on the current snapshot*/

                if (i == 0)wanted_atom_ids = get_wanted_atom_ids(cpdb, wantedpocket, &nwanted_atom_ids);
                write_md_pocket_atoms(fout[1], wanted_atom_ids, cpdb, nwanted_atom_ids, i);
                if (pockets) {
                    cpocket = extract_wanted_vertices(pockets, wantedpocket); /*get only vertices in the interesting zone and put them together in one pocket*/


                    //        c_lst_pockets_add_last(mdpockets,cpocket,0,0);          /*add the pocket to the chained list (will contain the pocket over the md traj)*/

                    /*some tmp stuff following,TODO : put this in a function*/
                    s_vvertice **tab_vert = (s_vvertice **)
                            malloc(cpocket->v_lst->n_vertices * sizeof (s_vvertice*));
                    j = 0;
                    node_vertice *nvcur = cpocket->v_lst->first;
                    while (nvcur) {
                        write_pqr_vert(fout[0], nvcur->vertice,j);
                        tab_vert[j] = nvcur->vertice;
                        nvcur = nvcur->next;
                        j++;
                    }

                    /*get atoms contacted by the pocket*/
                    pocket_atoms = get_pocket_contacted_atms(cpocket, &natms);
                    set_descriptors(pocket_atoms, natms, tab_vert, cpocket->v_lst->n_vertices, cpocket->pdesc, par->fpar->nb_mcv_iter, cpdb, par->fpar->flag_do_asa_and_volume_calculations);

                    my_free(pocket_atoms); /*free current pocket atoms*/
                    free(tab_vert); /*free tmp vertice tab*/
                    if (DEBUG) print_number_of_objects_in_memory();




                    /* Calculate descriptors*/
                    write_md_descriptors(descfile, cpocket, i + 1); /*write MD descriptors to the descriptor output file*/
                    if (DEBUG) print_number_of_objects_in_memory();

                    //my_free(pocket_atoms) ;     /*free current pocket atoms*/
                    free_pocket(cpocket);
                }


                free_pdb_atoms(cpdb); /*free memory of the current snapshot atoms*/
                // free_pocket(cpocket);
                /*just some stupid print to stdout things*/
                if (i == par->nfiles - 1) fprintf(stdout, "\n");
                else fprintf(stdout, "\r");
                fflush(stdout);
                fprintf(fout[0], "ENDMDL\n\n");
                c_lst_pocket_free(pockets); /*free pockets of current snapshot*/
            }
        } else {

            topology_pdb = open_pdb_file(par->fpar->pdb_path,par); /*open the snapshot*/
            rpdb_read(topology_pdb, NULL, M_KEEP_LIG, 0,params);



            if (par->fpar->topology_path[0] != 0) {
                read_topology(par->fpar->topology_path, topology_pdb);
            }

            //print_number_of_objects_in_memory();
            void *h_in;
            int inatoms = 0;
            molfile_timestep_t ts_in;
            int rc;
            if (!par->traj_format) {
                fprintf(stderr, "Error : you did not specify the format of the MD trajectory with the Y option!\n");
                return;
            }
            fprintf(stdout, "Format of trajectory %s %s %d\n", par->traj_format, par->f_traj, inatoms);
            fflush(stdout);
            h_in = api->open_file_read(par->f_traj, par->traj_format, &inatoms);

            fflush(stdout);
            //print_number_of_objects_in_memory();

            if (!h_in) {
                fprintf(stderr, "Error: could not open file '%s' for reading.\n", par->f_traj);
                return;
            }

            if (inatoms != topology_pdb->natoms) {
                if (strncmp(par->traj_format, "crd", 3)) {
                    fprintf(stderr, "Number of atoms in topology and MD trajectory do not coincide : %d vs %d\n", inatoms, topology_pdb->natoms);

                } else {
                    fprintf(stderr, "Number of atoms in crd file formats cannot be determined, assuming that they correspond to the input PDB structure\n");
                    inatoms = topology_pdb->natoms;
                }
            }
            ts_in.coords = (float *) my_malloc(3 * inatoms * sizeof (float));

            //print_number_of_objects_in_memory();

            rc = api->read_next_timestep(h_in, inatoms, &ts_in);
            //print_number_of_objects_in_memory();                                
            if (rc == -1) {

                api->close_file_read(h_in);
            }
            k = 0;
            s_atm *cur_atom;

            s_grid *pocket_vdw_grid = NULL;
            s_grid *pocket_elec_grid = NULL;

//            fprintf(stdout, "MDPOCKET CHARACTERIZATION\n");

            while (rc != -1) {
                cpocket = NULL;
                //                print_number_of_objects_in_memory();
                k++;
                fprintf(stdout, "<mdpocket> analysing snapshot %d", k);
                for (j = 0; j < inatoms; j++) {
                    cur_atom = topology_pdb->latoms_p[j];
                    cur_atom->x = ts_in.coords[3 * j];
                    cur_atom->y = ts_in.coords[3 * j + 1];
                    cur_atom->z = ts_in.coords[3 * j + 2];
                }
                pockets = mdprocess_pdb(topology_pdb, par, k); /*perform pocket detection on the current snapshot*/
//                fprintf(stdout, "natoms : %d\n", topology_pdb->natoms);
                fprintf(stdout, "\r");
                if (k == 1) { //if it's the first snapshot that has been analyzed
                    create_coord_grid(topology_pdb);
                    wanted_atom_ids = get_wanted_atom_ids(topology_pdb, wantedpocket, &nwanted_atom_ids);
//                    fprintf(stdout, "\nFound %d atoms to track for neighbourhood lists\n", nwanted_atom_ids);
//                    fflush(stdout);

                }
                write_md_pocket_atoms(fout[1], wanted_atom_ids, topology_pdb, nwanted_atom_ids, k - 1);
                if (pockets) {
                    cpocket = extract_wanted_vertices(pockets, wantedpocket); /*get only vertices in the interesting zone and put them together in one pocket*/

                    if (par->fpar->flag_do_grid_calculations) {
                        if (k % 10 == 0) {
                            sprintf(vdwgrid_path, "vdw_energy_grid_%04d.dx", k);
                            sprintf(elecgrid_path, "elec_energy_grid_%04d.dx", k);
                            f_out_vdwgrid = fopen(vdwgrid_path, "w");
                            f_out_elecgrid = fopen(elecgrid_path, "w");
                        }
                        if (k == 1) {
                            pocket_vdw_grid = init_pocket_grid(cpocket);
                            pocket_elec_grid = init_pocket_grid(cpocket);

                        }
                        assign_energies(pocket_elec_grid, pocket_vdw_grid, cpocket, topology_pdb);

                        if (k % 10 == 0) {
                            write_grid(pocket_vdw_grid, f_out_vdwgrid);
                            write_grid(pocket_elec_grid, f_out_elecgrid);

                            fclose(f_out_vdwgrid);
                            fclose(f_out_elecgrid);
                        }
                    }

                    //        c_lst_pockets_add_last(mdpockets,cpocket,0,0);          /*add the pocket to the chained list (will contain the pocket over the md traj)*/

                    /*some tmp stuff following,TODO : put this in a function*/
                    s_vvertice **tab_vert = (s_vvertice **)
                            malloc(cpocket->v_lst->n_vertices * sizeof (s_vvertice*));
                    j = 0;
                    node_vertice *nvcur = cpocket->v_lst->first;
                    while (nvcur) {
                        write_pqr_vert(fout[0], nvcur->vertice,j);
                        tab_vert[j] = nvcur->vertice;
                        nvcur = nvcur->next;
                        j++;
                    }

                    /*get atoms contacted by the pocket*/
                    pocket_atoms = get_pocket_contacted_atms(cpocket, &natms);
                    set_descriptors(pocket_atoms, natms, tab_vert, cpocket->v_lst->n_vertices, cpocket->pdesc, par->fpar->nb_mcv_iter, topology_pdb, par->fpar->flag_do_asa_and_volume_calculations);
                    //if (par->fpar->flag_do_grid_calculations && k == 1) vdw_grid = init_pocket_grid(cpocket);
                    my_free(pocket_atoms); /*free current pocket atoms*/
                    free(tab_vert); /*free tmp vertice tab*/

                    /* Calculate descriptors*/
                    write_md_descriptors(descfile, cpocket, k); /*write MD descriptors to the descriptor output file*/

                    if (DEBUG) print_number_of_objects_in_memory();

                    //my_free(pocket_atoms) ;     /*free current pocket atoms*/
                    free_pocket(cpocket);
                }
                // free_pocket(cpocket);
                /*just some stupid print to stdout things*/

                fprintf(stdout, "\r");
                fprintf(fout[0], "ENDMDL\n\n");
                c_lst_pocket_free(pockets); /*free pockets of current snapshot*/
                rc = api->read_next_timestep(h_in, inatoms, &ts_in);
            }
            fprintf(stdout, "\n");

            if (par->fpar->flag_do_grid_calculations) {
                assign_mean_energies(pocket_vdw_grid, k);
                assign_mean_energies(pocket_elec_grid, k);
                elec_file = fopen(par->f_elec, "w");
                vdw_file = fopen(par->f_vdw, "w");

                write_grid(pocket_vdw_grid, vdw_file);
                fclose(vdw_file);

                write_grid(pocket_elec_grid, elec_file);
                fclose(elec_file);

            }

            //free_pdb_atoms(topology_pdb); /*free memory of the current snapshot atoms*/
        }

        fclose(descfile); /*close the descriptor output file handle*/
        /*free_mdconcat(mdconcat);*/ /*should be freed by free_all*/
        for (i = 0; i < 2; i++) fclose(fout[i]);
    }
    fclose(wantedpocket->fpdb);
    fclose(null); /*close the /dev/null file handle*/
}

/**
   ## FUNCTION:
        write_md_descriptors

   ## SPECIFICATION:
        Write the md descriptors to the output file

   ## PARAMETRES:
        @ FILE *f : file handler of the output file
        @ s_pocket *p : pointer to the md pocket
        @ int i : integer containing the current snapshot number

   ## RETURN:
        void

 */
void write_md_descriptors(FILE *f, s_pocket *p, int i) {
    s_desc *d = p->pdesc;

    fprintf(f, M_MDP_OUTP_FORMAT, M_MDP_OUTP_VAR(i, d));
    int j;
    for (j = 0; j < 20; j++) fprintf(f, " %3d", d->aa_compo[j]);

    fprintf(f, "\n");
    fflush(f);
}

/**
   ## FUNCTION:
        extract_wanted_vertices

   ## SPECIFICATION:
        Return a pocket structure containing all vertices that are nearby the
        wanted zone given in the input file

   ## PARAMETRES:
        @ c_lst_pockets *pockets : Chained list of pockets found in the current
                                   Snapshot
        @ s_pdb *pdb : The wanted vertices in a pdb structure handle

   ## RETURN:
        s_pocket * : One pocket containing all interesting vertices

 */
s_pocket* extract_wanted_vertices(c_lst_pockets *pockets, s_pdb *pdb) {
    s_pocket *p = alloc_pocket(); /*alloc memory for a new pocket*/
    p->v_lst = c_lst_vertices_alloc(); /*alloc memory for vertices in new pocket*/
    s_pocket *cp = NULL; /*just a handler for the chained list navigation*/
    node_pocket *cur = NULL; /*again just a handler for navigation*/
    cur = pockets->first; /*get the first pocket in the chained list*/
    s_vvertice** pverts = NULL; /*define a vertice object*/
    size_t i;
    int z;
    s_atm *cura = NULL;




    while (cur) { /*loop over all snapshot pockets*/
        cp = cur->pocket;
        pverts = get_pocket_pvertices(cp); /*get the current pocket vertices*/


        if (1) {
            for (i = 0; i < cp->v_lst->n_vertices; i++) { /*loop over these vertices*/
                for (z = 0; z < pdb->natoms; z++) { /*loop over wanted vertices*/
                    cura = pdb->latoms_p[z]; /*get wanted vertice in an atom object*/
                    if (dist(cura->x, cura->y, cura->z, pverts[i]->x, pverts[i]->y, pverts[i]->z) <= (float) M_MDP_CUBE_SIDE / 2.0) {
                        c_lst_vertices_add_last(p->v_lst, pverts[i]); /*if the current vertice is near the wanted one, add it to the new pocket*/
                    }
                }
            }
        }
        my_free(pverts);
        cur = cur->next;
    }



    //   free_pocket(p);

    //    my_free(pverts);



    return (p);
}

/**
   ## FUNCTION:
        get_wanted_atom_ids

   ## SPECIFICATION:
        Given an input pocket by the user, this function returns all atoms on
        the protein that are nearby (usually on the first snapshot).
        This is useful for the output of the pocket motions

   ## PARAMETRES:
        @ s_pdb *prot : Protein structure
        @ s_pdb *pocket : The pocket (grid points) organized as s_pdb structure
        @ int *n : Pointer to int storing the number of atoms that are selected
            by this function.

   ## RETURN:
        int * : List of atom ids

 */
int *get_wanted_atom_ids(s_pdb *prot, s_pdb *pocket, int *n) {
    int *ids = (int *) my_malloc(sizeof (int));
    int v, a;
    *n = 1;
    s_atm *cura = NULL;
    s_atm *curv = NULL;
    int flag = 0;
    for (a = 0; a < prot->natoms; a++) {
        cura = prot->latoms_p[a];
        v = 0;
        flag = 0;
        while (flag == 0 && v < pocket->natoms) {
            curv = pocket->latoms_p[v];
            if (dist(cura->x, cura->y, cura->z, curv->x, curv->y, curv->z) <= M_MDP_WP_ATOM_DIST) {
                ids[*n - 1] = cura->id;
                *n = *n + 1;
                ids = (int *) my_realloc(ids, sizeof (int) *(*n));
                ids[*n - 1]=-1;
                flag = 1;
            }
            v++;
        }
    }
    return (ids);

}

/**
   ## FUNCTION:
        open_pdb_file

   ## SPECIFICATION:
        Return a pdb structure containing an opened, yet not read pdb file

   ## PARAMETRES:
        @ char *pdbname : Name of the pdb file to open

   ## RETURN:
        s_pdb * : A pdb structure handle of the opened file
        TODO : place this function in rpdb.c
 */
s_pdb *open_pdb_file(char *pdbname,s_mdparams *mdparams) {
    if (pdbname == NULL) return NULL;
    s_fparams *params = mdparams->fpar;
    int len = strlen(pdbname);
    if (len >= M_MAX_PDB_NAME_LEN || len <= 0) {
        fprintf(stderr, "! Invalid length for the pdb file name. (Max: %d, Min 1)\n",
                M_MAX_PDB_NAME_LEN);
        return NULL;
    }

    /* Try to open it */
    s_pdb *pdb = rpdb_open(pdbname, NULL, M_DONT_KEEP_LIG, 0,params);
    if (pdb) return (pdb);
    return NULL;
}

/**
   ## FUNCTION:
        mdprocess_pdb

   ## SPECIFICATION:
        Process (fpocket) one snapshot and return all the pockets

   ## PARAMETRES:
        @ s_pdb *pdb : The current snapshot structure handle
        @ s_mdparams *mdparams : Parameter structure of the md run
        @ FILE * pqrout : File handle for the pqr concat output
        @ int snnumber : Number of the current snapshot

   ## RETURN:
        c_lst_pockets * : chained list of the fpocket identified pockets on this
                          snapshot

 */
c_lst_pockets* mdprocess_pdb(s_pdb *pdb, s_mdparams *mdparams, int snnumber) {
    c_lst_pockets *pockets = NULL;
    s_fparams *params = mdparams->fpar;
    /* Check the PDB file */

    if (pdb) {
        /* Actual reading of pdb data and then calculation */

        if (mdparams->flag_MD == 0) rpdb_read(pdb, NULL, M_DONT_KEEP_LIG, 0,params);

        params->fpocket_running = 0;
        pockets = search_pocket(pdb, params, pdb); /*run fpocket*/
        //  if(pockets) write_mdpockets_concat_pqr(pqrout,pockets); /*write pqr concat output*/
    } else fprintf(stderr, "! PDB reading failed on snapshot %d\n", snnumber);
    return pockets;
}



