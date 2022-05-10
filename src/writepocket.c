
#include "../headers/writepocket.h"
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
## FILE 					writepocket.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			02-12-08
##
## SPECIFICATIONS
##
##  Output routine for pockets.
##
## MODIFICATIONS HISTORY
##
##  02-12-08    (v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##

 */

/*header for the mmcif writing*/

extern char write_mode[10];
static const char atomSiteHeader[] =
    "loop_\n"
    "_atom_site.group_PDB\n"
    "_atom_site.id\n"
    "_atom_site.type_symbol\n"
    "_atom_site.label_atom_id\n"
    "_atom_site.label_alt_id\n"
    "_atom_site.label_comp_id\n"
    "_atom_site.label_asym_id\n"
    "_atom_site.label_entity_id\n"
    "_atom_site.label_seq_id\n"
    "_atom_site.pdbx_PDB_ins_code\n"
    "_atom_site.Cartn_x\n"
    "_atom_site.Cartn_y\n"
    "_atom_site.Cartn_z\n"
    "_atom_site.occupancy\n"
    "_atom_site.pdbx_formal_charge\n"
    "_atom_site.auth_asym_id\n";

    /*static const char atomSiteHeader[] =
    "loop_\n"
    "_atom_site.group_PDB\n"
    "_atom_site.id\n"
    "_atom_site.type_symbol\n"
    "_atom_site.label_atom_id\n"
    "_atom_site.label_alt_id\n"
    "_atom_site.label_comp_id\n"
    "_atom_site.label_asym_id\n"
    "_atom_site.label_entity_id\n"
    "_atom_site.label_seq_id\n"
    "_atom_site.pdbx_PDB_ins_code\n"
    "_atom_site.Cartn_x\n"
    "_atom_site.Cartn_y\n"
    "_atom_site.Cartn_z\n"
    "_atom_site.occupancy\n"
    "_atom_site.pdbx_formal_charge\n"
    "_atom_site.auth_seq_id\n"
    "_atom_site.auth_comp_id\n"
    "_atom_site.auth_asym_id\n"
    "_atom_site.auth_atom_id\n";*/


void write_each_pocket_for_DB(const char out_path[], c_lst_pockets *pockets, s_pdb *pdb) {
    int out_len = strlen(out_path);
    char out[out_len + 20];
    out[0] = '\0';

    node_pocket *pcur;

    int i = 0;
    if (pockets) {
        pcur = pockets->first;

        while (pcur) {
            sprintf(out, "%s/pocket%d_vert.pqr", out_path, i + 1);
            write_pocket_pqr_DB(out, pcur->pocket);

            sprintf(out, "%s/pocket%d_env_atm.pdb", out_path, i + 1);
            write_pocket_pdb_DB(out, pcur->pocket, pdb);

            
            sprintf(out, "%s/pocket%d_atm.pdb", out_path, i + 1);
            write_pocket_pdb(out, pcur->pocket);

            pcur = pcur->next;
            i++;
        }
    } else {
        fprintf(stderr, "! The file %s could not be opened!\n", out);
    }
}

void write_pocket_pqr_DB(const char out[], s_pocket *pocket) {
    node_vertice *vcur = NULL;
    int i=0;
    FILE *f = fopen(out, "w");
    if (f && pocket) {
        vcur = pocket->v_lst->first;

        while (vcur) {
            i++;
            write_pqr_vert(f, vcur->vertice,i);

            vcur = vcur->next;
        }

        fprintf(f, "TER\nEND\n");
        fclose(f);
    } else {
        if (!f) fprintf(stderr, "! The file %s could not be opened!\n", out);
        else fprintf(stderr, "! Invalid pocket to write in write_pocket_pqr !\n");
    }
}

void write_pocket_pdb_DB(const char out[], s_pocket *pocket, s_pdb *pdb) {
    int i = 0, nvert = 0;
    s_atm **atms = (s_atm **) my_malloc(sizeof (s_atm*)*10);
    s_atm *atom = NULL;
    int n_sa = 0;
    int *sa = NULL; /*surrounding atoms container*/
    s_vvertice **tab_vert = NULL;

    FILE *f = fopen(out, "w");
    if (f && pocket) {
        // First get the list of atoms
        tab_vert = (s_vvertice **) my_malloc(pocket->v_lst->n_vertices * sizeof (s_vvertice*));

        node_vertice *nvcur = pocket->v_lst->first;

       /* 
                                fprintf(stdout, "A Pocket:\n") ;
        */
        while (nvcur) {
            /*
                                            fprintf(stdout, "Vertice %d: %p %d %f\n", i, nvcur->vertice, nvcur->vertice->id, nvcur->vertice->ray) ;
                                            fprintf(stdout, "Atom %s\n", nvcur->vertice->neigh[0]->name) ;
             */

            tab_vert[nvert] = nvcur->vertice;
            nvcur = nvcur->next;
            nvert++;
        }
        sa = (int *) get_surrounding_atoms_idx(tab_vert, nvert, pdb, &n_sa);
        for (i = 0; i < n_sa; i++) {
            //atom = pocket->sou_atoms[i] ;
            atom = pdb->latoms_p[sa[i]];
            write_pdb_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                    atom->res_name, atom->chain, atom->res_id,
                    atom->pdb_insert, atom->x, atom->y, atom->z,
                    atom->dA, atom->a0, atom->abpa, atom->symbol,
                    atom->charge, atom->abpa_sourrounding_prob);
        }
        /*
                    vcur = pocket->v_lst->first ;

                        while(vcur){
                                for(i = 0 ; i < 4 ; i++) {
                                        if(!is_in_lst_atm(atms, cur_size, vcur->vertice->neigh[i]->id)) {
                                                if(cur_size >= cur_allocated-1) {
                                                        cur_allocated *= 2 ;
                                                        atms = (s_atm**) my_realloc(atms, sizeof(s_atm)*cur_allocated) ;
                                                }
                                                atms[cur_size] = vcur->vertice->neigh[i] ;
                                                cur_size ++ ;
                                        }

                                }
                                vcur = vcur->next ;
                        }
         */
        // Then write atoms...
        /*
                        for(i = 0 ; i < cur_size ; i++) {
                                atom = atms[i] ;

                                write_pdb_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                                                                                atom->res_name, atom->chain, atom->res_id,
                                                                                atom->pdb_insert, atom->x, atom->y, atom->z,
                                                                                atom->occupancy, atom->bfactor, atom->symbol,
                                                                                atom->charge);
                        }
         */
        fprintf(f, "TER\nEND\n");
        fclose(f);
    } else {
        if (!f) fprintf(stderr, "! The file %s could not be opened!\n", out);
        else fprintf(stderr, "! Invalid pocket to write in write_pocket_pqr !\n");
    }

    my_free(atms);
}

/**
   ## FUNCTION: 
        write_single_pdb
  
   ## SPECIFICATION: 
        Write atoms and vertices given in argument in the following standard v2.2 
        pdb format.

  
   ## PARAMETRES:
        @ const char out[]       : Output file name
        @ s_pdb *pdb             : PDB infos
        @ c_lst_pockets *pockets : All pockets
  
   ## RETURN:
  
 */
void write_pockets_single_pdb(const char out[], s_pdb *pdb, c_lst_pockets *pockets) {
    node_pocket *nextPocket;
    node_vertice *nextVertice;
    int i=0;
    FILE *f = fopen(out, "w");
    if (f) {
        if (pdb) {
            if (pdb->latoms) write_pdb_atoms(f, pdb->latoms, pdb->natoms);
        }

        if (pockets) {
            pockets->current = pockets->first;

            while (pockets->current) {
                pockets->current->pocket->v_lst->current = pockets->current->pocket->v_lst->first;
                i=0;
                while (pockets->current->pocket->v_lst->current) {
                    i++;
                    
                    if(strstr(out,".pdb"))
                    write_pdb_vert(f, pockets->current->pocket->v_lst->current->vertice,i);
                    else if(strstr(out,".cif"))
                    write_mmcif_vert(f, pockets->current->pocket->v_lst->current->vertice,i);
                    nextVertice = pockets->current->pocket->v_lst->current->next;
                    pockets->current->pocket->v_lst->current = nextVertice;
                }
                /*
                                                printf("pocket %d\n",pockets->current->pocket->rank);
                 */
                nextPocket = pockets->current->next;
                pockets->current = nextPocket;
            }
        }

        fclose(f);
    } else {
        fprintf(stderr, "! The file %s could not be opened!\n", out);
    }
}

void write_pockets_single_mmcif(const char out[], s_pdb *pdb, c_lst_pockets *pockets) {
    node_pocket *nextPocket;
    node_vertice *nextVertice;
    int i=0;
    char tmp[250];
    strcpy(tmp,out);
    remove_ext(tmp);
    remove_path(tmp);

    FILE *f = fopen(out, "w");
    fprintf(f,"data_%s\n# \n",tmp);
    fprintf(f,"%s",atomSiteHeader);/*print the header*/
    if (f) {
        if (pdb) {
            if (pdb->latoms) write_mmcif_atoms(f, pdb->latoms, pdb->natoms);
        }
    
    if (pockets) {
            pockets->current = pockets->first;

            while (pockets->current) {
                pockets->current->pocket->v_lst->current = pockets->current->pocket->v_lst->first;
                i=0;
                while (pockets->current->pocket->v_lst->current) {
                    i++;

                    if(strstr(out,".pdb"))
                    write_pdb_vert(f, pockets->current->pocket->v_lst->current->vertice,i);
                    else if(strstr(out,".cif"))
                    write_mmcif_vert(f, pockets->current->pocket->v_lst->current->vertice,i);    
                    
                    nextVertice = pockets->current->pocket->v_lst->current->next;
                    pockets->current->pocket->v_lst->current = nextVertice;
                }
                
                              //                  printf("pocket %d\n",pockets->current->pocket->rank);
                 
                nextPocket = pockets->current->next;
                pockets->current = nextPocket;
            }
        }
        fprintf(f,"# \n");/*end of mmcif file*/
      fclose(f);
    } else {
        fprintf(stderr, "! The file %s could not be opened!\n", out);
    }


}

/**
   ## FUNCTION: 
        write_pdb_atoms
  
   ## SPECIFICATION:
        Print list of atoms as pdb format in given buffer
  
   ## PARAMETRES:
        @ FILE *f      : Buffer to write in.
        @ s_atm *atoms : List of atoms
        @ int natoms   : Number of atoms
  
   ## RETURN:
  
 */
void write_pdb_atoms(FILE *f, s_atm *atoms, int natoms) {
    s_atm *atom = NULL;
    int i = 0;
    for (i = 0; i < natoms; i++) {
        atom = atoms + i;
        //atom->chain[1]='\0';
        //printf("%d:%s|symb:%s\t",i,atom->chain,atom->symbol);
        write_pdb_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                atom->res_name, atom->chain, atom->res_id,
                atom->pdb_insert, atom->x, atom->y, atom->z,
                atom->dA, atom->a0, atom->abpa, atom->symbol,
                atom->charge, atom->abpa_sourrounding_prob);
    }
}

void write_mmcif_atoms(FILE *f, s_atm *atoms, int natoms) {
    s_atm *atom = NULL;
    int i = 0;
    for (i = 0; i < natoms; i++) {
        atom = atoms + i;
        //atom->chain[1]='\0';
        //printf("%d:%s|symb:%s\t",i,atom->chain,atom->symbol);
        write_mmcif_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                atom->res_name, atom->chain, atom->res_id,
                atom->pdb_insert, atom->x, atom->y, atom->z,
                atom->dA, atom->a0, atom->abpa, atom->symbol,
                atom->charge, atom->abpa_sourrounding_prob);
    }

}


/**
   ## FUNCTION:
        write_pockets_single_pqr
  
   ## SPECIFICATION: 
        Write only pockets (alpha sphere) given in argument in the pqr format.

        !! No atoms writen here, only all pockets in a single pqr file.
  
   ## PARAMETRES:
        @ const char out[]       : Output file path
        @ c_lst_pockets *pockets : List of pockets
  
   ## RETURN:
  
 */
void write_pockets_single_pqr(const char out[], c_lst_pockets *pockets) {
    node_pocket *nextPocket;
    node_vertice *nextVertice;
    int i = 0;
    FILE *f = fopen(out, "w");
    if (f) {

        if (pockets) {
            fprintf(f, "HEADER\n");
            fprintf(f, "HEADER This is a pqr format file writen by the programm fpocket.                 \n");
            fprintf(f, "HEADER It contains all the pocket vertices found by fpocket.                    \n");
            pockets->current = pockets->first;

            while (pockets->current) {
               
                pockets->current->pocket->v_lst->current = pockets->current->pocket->v_lst->first;

                while (pockets->current->pocket->v_lst->current) {
                    i++;
                    write_pqr_vert(f, pockets->current->pocket->v_lst->current->vertice,i);

                    nextVertice = pockets->current->pocket->v_lst->current->next;
                    pockets->current->pocket->v_lst->current = nextVertice;
                }

                nextPocket = pockets->current->next;
                pockets->current = nextPocket;
            }
        }

        fprintf(f, "TER\nEND\n");
        fclose(f);
    } else {
        fprintf(stderr, "! The file %s could not be opened!\n", out);
    }
}

/**
   ## FUNCTION:
        write_mdpockets_concat_pqr

   ## SPECIFICATION:
        Write only pockets (alpha sphere) given in argument in the pqr format.

        !! No atoms writen here, only all pockets in a single pqr file.

   ## PARAMETRES:
        @ File *f       : File handle for the output file
        @ c_lst_pockets *pockets : List of pockets

   ## RETURN:

 */
void write_mdpockets_concat_pqr(FILE *f, c_lst_pockets *pockets) {
    node_pocket *nextPocket;
    node_vertice *nextVertice;
    int i=0;
    if (f) {

        if (pockets) {
            pockets->current = pockets->first;

            while (pockets->current) {
                pockets->current->pocket->v_lst->current = pockets->current->pocket->v_lst->first;

                while (pockets->current->pocket->v_lst->current) {
                    i++;
                    write_pqr_vert(f, pockets->current->pocket->v_lst->current->vertice,i);

                    nextVertice = pockets->current->pocket->v_lst->current->next;
                    pockets->current->pocket->v_lst->current = nextVertice;
                }

                nextPocket = pockets->current->next;
                pockets->current = nextPocket;
            }
        }
    } else {
        fprintf(stderr, "! The pqr concat output file is not open!\n");
    }
}

/**
   ## FUNCTION:
        write_each_pocket
  
   ## SPECIFICATION: 
        Write each pocket in a single pqr (vertices) and pdb (atoms) file format.
  
   ## PARAMETRES:
        @ const char out[]       : Output file path
        @ c_lst_pockets *pockets : List of pockets
  
   ## RETURN:
  
 */
void write_each_pocket(const char out_path[], c_lst_pockets *pockets) {
    int out_len = strlen(out_path);
    char out[out_len + 20];
    out[0] = '\0';

    node_pocket *pcur;

    int i = 1;
    if (pockets) {
        pcur = pockets->first;
        
        while (pcur) {
            sprintf(out, "%s/pocket%d_vert.pqr", out_path, i);

            write_pocket_pqr(out, pcur->pocket);
            
            if(write_mode[0] == 'p' || write_mode[0] == 'b'){
            sprintf(out, "%s/pocket%d_atm.pdb", out_path, i);
            write_pocket_pdb(out, pcur->pocket);
            }

            if(write_mode[0] == 'm' || write_mode[0] == 'b'){
            sprintf(out, "%s/pocket%d_atm.cif", out_path, i);
            write_pocket_mmcif(out, pcur->pocket);
            }
            pcur = pcur->next;
            i++;
        }
    } else {
        fprintf(stderr, "! The file %s could not be opened!\n", out);
    }
}

/**
   ## FUNCTION:
        void write_pocket_pqr
  
   ## SPECIFICATION: 
        Write vertices of the pocket given in argument in the pqr format.

  
   ## PARAMETRES:
        @ const char out[]  : Output file path
        @ s_pocket *pocket : The pocket to write
  
   ## RETURN:
  
 */
void write_pocket_pqr(const char out[], s_pocket *pocket) {
    node_vertice *vcur = NULL;
    int i=0;
    FILE *f = fopen(out, "w");
    if (f && pocket) {
        fprintf(f, "HEADER\n");
        fprintf(f, "HEADER This is a pqr format file writen by the programm fpocket.                 \n");
        fprintf(f, "HEADER It represent the voronoi vertices of a single pocket found by the         \n");
        fprintf(f, "HEADER algorithm.                                                                \n");
        fprintf(f, "HEADER                                                                           \n");
        fprintf(f, "HEADER Information about the pocket %5d:\n", pocket->v_lst->first->vertice->resid);
        fprintf(f, "HEADER 0  - Pocket Score                      : %.4f\n", pocket->score);
        fprintf(f, "HEADER 1  - Drug Score                        : %.4f\n", pocket->pdesc->drug_score);
        fprintf(f, "HEADER 2  - Number of V. Vertices             : %5d\n", pocket->pdesc->nb_asph);
        fprintf(f, "HEADER 3  - Mean alpha-sphere radius          : %.4f\n", pocket->pdesc->mean_asph_ray);
        fprintf(f, "HEADER 4  - Mean alpha-sphere SA              : %.4f\n", pocket->pdesc->masph_sacc);
        fprintf(f, "HEADER 5  - Mean B-factor                     : %.4f\n", pocket->pdesc->flex);
        fprintf(f, "HEADER 6  - Hydrophobicity Score              : %.4f\n", pocket->pdesc->hydrophobicity_score);
        fprintf(f, "HEADER 7  - Polarity Score                    : %5d\n", pocket->pdesc->polarity_score);
        fprintf(f, "HEADER 8  - Volume Score                      : %.4f\n", pocket->pdesc->volume_score);
        fprintf(f, "HEADER 9  - Real volume (approximation)       : %.4f\n", pocket->pdesc->volume);
        fprintf(f, "HEADER 10 - Charge Score                      : %5d\n", pocket->pdesc->charge_score);
        fprintf(f, "HEADER 11 - Local hydrophobic density Score   : %.4f\n", pocket->pdesc->mean_loc_hyd_dens);
        fprintf(f, "HEADER 12 - Number of apolar alpha sphere     : %5d\n", pocket->nAlphaApol);
        fprintf(f, "HEADER 13 - Proportion of apolar alpha sphere : %.4f\n", pocket->pdesc->apolar_asphere_prop);

        vcur = pocket->v_lst->first;

        while (vcur) {
            i++;
            write_pqr_vert(f, vcur->vertice,i);

            vcur = vcur->next;
        }

        fprintf(f, "TER\nEND\n");
        fclose(f);
    } else {
        if (!f) fprintf(stderr, "! The file %s could not be opened!\n", out);
        else fprintf(stderr, "! Invalid pocket to write in write_pocket_pqr !\n");
    }
}

/**
   ## FUNCTION:
        write_pocket_pdb
  
   ## SPECIFICATION: 
        Write atoms contacted by vertices of the pocket given in argument in 
        the pdb format.

  
   ## PARAMETRES:
        @ const char out[]  : Output file path
        @  s_pocket *pocket : The pocket to write
  
   ## RETURN:
  
 */
void write_pocket_pdb(const char out[], s_pocket *pocket) {
    node_vertice *vcur = NULL;
    int i = 0;
    int cur_size = 0,
            cur_allocated = 10;

    s_atm **atms = (s_atm**) my_malloc(sizeof (s_atm*)*10);
    s_atm *atom = NULL;

    FILE *f = fopen(out, "w");
    if (f && pocket) {

        fprintf(f, "HEADER\n");
        fprintf(f, "HEADER This is a pdb format file writen by the programm fpocket.                 \n");
        fprintf(f, "HEADER It represents the atoms contacted by the voronoi vertices of the pocket.  \n");
        fprintf(f, "HEADER                                                                           \n");
        fprintf(f, "HEADER Information about the pocket %5d:\n", pocket->v_lst->first->vertice->resid);
        fprintf(f, "HEADER 0  - Pocket Score                      : %.4f\n", pocket->score);
        fprintf(f, "HEADER 1  - Drug Score                        : %.4f\n", pocket->pdesc->drug_score);
        fprintf(f, "HEADER 2  - Number of alpha spheres           : %5d\n", pocket->pdesc->nb_asph);
        fprintf(f, "HEADER 3  - Mean alpha-sphere radius          : %.4f\n", pocket->pdesc->mean_asph_ray);
        fprintf(f, "HEADER 4  - Mean alpha-sphere Solvent Acc.    : %.4f\n", pocket->pdesc->masph_sacc);
        fprintf(f, "HEADER 5  - Mean B-factor of pocket residues  : %.4f\n", pocket->pdesc->flex);
        fprintf(f, "HEADER 6  - Hydrophobicity Score              : %.4f\n", pocket->pdesc->hydrophobicity_score);
        fprintf(f, "HEADER 7  - Polarity Score                    : %5d\n", pocket->pdesc->polarity_score);
        fprintf(f, "HEADER 8  - Amino Acid based volume Score     : %.4f\n", pocket->pdesc->volume_score);
        fprintf(f, "HEADER 9  - Pocket volume (Monte Carlo)       : %.4f\n", pocket->pdesc->volume);
        fprintf(f, "HEADER 10  -Pocket volume (convex hull)       : %.4f\n", pocket->pdesc->convex_hull_volume);
        fprintf(f, "HEADER 11 - Charge Score                      : %5d\n", pocket->pdesc->charge_score);
        fprintf(f, "HEADER 12 - Local hydrophobic density Score   : %.4f\n", pocket->pdesc->mean_loc_hyd_dens);
        fprintf(f, "HEADER 13 - Number of apolar alpha sphere     : %5d\n", pocket->nAlphaApol);
        fprintf(f, "HEADER 14 - Proportion of apolar alpha sphere : %.4f\n", pocket->pdesc->apolar_asphere_prop);

        /* First get the list of atoms */
        vcur = pocket->v_lst->first;

        while (vcur) {
            for (i = 0; i < 4; i++) {
                if (!is_in_lst_atm(atms, cur_size, vcur->vertice->neigh[i]->id)) {
                    if (cur_size >= cur_allocated - 1) {
                        cur_allocated *= 2;
                        atms = (s_atm**) my_realloc(atms, sizeof (s_atm) * cur_allocated);
                    }
                    atms[cur_size] = vcur->vertice->neigh[i];
                    cur_size++;
                }

            }
            vcur = vcur->next;
        }

        /* Then write atoms... */

        for (i = 0; i < cur_size; i++) {
            atom = atms[i];

            write_pdb_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                    atom->res_name, atom->chain, atom->res_id,
                    atom->pdb_insert, atom->x, atom->y, atom->z,
                    atom->dA, atom->a0, atom->abpa, atom->symbol,
                    atom->charge, atom->abpa_sourrounding_prob);
        }

        fprintf(f, "TER\nEND\n");
        fclose(f);
    } else {
        if (!f) fprintf(stderr, "! The file %s could not be opened!\n", out);
        else fprintf(stderr, "! Invalid pocket to write in write_pocket_pqr !\n");
    }

    my_free(atms);
}


void write_pocket_mmcif(const char out[], s_pocket *pocket) {
    node_vertice *vcur = NULL;
    int i = 0;
    int cur_size = 0,
            cur_allocated = 10;

    s_atm **atms = (s_atm**) my_malloc(sizeof (s_atm*)*10);
    s_atm *atom = NULL;
    char tmp[250];
    FILE *f = fopen(out, "w");
    strcpy(tmp,out);
    remove_ext(tmp);
    remove_path(tmp);
    if (f && pocket) {
        fprintf(f, "data_%s\n# \n",tmp);
        fprintf(f, "loop_\n");
        fprintf(f, "_struct.pdbx_descriptor\n");
        fprintf(f, "This is a mmcif format file writen by the programm fpocket.                 \n");
        fprintf(f, "It represents the atoms contacted by the voronoi vertices of the pocket.  \n");
        fprintf(f, "                                                                           \n");
        fprintf(f, "Information about the pocket %5d:\n", pocket->v_lst->first->vertice->resid);
        fprintf(f, "0  - Pocket Score                      : %.4f\n", pocket->score);
        fprintf(f, "1  - Drug Score                        : %.4f\n", pocket->pdesc->drug_score);
        fprintf(f, "2  - Number of alpha spheres           : %5d\n", pocket->pdesc->nb_asph);
        fprintf(f, "3  - Mean alpha-sphere radius          : %.4f\n", pocket->pdesc->mean_asph_ray);
        fprintf(f, "4  - Mean alpha-sphere Solvent Acc.    : %.4f\n", pocket->pdesc->masph_sacc);
        fprintf(f, "5  - Mean B-factor of pocket residues  : %.4f\n", pocket->pdesc->flex);
        fprintf(f, "6  - Hydrophobicity Score              : %.4f\n", pocket->pdesc->hydrophobicity_score);
        fprintf(f, "7  - Polarity Score                    : %5d\n", pocket->pdesc->polarity_score);
        fprintf(f, "8  - Amino Acid based volume Score     : %.4f\n", pocket->pdesc->volume_score);
        fprintf(f, "9  - Pocket volume (Monte Carlo)       : %.4f\n", pocket->pdesc->volume);
        fprintf(f, "10  -Pocket volume (convex hull)       : %.4f\n", pocket->pdesc->convex_hull_volume);
        fprintf(f, "11 - Charge Score                      : %5d\n", pocket->pdesc->charge_score);
        fprintf(f, "12 - Local hydrophobic density Score   : %.4f\n", pocket->pdesc->mean_loc_hyd_dens);
        fprintf(f, "13 - Number of apolar alpha sphere     : %5d\n", pocket->nAlphaApol);
        fprintf(f, "14 - Proportion of apolar alpha sphere : %.4f\n", pocket->pdesc->apolar_asphere_prop);
        fprintf(f,"# \n");
        /* First get the list of atoms */
        vcur = pocket->v_lst->first;
        
        fprintf(f,"%s",atomSiteHeader);
        while (vcur) {
            for (i = 0; i < 4; i++) {
                if (!is_in_lst_atm(atms, cur_size, vcur->vertice->neigh[i]->id)) {
                    if (cur_size >= cur_allocated - 1) {
                        cur_allocated *= 2;
                        atms = (s_atm**) my_realloc(atms, sizeof (s_atm) * cur_allocated);
                    }
                    atms[cur_size] = vcur->vertice->neigh[i];
                    cur_size++;
                }

            }
            vcur = vcur->next;
        }

        /* Then write atoms... */

        for (i = 0; i < cur_size; i++) {
            atom = atms[i];

            write_mmcif_atom_line(f, atom->type, atom->id, atom->name, atom->pdb_aloc,
                    atom->res_name, atom->chain, atom->res_id,
                    atom->pdb_insert, atom->x, atom->y, atom->z,
                    atom->dA, atom->a0, atom->abpa, atom->symbol,
                    atom->charge, atom->abpa_sourrounding_prob);
        }

        fprintf(f, "# \n");
        fclose(f);
    } else {
        if (!f) fprintf(stderr, "! The file %s could not be opened!\n", out);
        else fprintf(stderr, "! Invalid pocket to write in write_pocket_pqr !\n");
    }

    my_free(atms);
}
