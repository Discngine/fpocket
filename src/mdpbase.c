#include "../headers/mdpbase.h"
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
## FILE 					mdpbase.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			04-06-10
##
## SPECIFICATIONS
##
##	Basic functions for handling & initializing mdpocket grids
##
## MODIFICATIONS HISTORY
##
##      07-06-10        (p)  Added the header & copyright + comments
##	01-01-08	(vp) Created (random date...)
##
## TODO or SUGGESTIONS
##
 */

/**
   ## FUNCTION:
        store_vertice_positions

   ## SPECIFICATION:
        Store vertice positions of current pockets in the mdconcat structure

   ## PARAMETRES:
        @ s_mdconcat *m: Pointer to the mdconcat structure (vertices),
        @ c_lst_pockets *pockets : Pointer to all pockets found by fpocket

   ## RETURN:
        void

 */
void store_vertice_positions(s_mdconcat *m, c_lst_pockets *pockets) {
    if (pockets) {
        int z;
        int n = pockets->vertices->nvert;
        size_t old_n = m->n_vertpos;
        /*if there a no vertices in m before, first allocate some space*/
        if (m->n_vertpos == 0) alloc_first_md_concat(m, n);
        else realloc_md_concat(m, n); /*else, reallocate the object size*/
        for (z = 0; z < n; z++) { /*loop over all vertices*/
            /*store the positions and radius of the vertices*/
            m->vertpos[old_n + z][0] = pockets->vertices->vertices[z].x;
            m->vertpos[old_n + z][1] = pockets->vertices->vertices[z].y;
            m->vertpos[old_n + z][2] = pockets->vertices->vertices[z].z;
            m->vertpos[old_n + z][3] = pockets->vertices->vertices[z].ray;
        }
    }
}

void writeAlphaSpheresToFile(FILE *f,c_lst_pockets *pockets){
    float vx, vy, vz;
    node_pocket *cp = NULL;
    s_pocket *pocket = NULL;
    node_vertice *cnv = NULL;
    s_vvertice *cv = NULL;
    /*loop over all known vertices and CALCULATE the grid positions and increment grid values by 1*/
    /*important : no distance calculations are done here, thus this routine is very fast*/
    cp = pockets->first;
    int np=0;
    while (cp && np<1) { /*loop over pockets*/
        pocket = cp->pocket;
        cnv = pocket->v_lst->first;
        /*if(par->flag_scoring) incre=pocket->score;*/
        while (cnv) { /*loop over all vertices of a pocket*/
            cv = cnv->vertice;
            vx = cv->x; /*tmp the vertice position*/
            vy = cv->y;
            vz = cv->z;
            fprintf(f,"C %.3f %.3f %.3f\n",vx,vy,vz);
            cnv = cnv->next;
        }
        np++;
        cp = cp->next;
    }
}

/**
   ## FUNCTION:
        calculate_md_dens_grid

   ## SPECIFICATION:
        Do the actual grid calculation (count number of vertices near a grid point)
        NOT USED ANYMORE
   ## PARAMETRES:
        @ s_mdgrid *g: Grid structure
        @ c_lst_pockets *pockets : Pocket chained list
        @ s_mdparams *par : Parameters of mdpocket

   ## RETURN:
        void

 */
void calculate_md_dens_grid(s_mdgrid *g, c_lst_pockets *pockets, s_mdparams *par) {
    int xidx = 0, yidx = 0, zidx = 0; /*direct indices of the positions in the grid*/
    int sxidx, syidx, szidx; /*indices nearby xidx,yidx,zidx that are within M_MDP_CUBE_SIDE of this point*/
    int sxi = 0, syi = 0, szi = 0;
    float vx, vy, vz;
    float incre = 1.0;
    node_pocket *cp = NULL;
    s_pocket *pocket = NULL;
    node_vertice *cnv = NULL;
    s_vvertice *cv = NULL;
    int s = (int) (((float) M_MDP_CUBE_SIDE / 2.0) / g->resolution); /*possible stepsize (resolution dependent) in the discrete grid*/
    /*loop over all known vertices and CALCULATE the grid positions and increment grid values by 1*/
    /*important : no distance calculations are done here, thus this routine is very fast*/
    cp = pockets->first;
    while (cp) { /*loop over pockets*/
        pocket = cp->pocket;
        cnv = pocket->v_lst->first;
        /*if(par->flag_scoring) incre=pocket->score;*/
        if (par->flag_scoring) incre = pocket->pdesc->drug_score; /*if we score by drug score, use it as increment here instead of the 1 by default*/
        while (cnv) { /*loop over all vertices of a pocket*/
            cv = cnv->vertice;
            vx = cv->x; /*tmp the vertice position*/
            vy = cv->y;
            vz = cv->z;
            xidx = (int) roundf((vx - g->origin[0]) / g->resolution); /*calculate the nearest grid point internal coordinates*/
            yidx = (int) roundf((vy - g->origin[1]) / g->resolution);
            zidx = (int) roundf((vz - g->origin[2]) / g->resolution);
            /*we use a cube of M_MDP_CUBE_SIDE**3 volume to check if there are grid points nearby,
             *thus a check in the neighbourhood is performed here...this looks a bit awful and should be changed later on*/
            for (sxi = -s; sxi <= s; sxi++) {
                for (syi = -s; syi <= s; syi++) {
                    for (szi = -s; szi <= s; szi++) {
                        /*check if we are not on the point xidx,yidx, zidx....the square sum is just a little trick*/
                        if ((sxi * sxi + syi * syi + szi * szi) != 0) {
                            /*next we have to check in a discrete manner if we can include a new grid point or not.*/
                            if (sxi < 0) sxidx = (int) ceil(((float) sxi + vx - g->origin[0]) / g->resolution);
                            else if (sxi > 0) sxidx = (int) floor(((float) sxi + vx - g->origin[0]) / g->resolution);
                            else if (sxi == 0) sxidx = xidx;
                            if (syi < 0) syidx = (int) ceil(((float) syi + vy - g->origin[1]) / g->resolution);
                            else if (syi > 0) syidx = (int) floor(((float) syi + vy - g->origin[1]) / g->resolution);
                            else if (syi == 0) syidx = yidx;
                            if (szi < 0) szidx = (int) ceil(((float) szi + vz - g->origin[2]) / g->resolution);
                            else if (szi > 0) szidx = (int) floor(((float) szi + vz - g->origin[2]) / g->resolution);
                            else if (szi == 0) szidx = zidx;
                            /*TODO : double check if we are not on the already incremented grid point this is incomplete, fix please!!!*/
                            if (((sxidx != xidx) || (syidx != yidx) || (szidx != zidx))
                                    && (sxidx >= 0 && syidx >= 0 && szidx >= 0 && sxidx < g->nx && syidx < g->ny && szidx < g->nz)) {
                                g->gridvalues[sxidx][syidx][szidx] += incre;
                            } /*added condition if grid value already set, do not update, to better density measurements and match drug score*/
                        }
                    }
                }
            }
            cnv = cnv->next;
        }

        if (xidx < g->nx && yidx < g->ny && zidx < g->nz && xidx >= 0 && yidx >= 0 && zidx >= 0) {

            g->gridvalues[xidx][yidx][zidx] += incre; /*increment the already known grid point value*/

        } else fprintf(stderr, "\n\nWarning (oh oh!!) : Your structure is not aligned or is moving a lot. Results might not reflect what you expect. Consider first structural alignemnt\nIf your structure is moving a lot, consider to split up analysis in two distinct parts.\n\n");
        cp = cp->next;
    }
}

/**
   ## FUNCTION:
        update_md_dens_grid

   ## SPECIFICATION:
        Do the actual grid calculation (count number of vertices near a grid point)

   ## PARAMETRES:
        @ s_mdgrid *g: Grid structure
        @ c_lst_pockets *pockets : Pocket chained list
        @ s_mdparams *par : Parameters of mdpocket
   ## RETURN:
        void

 */
void update_md_grid(s_mdgrid *g, s_mdgrid *refg, c_lst_pockets *pockets, s_mdparams *par) {
    int xidx = 0, yidx = 0, zidx = 0; /*direct indices of the positions in the grid*/
    int sxidx = 0, syidx = 0, szidx = 0; /*indices nearby xidx,yidx,zidx that are within M_MDP_CUBE_SIDE of this point*/
    int sxi = 0, syi = 0, szi = 0;
    float vx, vy, vz;
    float incre = 1.0;
    node_pocket *cp = NULL;
    s_pocket *pocket = NULL;
    node_vertice *cnv = NULL;
    s_vvertice *cv = NULL;
    int s = (int) (((float) M_MDP_CUBE_SIDE / 2.0) / g->resolution); /*possible stepsize (resolution dependent) in the discrete grid*/
    /*loop over all known vertices and CALCULATE the grid positions and increment grid values by 1*/
    /*important : no distance calculations are done here, thus this routine is very fast*/
    cp = pockets->first;
    while (cp) { /*loop over pockets*/
        pocket = cp->pocket;
        cnv = pocket->v_lst->first;
        /*if(par->flag_scoring) incre=pocket->score;*/
        if (par->flag_scoring) incre = pocket->pdesc->drug_score;
        
        while (cnv) { /*loop over vertices*/
            cv = cnv->vertice;
            vx = cv->x; /*tmp the vertice position*/
            vy = cv->y;
            vz = cv->z;
            s=(int) (((float) cv->ray/2.0) / g->resolution);
            xidx = (int) roundf((vx - g->origin[0]) / g->resolution); /*calculate the nearest grid point internal coordinates*/
            yidx = (int) roundf((vy - g->origin[1]) / g->resolution);
            zidx = (int) roundf((vz - g->origin[2]) / g->resolution);
            /*we use a cube of M_MDP_CUBE_SIDE**3 volume to check if there are grid points nearby,
             *thus a check in the neighbourhood is performed here...this looks a bit awful and should be changed later on*/

            for (sxi = -s; sxi <= s; sxi++) {
                for (syi = -s; syi <= s; syi++) {
                    for (szi = -s; szi <= s; szi++) {
                        /*check if we are not on the point xidx,yidx, zidx....the square sum is just a little trick*/
                        if ((sxi * sxi + syi * syi + szi * szi) != 0) {
                            /*next we have to check in a discrete manner if we can include a new grid point or not.*/
                            if (sxi < 0) sxidx = (int) ceil(((float) sxi + vx - g->origin[0]) / g->resolution);
                            else if (sxi > 0) sxidx = (int) floor(((float) sxi + vx - g->origin[0]) / g->resolution);
                            else if (sxi == 0) sxidx = xidx;
                            if (syi < 0) syidx = (int) ceil(((float) syi + vy - g->origin[1]) / g->resolution);
                            else if (syi > 0) syidx = (int) floor(((float) syi + vy - g->origin[1]) / g->resolution);
                            else if (syi == 0) syidx = yidx;
                            if (szi < 0) szidx = (int) ceil(((float) szi + vz - g->origin[2]) / g->resolution);
                            else if (szi > 0) szidx = (int) floor(((float) szi + vz - g->origin[2]) / g->resolution);
                            else if (szi == 0) szidx = zidx;
                            /*double check if we are not on the already incremented grid point*/
                            if (((sxidx != xidx) || (syidx != yidx) || (szidx != zidx))
                                    && (sxidx >= 0 && syidx >= 0 && szidx >= 0 && sxidx < g->nx && syidx < g->ny && szidx < g->nz)) {
                                if (refg->gridvalues[sxidx][syidx][szidx] < 1.0) {
                                    g->gridvalues[sxidx][syidx][szidx] += incre;
                                    refg->gridvalues[sxidx][syidx][szidx] = 1.0;

                                }
                            } /*added condition if grid value already set, do not update, to better density measurements and match drug score*/
                        }
                    }
                }
            }
            cnv = cnv->next;
        }

        if (xidx < g->nx && yidx < g->ny && zidx < g->nz && xidx >= 0 && yidx >= 0 && zidx >= 0) {
            if (refg->gridvalues[xidx][yidx][zidx] < 1.0) {
                g->gridvalues[xidx][yidx][zidx] += incre; /*increment the already known grid point value*/
                refg->gridvalues[xidx][yidx][zidx] = 1.0;
            }
        } else fprintf(stderr, "\n\nWarning (oh oh!!) : Your structure is not aligned or is moving a lot. Results might not reflect what you expect. Consider first structural alignemnt\nIf your structure is moving a lot, consider to split up analysis in two distinct parts.\n\n");
        cp = cp->next;
    }
    //return g;
}

/**
   ## FUNCTION:
        reset_grid

   ## SPECIFICATION:
        Reset all grid values to 0

   ## PARAMETRES:
        @ s_mdgrid *g: Grid structure
   ## RETURN:
        void

 */
void reset_grid(s_mdgrid *g) {
    int x, y, z;
    for (x = 0; x < g->nx; x++) {
        for (y = 0; y < g->ny; y++) {
            for (z = 0; z < g->nz; z++) {
                g->gridvalues[x][y][z] = 0.0;
            }
        }
    }
}

/**
   ## FUNCTION:
        project_grid_on_atoms

   ## SPECIFICATION:
        Project grid values to atoms to store these into the bfactor column of
        the pdb

   ## PARAMETRES:
        @ s_mdgrid *g: Grid structure
   ## RETURN:
        void

*/

void project_grid_on_atoms(s_mdgrid *g, s_pdb *pdb) {
    s_atm *ca = NULL;
    float x, y, z;
    int ix, iy, iz;
    float maxix, maxiy, maxiz;
    int i;
    float density;
    float ngridpoints1D = (float) M_MDP_ATOM_DENSITY_DIST / g->resolution;
    for (i = 0; i < pdb->natoms; i++) {/*for all protein atoms*/
        density = 0.0;
        ca = pdb->latoms_p[i];  /*set up the current atom*/
        /*get the coordinates*/
        x = ca->x;
        y = ca->y;
        z = ca->z;
        /*nearest position of the atom in x in the grid*/
        ix = (int) floor((x - M_MDP_ATOM_DENSITY_DIST - g->origin[0]) / g->resolution);

        maxix = (int) ceil((x + M_MDP_ATOM_DENSITY_DIST - g->origin[0]) / g->resolution);
        maxiy = (int) ceil((y + M_MDP_ATOM_DENSITY_DIST - g->origin[1]) / g->resolution);
        maxiz = (int) ceil((z + M_MDP_ATOM_DENSITY_DIST - g->origin[2]) / g->resolution);
        while (ix <= maxix && g->nx > ix && ix>=0) {
            iy = (int) floor((y - M_MDP_ATOM_DENSITY_DIST - g->origin[1]) / g->resolution);
            while (iy <= maxiy && g->ny > iy && iy>=0) {
                iz = (int) floor((z - M_MDP_ATOM_DENSITY_DIST - g->origin[2]) / g->resolution);
                while (iz <= maxiz && g->nz > iz && iz>=0) {
                    density += g->gridvalues[ix][iy][iz];
                    iz++;
                }
                iy++;
            }
            ix++;
        }
        /*transform the density to something more contrasted for the bfactor column*/
        ca->bfactor = log(1 + density / (ngridpoints1D) / (float) g->n_snapshots);
    }
}


/**
   ## FUNCTION:
        normalize_grid

   ## SPECIFICATION:
        Normalize all grid values by the number of snapshots

   ## PARAMETRES:
        @ s_mdgrid *g: Grid structure
        @ int n : Number of snapshots
   ## RETURN:
        void

 */
void normalize_grid(s_mdgrid *g, int n) {
    int x, y, z;
    for (x = 0; x < g->nx; x++) {
        for (y = 0; y < g->ny; y++) {
            for (z = 0; z < g->nz; z++) {
                g->gridvalues[x][y][z] /= (float) n;
            }
        }
    }
}

/**
   ## FUNCTION:
        init_md_concat

   ## SPECIFICATION:
        Initialize the md concat (alloc)

   ## PARAMETRES:
        void

   ## RETURN:
        s_mdconcat * : the md concat structure

 */

s_mdconcat *init_md_concat(void) {
    s_mdconcat *m = (s_mdconcat *) my_malloc(sizeof (s_mdconcat));
    m->n_vertpos = 0;
    m->vertpos = NULL;
    m->n_snapshots = 0;
    return m;
}


/**
   ## FUNCTION:
        float_get_min_max_from_pockets

   ## SPECIFICATION:
        Get the absolute minimum and maximum point from pockets

   ## PARAMETRES:
        @ c_lst_pockets *pockets : Chained list of pockets

   ## RETURN:
        @ s_min_max_pockets : Structure containing the minimum & maximum

*/
s_min_max_pockets *float_get_min_max_from_pockets(c_lst_pockets *pockets) {
    if (pockets) {
        int z;
        float minx = 50000., maxx = -50000., miny = 50000., maxy = -50000., minz = 50000., maxz = -50000.;
        int n = pockets->vertices->nvert;
        /*if there a no vertices in m before, first allocate some space*/
        for (z = 0; z < n; z++) { /*loop over all vertices*/
            /*store the positions and radius of the vertices*/
            if (minx > pockets->vertices->vertices[z].x) minx = pockets->vertices->vertices[z].x;
            else if (maxx < pockets->vertices->vertices[z].x)maxx = pockets->vertices->vertices[z].x;
            if (miny > pockets->vertices->vertices[z].y) miny = pockets->vertices->vertices[z].y;
            else if (maxy < pockets->vertices->vertices[z].y)maxy = pockets->vertices->vertices[z].y;
            if (minz > pockets->vertices->vertices[z].z) minz = pockets->vertices->vertices[z].z;
            else if (maxz < pockets->vertices->vertices[z].z)maxz = pockets->vertices->vertices[z].z;
        }
        s_min_max_pockets *r = (s_min_max_pockets *) my_malloc(sizeof (s_min_max_pockets));
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

/**
   ## FUNCTION:
        init_md_grid

   ## SPECIFICATION:
        Initialize the md grid (allocate + 0)

   ## PARAMETRES:
        @ s_mdconcat *mdc: Pointer to the mdconcat structure (vertices),

   ## RETURN:
        s_mdgrid * : the grid

 */
s_mdgrid *init_md_grid(c_lst_pockets *pockets,s_mdparams *par) {
    s_mdgrid *g = (s_mdgrid *) malloc(sizeof (s_mdgrid));
    
    float resolution=M_MDP_GRID_RESOLUTION;
    s_min_max_pockets *mm;
    
    if(grid_user_data_missing(par)){
        mm= float_get_min_max_from_pockets(pockets);
    }
    else {
        mm = assign_min_max_from_user_input(par);
    }
    float xmax = mm->maxx;
    float ymax = mm->maxy;
    float zmax = mm->maxz;
    float xmin = mm->minx;
    float ymin = mm->miny;
    float zmin = mm->minz;
    float initvalue = 0.0;
    my_free(mm);
    int cx, cy, cz;
    if(par->grid_spacing>0.0){
        resolution=par->grid_spacing;
    }
    float span;
    if(grid_user_data_missing(par))span=(M_MDP_CUBE_SIDE / 2.0); /** / resolution;*/
    else span=0.0;
    
    g->resolution = resolution;

    if(grid_user_data_missing(par)){
        g->nx = 1 + (int) (xmax + 30. * span - xmin) / (g->resolution);
        g->ny = 1 + (int) (ymax + 30. * span - ymin) / (g->resolution);
        g->nz = 1 + (int) (zmax + 30. * span - zmin) / (g->resolution);
    } else {
        g->nx=par->grid_extent[0];
        g->ny=par->grid_extent[1];
        g->nz=par->grid_extent[2];
    }

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
    
    g->origin[0] = xmin - 15. * span;
    g->origin[1] = ymin - 15. * span;
    g->origin[2] = zmin - 15. * span;
    
        
    return g;
}


s_min_max_pockets *assign_min_max_from_user_input(s_mdparams *par){
        s_min_max_pockets *r = (s_min_max_pockets *) my_malloc(sizeof (s_min_max_pockets));
        float spacing;
        if(par->grid_spacing>0.0){
            spacing=par->grid_spacing;
        }
        else spacing=M_MDP_GRID_RESOLUTION;
        r->minx=par->grid_origin[0];
        r->miny=par->grid_origin[1];
        r->minz=par->grid_origin[2];
        r->maxx=par->grid_origin[0]+spacing*par->grid_extent[0];
        r->maxy=par->grid_origin[1]+spacing*par->grid_extent[1];
        r->maxz=par->grid_origin[2]+spacing*par->grid_extent[2];
        return(r);
}


/**
   ## FUNCTION:
        alloc_first_md_concat

   ## SPECIFICATION:
        Allocate memory for the md concat structure (first snapshot)

   ## PARAMETRES:
        @ s_mdconcat *m: Pointer to the structure to free,
        @ size_t n: Number of vertices in the snapshot to add to m

   ## RETURN:
        void
*/
void alloc_first_md_concat(s_mdconcat *m, size_t n) {
    size_t z;
    m->vertpos = (float **) my_malloc(sizeof (float *) * n);
    for (z = 0; z < n; z++) {
        m->vertpos[z] = (float *) my_malloc(sizeof (float) *4);
        m->vertpos[z][0] = 0.0;
        m->vertpos[z][1] = 0.0;
        m->vertpos[z][2] = 0.0;
        m->vertpos[z][3] = 0.0;
    }
    m->n_vertpos = n;
}

/**
   ## FUNCTION:
        realloc_md_concat

   ## SPECIFICATION:
        Reallocate memory for the md concat structure (to add a new snapshot)

   ## PARAMETRES:
        @ s_mdconcat *m: Pointer to the structure to free,
        @ size_t n: Number of vertices in the snapshot to add to m

   ## RETURN:
        void

 */
void realloc_md_concat(s_mdconcat *m, size_t n) {
    size_t z;
    m->vertpos = (float **) my_realloc(m->vertpos, sizeof (float *) *(m->n_vertpos + n));
    for (z = 0; z < n; z++) {
        m->vertpos[m->n_vertpos + z] = (float *) my_malloc(sizeof (float) *4);
        m->vertpos[m->n_vertpos + z][0] = 0.0;
        m->vertpos[m->n_vertpos + z][1] = 0.0;
        m->vertpos[m->n_vertpos + z][2] = 0.0;
        m->vertpos[m->n_vertpos + z][3] = 0.0;
    }
    m->n_vertpos += n;
}

/**
   ## FUNCTION:
        free_mdconcat

   ## SPECIFICATION:
        Free the mdconcat structure

   ## PARAMETRES:
        @ s_mdconcat *m: Pointer to the structure to free

   ## RETURN:
        void

 */
void free_mdconcat(s_mdconcat *m) {
    size_t i;
    for (i = 0; i < m->n_vertpos; i++) {
        my_free(m->vertpos[i]);
    }
    my_free(m->vertpos);
    my_free(m);
}


void free_md_grid(s_mdgrid *g){
    int cx,cy;
    
    for (cx = g->nx-1; cx >=0; cx--) {
        for (cy = g->ny-1; cy >=0; cy--) {
                free(g->gridvalues[cx][cy]);
        }
    }
    for (cx = g->nx-1; cx >=0; cx--) {
        free(g->gridvalues[cx]);
    }
    
    free(g->gridvalues);

}



