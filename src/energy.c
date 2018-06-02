#include "../headers/energy.h"
/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
static const short n_mm_atom_type = 35;

static const s_mm_atom_type_a mm_atom_type_ST[35] = {
    // Generic type VdWradius Well depth parm 99SBildn parameters
    { "C", 1.908, 0.086},
    { "C3", 1.9080, 0.1094},
    {"C4", 1.9080, 0.1094},
    {"C5", 1.9080, 0.0860},
    {"C6", 1.9080, 0.0860},
    {"H", 0.6000, 0.0157},
    {"HO", 0.0000, 0.0000},
    {"HS", 0.6000, 0.0157},
    {"HC", 1.4870, 0.0157},
    {"H1", 1.3870, 0.0157},
    {"H2", 1.2870, 0.0157},
    {"H3", 1.1870, 0.0157},
    {"HP", 1.1000, 0.0157},
    {"HA", 1.4590, 0.0150},
    {"H4", 1.4090, 0.0150},
    {"H5", 1.3590, 0.0150},
    {"HW", 0.0000, 0.0000},
    {"HZ", 1.4590, 0.0150},
    {"O", 1.6612, 0.2100},
    {"O2", 1.6612, 0.2100},
    {"OW", 1.7683, 0.1520},
    {"OH", 1.7210, 0.2104},
    {"OS", 1.6837, 0.1700},
    {"CT", 1.9080, 0.1094},
    {"N", 1.8240, 0.1700},
    {"N3", 1.8240, 0.1700},
    {"S", 2.0000, 0.2500},
    {"SH", 2.0000, 0.2500},
    {"P", 2.1000, 0.2000},
    {"F", 1.75, 0.061},
    {"Cl", 1.948, 0.265},
    {"Br", 2.22, 0.320},
    {"I", 2.35, 0.40},
    {"LP", 0.00, 0.0000},
    {"C*", 1.9080, 0.0860} //keep C* always as last element !
};

void calculate_pocket_energy_grids(c_lst_pockets *pockets, s_fparams *params, s_pdb *pdb) {
    node_pocket *cur_node_pocket = NULL;
    cur_node_pocket = pockets->first;
    int pocket_number = 1;
    char out_path[350] = "";
    char out_path_pockets[350] = "";
    FILE *f_vdw = NULL;
    FILE *f_elec = NULL;
    char pdb_code[350] = "";
    char pdb_path[350] = "";
    char final_path[350] = "";
    //char pdb_out_path[350] = "" ;
    //char info_out_path[350]="";
    //char fout[350] = "" ;
    int status;


    strcpy(pdb_code, params->pdb_path);
    extract_path(params->pdb_path, pdb_path);
    remove_ext(pdb_code);
    remove_path(pdb_code);

    if (strlen(pdb_path) > 0) sprintf(out_path, "%s/%s_out", pdb_path, pdb_code);
    else sprintf(out_path, "%s_out", pdb_code);

    //sprintf(command, "mkdir %s", out_path) ;
    status = mkdir(out_path, 0755);
    //status = system(command) ;
    sprintf(out_path_pockets, "%s/pockets", out_path);
    status = mkdir(out_path_pockets, 0755);
    //status = system(command) ;
    if(status != 0) {
            return ;
    }
    //sprintf(out_path, "%s/%s", out_path, pdb_code) ;
    //sprintf(pdb_out_path, "%s_out.pdb", out_path) ;
    while (cur_node_pocket) {
        fprintf(stdout, "Writing pocket %d grid\n", (pocket_number));
        s_pocket *p = cur_node_pocket->pocket;

        s_grid *pocket_vdw_grid = init_pocket_grid(p);
        s_grid *pocket_elec_grid = init_pocket_grid(p);

        assign_energies(pocket_elec_grid, pocket_vdw_grid, p, pdb);



        sprintf(final_path, "%s/pockets/pocket_%d_vdw.dx", out_path, pocket_number);
        f_vdw = fopen(final_path, "w");
        write_grid(pocket_vdw_grid, f_vdw);
        fclose(f_vdw);

        sprintf(final_path, "%s/pockets/pocket_%d_elec.dx", out_path, pocket_number);
        f_elec = fopen(final_path, "w");
        write_grid(pocket_elec_grid, f_elec);
        fclose(f_elec);
        cur_node_pocket = cur_node_pocket->next;
        pocket_number++;
    }

}

void write_grid(s_grid *g, FILE *f) {
    int cx, cy, cz;
    float cv;   
    /*write the header of the dx file*/
    fprintf(f, "# Data calculated by fpocket\n");
/*    fprintf(f, "# This is a standard DX file of calculated energies of placing probes into this detected binding site\n");
    fprintf(f, "# The file can be visualised using the freely available VMD software\n");
    fprintf(f, "# fpocket parameters used to create this dx file : \n");*/
    /*    fprintf(f,"# \t-m %2.f (min alpha sphere size) -M %.2f (max alpha sphere size)\n",par->fpar->asph_min_size, par->fpar->asph_max_size);
        fprintf(f,"# \t-i %d (min number of alpha spheres per pocket)\n",par->fpar->min_pock_nb_asph);
        if(par->flag_scoring) fprintf(f,"# \t-S (Map drug score to density map!)\n");*/
    fprintf(f, "object 1 class gridpositions counts %d %d %d\n", g->nx, g->ny, g->nz);
    fprintf(f, "origin %.2f %.2f %.2f\n", g->origin[0], g->origin[1], g->origin[2]);
    fprintf(f, "delta %.2f 0 0\n", g->resolution);
    fprintf(f, "delta 0 %.2f 0\n", g->resolution);
    fprintf(f, "delta 0 0 %.2f\n", g->resolution);
    fprintf(f, "object 2 class gridconnections counts %d %d %d\n", g->nx, g->ny, g->nz);
    fprintf(f, "object 3 class array type double rank 0 items %d data follows\n", g->nx * g->ny * g->nz);
    int i = 0;
    for (cx = 0; cx < g->nx; cx++) {
        for (cy = 0; cy < g->ny; cy++) {
            for (cz = 0; cz < g->nz; cz++) {
                if (i == 3) {
                    i = 0;
                    fprintf(f, "\n");
                }
                cv = g->gridvalues[cx][cy][cz];
                fprintf(f, "%.3f ", cv);

                i++;
            }
        }
    }

}

void assign_energies(s_grid *g_elec, s_grid *g_vdw, s_pocket *p, s_pdb *pdb) {
    int cx, cy, cz;
    s_atm **atom_ids = (s_atm **) my_malloc(sizeof (s_atm *) * MAX_NUMBER_ATOMS_NEAR);
    int n_atoms;
    float cartesian_position[3];
    for (cx = 0; cx < g_elec->nx; cx++) {
        printf("x = %d out of %d\n", cx, g_elec->nx);
        for (cy = 0; cy < g_elec->ny; cy++) {
            for (cz = 0; cz < g_elec->nz; cz++) {
                n_atoms = 0;
                cartesian_position[0] = g_elec->origin[0] + cx * g_elec->resolution;
                cartesian_position[1] = g_elec->origin[1] + cy * g_elec->resolution;
                cartesian_position[2] = g_elec->origin[2] + cz * g_elec->resolution;
                                //get_atoms_contacted_by_vertices_overlapping_with_grid_point(cartesian_position, p, &(n_atoms), atom_ids);
                get_atoms_in_near_grid_points(cartesian_position, pdb->grid, &(n_atoms), atom_ids);
                //                set_energies_to_grid_point(cx, cy, cz, pdb->latoms_p, pdb->natoms, g_elec, g_vdw);
                set_energies_to_grid_point(cx, cy, cz, atom_ids, n_atoms, g_elec, g_vdw);

            }
        }
    }

    if (p->v_lst) {
        node_vertice *cur_vert = p->v_lst->first;

        while (cur_vert) { /*loop over all vertices*/
            set_alpha_sphere_electrostatic_energy(cur_vert->vertice, g_elec);

            cur_vert = cur_vert->next;
        }
    }

    return ;
}

void set_alpha_sphere_electrostatic_energy(s_vvertice *v, s_grid *g_elec) {
    float vx, vy, vz;
    int gx, gy, gz;
    vx = v->x;
    vy = v->y;
    vz = v->z;

    gx = (int) ((vx - g_elec->origin[0]) / g_elec->resolution + 0.5);
    gy = (int) ((vy - g_elec->origin[1]) / g_elec->resolution + 0.5);
    gz = (int) ((vz - g_elec->origin[2]) / g_elec->resolution + 0.5);
    
    if (gx < g_elec->nx && gy < g_elec->ny && gz < g_elec->nz && gx>=0 && gy>=0 && gz>=0) v->electrostatic_energy = g_elec->gridvalues[gx][gy][gz];
}

//short get_ff_type(char *atom_type){
//    int i;
//    for(i=0;i<n_mm_atom_type;i++){
//        
//        if(strcmp(atom_type,mm_atom_type_ST[i].name)==0){
//            return(i);
//        }
//        
//    }
//    if(atom_type[0]=='C') return(n_mm_atom_type-1);
//    return(-1);
//}

void set_energies_to_grid_point(int cx, int cy, int cz, s_atm **atom_ids, int n_atoms, s_grid *g_elec, s_grid *g_vdw) {
    short i;
    float d = 0.0;
    float sigma = 0.0;
    float epsilon = 0.0;
    float x = g_elec->origin[0] + g_elec->resolution*cx;
    float y = g_elec->origin[1] + g_elec->resolution*cy;
    float z = g_elec->origin[2] + g_elec->resolution*cz;
    double kb=0.0019872041;
    float T=310;
    float curVdw=0.0;
    float curElec=0.0;
    //g_vdw->gridvalues[cx][cy][cz] = 0.0;
    //g_elec->gridvalues[cx][cy][cz] = 0.0;
    float charge;
    float eps=78.4; //dielectric constant
    float A=-8.5525;
    float l=0.003627;
    float k=7.7839;
    float B=eps-A;

    
    
    for (i = 0; i < n_atoms; i++) {

        //atype = atom_ids[i]->mm_type;

        //        printf("%s %s %d\n",atom_ids[i]->symbol,atom_ids[i]->ff_type,ff_type);
        if (atom_ids[i]->ff_well_depth_set == 1) {
//            printf("here\n");
            charge = atom_ids[i]->ff_charge / 18.2223; //get_receptor_atom_charge(atom_ids[i]);
            d = dist(x, y, z, atom_ids[i]->x, atom_ids[i]->y, atom_ids[i]->z);
            if (d < 1.4) {
                g_vdw->gridvalues[cx][cy][cz] += 100.0; //try with 0 in case of MD here??
                g_elec->gridvalues[cx][cy][cz] += 0.0;
                return;
            } else {

                sigma = sqrt((atom_ids[i]->ff_radius + 1.4) * mm_atom_type_ST[n_mm_atom_type - 1].radius); //by default compare to carbon as probe on the grid
                epsilon = sqrt(atom_ids[i]->ff_well_depth * mm_atom_type_ST[0].w);
                //printf("%f %f %f %f \n",atom_ids[i]->ff_radius,mm_atom_type_ST[n_mm_atom_type-1].radius,sigma,epsilon);
                //if(4.0 * epsilon * (pow(sigma / d, 12) - pow(sigma / d, 6))<0) printf("vdw < 0 : %f\n",4.0 * epsilon * (pow(sigma / d, 12) - pow(sigma / d, 6)));
                curVdw=4.0 * epsilon * (pow(sigma / d, 12) - pow(sigma / d, 6));
                curElec=charge/(d*(A+B/(1.0+k*exp(-l*B*d))));
                g_vdw->gridvalues[cx][cy][cz] += exp(-curVdw/(kb*T))*curVdw;
                if (charge != 0.0 && d < 8.5) {
                    g_elec->gridvalues[cx][cy][cz] +=exp(-curElec/(kb*T))*curElec;
                }

            }
        } else {
            
            fprintf(stderr, "%s %s %d: no well depth parameter found, check if PDB and topology correspond\n",atom_ids[i]->symbol,atom_ids[i]->res_name,atom_ids[i]->res_id);
        }
    }
//    if (!cntflag || g_vdw->gridvalues[cx][cy][cz] > 900.0) {
//        g_vdw->gridvalues[cx][cy][cz] = 1000.0;
//        g_elec->gridvalues[cx][cy][cz] = 0.0;
//    }
    return;
}

void assign_mean_energies(s_grid *g,int devider){
    int x,y,z;
    for(x=0;x<g->nx;x++){
        for(y=0;y<g->ny; y++){
            for(z=0;z<g->nz;z++){
                g->gridvalues[x][y][z]/=devider;
            }
        }
    }
}

void get_atoms_in_near_grid_points(float pos[3], s_pdb_grid *g, int *n_atoms, s_atm **atom_ids) {
    int xidx, yidx, zidx;

    int sxidx, syidx, szidx; /*indices nearby xidx,yidx,zidx that are within M_MDP_CUBE_SIDE of this point*/
    int sxi = 0, syi = 0, szi = 0;
    int s = 1;
    xidx = (int) roundf((pos[0] - g->origin[0]) / g->resolution); /*calculate the nearest grid point internal coordinates*/
    yidx = (int) roundf((pos[1] - g->origin[1]) / g->resolution);
    zidx = (int) roundf((pos[2] - g->origin[2]) / g->resolution);

    add_atom_ids_from_grid_point(atom_ids, n_atoms, g->atom_ptr[xidx][yidx][zidx].latoms, g->atom_ptr[xidx][yidx][zidx].natoms);
    
    /*if (xidx > 1 && xidx < (g->nx - 1)) add_atom_ids_from_grid_point(atom_ids, n_atoms, g->atom_ptr[xidx + 1][yidx][zidx].latoms, g->atom_ptr[xidx + 1][yidx][zidx].natoms);
    if (yidx > 1 && yidx < (g->ny - 1)) add_atom_ids_from_grid_point(atom_ids, n_atoms, g->atom_ptr[xidx][yidx + 1][zidx].latoms, g->atom_ptr[xidx][yidx + 1][zidx].natoms);
    if (zidx > 1 && zidx < (g->nz - 1)) add_atom_ids_from_grid_point(atom_ids, n_atoms, g->atom_ptr[xidx][yidx][zidx + 1].latoms, g->atom_ptr[xidx][yidx][zidx + 1].natoms);
    //return(NULL);*/

    for (sxi = -s; sxi <= s; sxi++) {
        for (syi = -s; syi <= s; syi++) {
            for (szi = -s; szi <= s; szi++) {
                /*check if we are not on the point xidx,yidx, zidx....the square sum is just a little trick*/
                if ((sxi * sxi + syi * syi + szi * szi) != 0) {
                    /*next we have to check in a discrete manner if we can include a new grid point or not.*/
                    if (sxi < 0) sxidx = (int) ceil(((float) sxi + pos[0] - g->origin[0]) / g->resolution);
                    else if (sxi > 0) sxidx = (int) floor(((float) sxi + pos[0] - g->origin[0]) / g->resolution);
                    else if (sxi == 0) sxidx = xidx;
                    if (syi < 0) syidx = (int) ceil(((float) syi + pos[1] - g->origin[1]) / g->resolution);
                    else if (syi > 0) syidx = (int) floor(((float) syi + pos[1] - g->origin[1]) / g->resolution);
                    else if (syi == 0) syidx = yidx;
                    if (szi < 0) szidx = (int) ceil(((float) szi + pos[2] - g->origin[2]) / g->resolution);
                    else if (szi > 0) szidx = (int) floor(((float) szi + pos[2] - g->origin[2]) / g->resolution);
                    else if (szi == 0) szidx = zidx;
                    /*double check if we are not on the already incremented grid point*/
                    if (((sxidx != xidx) || (syidx != yidx) || (szidx != zidx))
                            && (sxidx >= 0 && syidx >= 0 && szidx >= 0 && sxidx < (g->nx-1) && syidx < (g->ny-1) && szidx < (g->nz-1))) {
                        add_atom_ids_from_grid_point(atom_ids, n_atoms, g->atom_ptr[sxidx][syidx][szidx].latoms, g->atom_ptr[sxidx][syidx][szidx].natoms);

                    } /*added condition if grid value already set, do not update, to better density measurements and match drug score*/
                }
            }
        }
    }

}

void get_atoms_contacted_by_vertices_overlapping_with_grid_point(float pos[3], s_pocket *p, int *n_atoms, s_atm **atom_ids) {
    if (p->v_lst) {
        node_vertice *cur_vert = p->v_lst->first;
        while (cur_vert) { /*loop over all vertices*/
            if (grid_point_overlaps_with_alpha_sphere(pos, cur_vert->vertice)) {
                add_atom_ids_not_in_list(atom_ids, n_atoms, cur_vert->vertice);
            }
            cur_vert = cur_vert->next;
        }
    }
}

unsigned short grid_point_overlaps_with_alpha_sphere(float pos[3], s_vvertice * vert) {
    if (ddist(pos[0], pos[1], pos[2], vert->x, vert->y, vert->z) <= vert->ray * vert->ray + TINY_SPACING) return (1);
    return (0);

}

void add_atom_ids_from_grid_point(s_atm **atom_ids, int *n_atoms, s_atm **atoms_in_grid_point, int n_atoms_in_gridpoint) {
    int j;
    for (j = 0; j < n_atoms_in_gridpoint; j++) {
        atom_ids[*n_atoms] = atoms_in_grid_point[j];
        *n_atoms = *n_atoms + 1;
    }
}

void add_atom_ids_not_in_list(s_atm **atom_ids, int *n_atoms, s_vvertice * v) {
    int i, j;
    unsigned short flag;
    if (v) {
        for (j = 0; j < 4; j++) {
            flag = 0;
            for (i = 0; i<*n_atoms && !flag; i++) {
                //fprintf(stdout,"%d %d %d %d\n",j,i,atom_ids[i],*n_atoms);
                //fflush(stdout);
                if (atom_ids[i] == v->neigh[j]) flag = 1;
            }
            if (!flag) {//v->neigh[j]->mm_type>-1) {
                //fprintf(stdout,"%d %f\n",*n_atoms,v->neigh[j]->charge);
                atom_ids[*n_atoms] = v->neigh[j];
                *n_atoms = *n_atoms + 1;
            }
        }
    }
}

s_grid * init_pocket_grid(s_pocket * p) {

    s_grid *g = (s_grid *) my_malloc(sizeof (s_grid));

    s_min_max_pocket *mm = float_get_min_max_from_pocket(p);

    float xmax = mm->maxx;
    float ymax = mm->maxy;
    float zmax = mm->maxz;
    float xmin = mm->minx;
    float ymin = mm->miny;
    float zmin = mm->minz;
    float initvalue = -0.001;
    my_free(mm);
    int cx, cy, cz;

    g->resolution = G_GRID_RESOLUTION;

    g->nx = 1 + (int) (xmax - xmin) / (g->resolution);
    g->ny = 1 + (int) (ymax - ymin) / (g->resolution);
    g->nz = 1 + (int) (zmax - zmin) / (g->resolution);

    
    g->gridvalues = (float ***) malloc(sizeof (float **) * g->nx);
    for (cx = 0; cx < g->nx; cx++) {
        g->gridvalues[cx] = (float **) malloc(sizeof (float *) * g->ny);
        for (cy = 0; cy < g->ny; cy++) {
            g->gridvalues[cx][cy] = (float *) malloc(sizeof (float) * g->nz);
            for (cz = 0; cz < g->nz; cz++) {
                g->gridvalues[cx][cy][cz] = initvalue;

            }
        }
    }

    g->origin = (float *) malloc(sizeof (float) *3);

    g->origin[0] = xmin;
    g->origin[1] = ymin;
    g->origin[2] = zmin;


    return (g);

}

/**
   ## FUNCTION:
        float_get_min_max_from_pocket

   ## SPECIFICATION:
        Get the absolute minimum and maximum point from pocket

   ## PARAMETRES:
        @ s_pocket *pocket : Pointer to pocket structure

   ## RETURN:
        @ s_min_max_pocket : Structure containing the minimum & maximum

 */
s_min_max_pocket * float_get_min_max_from_pocket(s_pocket * pocket) {
    if (pocket) {
        float minx = 50000., maxx = -50000., miny = 50000., maxy = -50000., minz = 50000., maxz = -50000.;
        node_vertice *cur_vert = pocket->v_lst->first;
        /*if there a no vertices in m before, first allocate some space*/
        while (cur_vert) { /*loop over all vertices*/
            /*store the positions and radius of the vertices*/
            if (minx > cur_vert->vertice->x - cur_vert->vertice->ray) minx = cur_vert->vertice->x - cur_vert->vertice->ray;
            else if (maxx < cur_vert->vertice->x + cur_vert->vertice->ray)maxx = cur_vert->vertice->x + cur_vert->vertice->ray;
            if (miny > cur_vert->vertice->y - cur_vert->vertice->ray) miny = cur_vert->vertice->y - cur_vert->vertice->ray;
            else if (maxy < cur_vert->vertice->y + cur_vert->vertice->ray)maxy = cur_vert->vertice->y + cur_vert->vertice->ray;
            if (minz > cur_vert->vertice->z - cur_vert->vertice->ray) minz = cur_vert->vertice->z - cur_vert->vertice->ray;
            else if (maxz < cur_vert->vertice->z + cur_vert->vertice->ray)maxz = cur_vert->vertice->z + cur_vert->vertice->ray;
            cur_vert = cur_vert->next;
        }
        s_min_max_pocket *r = (s_min_max_pocket *) my_malloc(sizeof (s_min_max_pocket));
        r->maxx = maxx;
        r->maxy = maxy;
        r->maxz = maxz;
        r->minx = minx;
        r->miny = miny;
        r->minz = minz;
        return (r);
    }
    return (NULL);
}



