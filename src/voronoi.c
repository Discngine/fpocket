
#include "../headers/voronoi.h"
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
## FILE 					voronoi.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED                		02-12-08
##
## SPECIFICATIONS
##
##  Functions dealing with input/output of qhull: we will send to qhull a set
##  of points (basically all atoms of the system), and qhull will send back all
##  voronoi vertices positions. Everything will then be parsed properly for
##  future use.
##
## MODIFICATIONS HISTORY
##
##      01-12-12        (p)  Novel qvoronoi options & convex hull volume calculations
##      28-10-12        (P)  Introducing replicas of voronoi vertice tesselation
##	04-11-10	(v)  Fixed minor indexing bug, name of qvoronoi tmp files changed
##	02-12-08	(v)  Comments UTD
##	01-04-08	(v)  Added template for comments and creation of history
##	21-02-08	(p)  Adding support for proteins with hydrogens
##	01-01-08	(vp) Created (random date...)
##
## TODO or SUGGESTIONS
##

 */



double frand_a_b(double a, double b) {
    return ( rand() / (double) RAND_MAX) * (b - a) + a;
}

/**
   ## FUNCTION:
    s_lst_vvertice
  
   ## SPECIFICATION:
    Calculate voronoi vertices using an ensemble of atoms, and then load resulting
    vertices into a s_lst_vvertice structure. The function call an external
    programm qvoronoi, part of qhull programme which can be download at:
        http://www.qhull.org/download/
    or installed with apt-get install qhull-bin
  
   ## PARAMETRES:
    @ s_pdb *pdb          : PDB informations
    @ int min_apol_neigh  : Number of apolar neighbor of a vertice to be
                            considered as apolar
    @ float asph_min_size : Minimum size of voronoi vertices to retain
    @ float asph_max_size : Maximum size of voronoi vertices to retain
  
   ## RETURN:
    s_lst_vvertice * :The structure containing the list of vertices.
  
 */
s_lst_vvertice* load_vvertices_DEPRECATED(s_pdb *pdb, int min_apol_neigh, float asph_min_size, float asph_max_size, float xshift, float yshift, float zshift) {
    int i,
            nb_h = 0;

    s_atm *ca = NULL;
    s_lst_vvertice *lvvert = NULL;

    char tmpn1[250] = "";
    char tmpn2[250] = "";

    pid_t pid = getpid();


    sprintf(tmpn1, "/tmp/qvoro_in_fpocket_%d.dat", pid);
    sprintf(tmpn2, "/tmp/qvoro_out_fpocket_%d.dat", pid);
    printf(tmpn1);

    srand(time(NULL));
    /*
        sprintf(tmpn1, "qvoro_in_fpocket_%d.dat", pid) ;
        sprintf(tmpn2, "qvoro_out_fpocket_%d.dat", pid) ;
     */

    FILE *fvoro = fopen(tmpn1, "w+");
    FILE *ftmp = fopen(tmpn2, "w");

    if (fvoro != NULL) {
        lvvert = (s_lst_vvertice *) my_malloc(sizeof (s_lst_vvertice));
        lvvert->h_tr = NULL;
        /* Loop a first time to get out how many heavy atoms are in the file */
        for (i = 0; i < pdb->natoms; i++) {
            ca = (pdb->latoms) + i;
            if (strcmp(ca->symbol, "H") != 0) {
                lvvert->h_tr = (int *) my_realloc(lvvert->h_tr, sizeof (int) *(i - nb_h + 1));
                lvvert->h_tr[i - nb_h] = i;
            } else nb_h++;
        }
        lvvert->n_h_tr = i - nb_h;

        /* Write the header for qvoronoi */
        fprintf(fvoro, "3 rbox D3\n%d\n", lvvert->n_h_tr);
        /* Loop a second time for the qvoronoi input coordinates */

        for (i = 0; i < pdb->natoms; i++) {


            ca = (pdb->latoms) + i;
            if (strcmp(ca->symbol, "H") != 0) {
                fprintf(fvoro, "%.6f %.6f %.6f\n", ca->x + xshift, ca->y + yshift, ca->z + zshift);
            }
        }

        fflush(fvoro);
        rewind(fvoro);

        //int status = system("qvoronoi p i Pp Fn < voro_tmp.dat > voro.tmp") ;
        run_qvoronoi(fvoro, ftmp);
        int status = M_VORONOI_SUCCESS;

        if (status == M_VORONOI_SUCCESS) {
            fill_vvertices(lvvert, tmpn2, pdb->latoms, pdb->natoms,
                    min_apol_neigh, asph_min_size, asph_max_size, xshift, yshift, zshift, pdb->avg_bfactor,pdb);
        } else {
            my_free(lvvert);
            lvvert = NULL;
            fprintf(stderr, "! Voronoi command failed with status %d...\n", status);
        }
    } else {
        fprintf(stderr, "! File for Voronoi vertices calculation couldn't be opened...\n");
    }
    fclose(fvoro);
    fclose(ftmp);

    //remove(tmpn1) ;
    //remove(tmpn2) ;


    return lvvert;
}

/**
   ## FUNCTION:
    
  
   ## SPECIFICATION:
    Calculate voronoi vertices using an ensemble of atoms, and then load resulting
    vertices into a s_lst_vvertice structure. The function call an external
    programm qvoronoi, part of qhull programme which can be download at:
        http://www.qhull.org/download/
    or installed with apt-get install qhull-bin
  
   ## PARAMETRES:
    @ s_pdb *pdb          : PDB informations
    @ int min_apol_neigh  : Number of apolar neighbor of a vertice to be
                            considered as apolar
    @ float asph_min_size : Minimum size of voronoi vertices to retain
    @ float asph_max_size : Maximum size of voronoi vertices to retain
  
   ## RETURN:
    s_lst_vvertice * :The structure containing the list of vertices.
  
 */
s_lst_vvertice* load_vvertices(s_pdb *pdb, int min_apol_neigh, float asph_min_size, float asph_max_size, float xshift, float yshift, float zshift) {
    int i, j,
            nb_h = 0;

    s_atm *ca = NULL;
    s_lst_vvertice *lvvert = NULL;

    char tmpn1[250] = "";
    char tmpn2[250] = "";

    pid_t pid = getpid();


    sprintf(tmpn1, "/tmp/qvoro_in_fpocket_%d.dat", pid);
    sprintf(tmpn2, "/tmp/qvoro_out_fpocket_%d.dat", pid);
//    fprintf(stdout, tmpn1);
    /*fflush(stdout);*/

    srand(time(NULL));
    /*
        sprintf(tmpn1, "qvoro_in_fpocket_%d.dat", pid) ;
        sprintf(tmpn2, "qvoro_out_fpocket_%d.dat", pid) ;
     */

    //    FILE *fvoro = fopen(tmpn1, "w+") ;


    //if (fvoro != NULL) {
    lvvert = (s_lst_vvertice *) my_malloc(sizeof (s_lst_vvertice));
    lvvert->h_tr = NULL;
    /* Loop a first time to get out how many heavy atoms are in the file */
    //        for (i = 0 ; i < pdb->natoms ; i++) {
    //            ca = (pdb->latoms) + i ;
    //        
    //            if (strcmp(ca->symbol, "H") != 0 ) {
    //
    //                lvvert->h_tr = (int *) my_realloc(lvvert->h_tr, sizeof (int) *(i - nb_h + 1)) ;
    //                lvvert->h_tr[i - nb_h] = i ;
    //            }
    //            else nb_h++ ;
    //        }
    //        
    //        lvvert->n_h_tr = i - nb_h ;
    //        
    for (i = 0; i < pdb->natoms; i++) {
        ca = (pdb->latoms) + i;

        if (strcmp(ca->symbol, "H") == 0) nb_h++;
    }

//    printf("\nfound %d H atoms\n", nb_h);

    lvvert->h_tr = (int *) my_malloc(sizeof (int) *(pdb->natoms - nb_h));

    int n_cur_heavy_atoms = 0;
    for (i = 0; i < pdb->natoms; i++) {
        ca = (pdb->latoms) + i;
        if (strcmp(ca->symbol, "H") != 0) {

            lvvert->h_tr[n_cur_heavy_atoms++] = i;
        }


    }


    lvvert->n_h_tr = pdb->natoms - nb_h;

    for (j = 0; j < M_N_REPLICAS; j++) {
        FILE *ftmp = fopen(tmpn2, "w");
        FILE *fvoro = fopen(tmpn1, "w+");
        /* Write the header for qvoronoi */
        fprintf(fvoro, "3 rbox D3\n%d\n", lvvert->n_h_tr);
        //fprintf(fvoro, "3 rbox D3\n%d\n", 100) ;
        /* Loop a second time for the qvoronoi input coordinates */
        //float fact=0.05;
        float fact = 0.05;
        xshift = fact*j;
        yshift = fact*j;
        zshift = fact*j;
        //int kk=100;
        //pdb->natoms;
        for (i = 0; i < pdb->natoms; i++) {
            //for (i = 0 ; i < 100;  i++) {
            ca = (pdb->latoms) + i;
            if (strcmp(ca->symbol, "H") != 0) {
                fprintf(fvoro, "%.6f %.6f %.6f\n", ca->x + xshift, ca->y + yshift, ca->z + zshift);
            }
        }

        fflush(fvoro);
        rewind(fvoro);

        //int status = system("qvoronoi p i Pp Fn < voro_tmp.dat > voro.tmp") ;
        run_qvoronoi(fvoro, ftmp);
        int status = M_VORONOI_SUCCESS;

        if (status == M_VORONOI_SUCCESS) {
            if (j == 0) {
                fill_vvertices(lvvert, tmpn2, pdb->latoms, pdb->natoms,
                        min_apol_neigh, asph_min_size, asph_max_size, xshift, yshift, zshift, pdb->avg_bfactor,pdb);
            } else {
                add_missing_vvertices(lvvert, tmpn2, pdb->latoms, min_apol_neigh, asph_min_size, asph_max_size, xshift, yshift, zshift, pdb->avg_bfactor,pdb);
            }

        }
//        printf("nverts : %d\n", lvvert->nvert);
        fclose(fvoro);
        fclose(ftmp);
        //else {
        //    my_free(lvvert) ;
        //   lvvert = NULL ;
        //   fprintf(stderr, "! Voronoi command failed with status %d...\n", status) ;
        //}
        //fclose(fvoro) ;
    }
    //}
    // else {
    //     fprintf(stderr, "! File for Voronoi vertices calculation couldn't be opened...\n") ;
    //}
    //fclose(fvoro) ;
    //we used a huge buffer for preallocation, now lets shrink this to something smaller
    /*TODO : fix this....valgrind says buffer write errors later on*/
//    lvvert->pvertices = (s_vvertice **) my_realloc((void *) lvvert->pvertices, sizeof (s_vvertice *) * lvvert->nvert);
    
//    lvvert->vertices = (s_vvertice *) my_realloc((void *) lvvert->vertices, sizeof (s_vvertice) * (lvvert->nvert));

    //remove(tmpn1);
    //remove(tmpn2);

    /*        FILE *tmp=open("test.xyz","w+");
            ffprintf()
            for(i=0;i<lvvert->nvert;i++){
            
            }
     */

    return lvvert;
}

double **get_3d_array_from_vvertice_list(s_lst_vvertice *lvvert) {
    int debug = 0;

    if (debug == 0) {
        double **res = (double**) my_malloc(lvvert->nvert * (sizeof (double *)));
        int i;
        for (i = 0; i < lvvert->nvert; i++) {
            res[i] = (double*) my_malloc(3 * sizeof (double));
            res[i][0] = (double) lvvert->vertices[i].x;
            res[i][1] = (double) lvvert->vertices[i].y;
            res[i][2] = (double) lvvert->vertices[i].z;

        }
        return res;
    } else {
        double **res = (double**) my_malloc(7 * (sizeof (double *)));
        int i = 0;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = 0.5;
        res[i][1] = 0.5;
        res[i][2] = 0.5;
        i = 1;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = 0.5;
        res[i][1] = 0.6;
        res[i][2] = 1.0;
        i = 2;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = 100.0;
        res[i][1] = 0.5;
        res[i][2] = 0.5;
        i = 3;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = 100.0;
        res[i][1] = 1.5;
        res[i][2] = 1.5;
        i = 4;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = -50.0;
        res[i][1] = 0.5;
        res[i][2] = 50.0;
        i = 5;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = -52.0;
        res[i][1] = 0.5;
        res[i][2] = 55.0;
        i = 6;
        res[i] = (double*) my_malloc(3 * sizeof (double));
        res[i][0] = 0.0;
        res[i][1] = 0.5;
        res[i][2] = 50.0;
        return res;
    }

}

int **get_mask(int n) {
    int **res = (int**) my_malloc(n * (sizeof (int *)));
    int i;
    for (i = 0; i < n; i++) {
        res[i] = (int*) my_malloc(3 * sizeof (int));
        res[i][0] = 1.0;
        res[i][1] = 1.0;
        res[i][2] = 1.0;

    }
    return res;
}

void transferClustersToVertices(int **clusterIds, s_lst_vvertice *lvert) {
    /*Transfer cluster Ids to vertice residue Ids which are later used for pocket clustering*/
    int nelements = lvert->nvert;
    int i;
    /*
        FILE *f=fopen("test2.tmp","w");
     */
    for (i = 0; i < nelements; i++) {
//        fprintf(stdout,"resid %p\n",lvert->pvertices[i]);
//        fflush(stdout);
        if (clusterIds[i][0] > 0) lvert->pvertices[i]->resid = clusterIds[i][1];
        /*
                fprintf(f,"%d\n",clusterIds[i][1]);
         */
    }
    /*
        fclose(f);
     */
}

s_clusterlib_vertices *prepare_vertices_for_cluster_lib(s_lst_vvertice *lvvert, char c_method, char d_method) {
    /*transform vertices to something the clusterlib can treat*/
    s_clusterlib_vertices *clusterObject = my_malloc(sizeof (s_clusterlib_vertices));
    clusterObject->pos = get_3d_array_from_vvertice_list(lvvert);
    clusterObject->mask = get_mask(lvvert->nvert);
    clusterObject->weight[0] = 1.0;
    clusterObject->weight[1] = 1.0;
    clusterObject->weight[2] = 1.0;
    clusterObject->transpose = 0; /*set a global flag here somehow*/
    /**Distance metric from command.c in clusterlib
     *Specifies the distance measure for gene clustering\n");
       u: Uncentered correlation
       c: Pearson correlation\n"
       x: Uncentered correlation, absolute value\n"
       a: Pearson correlation, absolute value\n"
       s: Spearman's rank correlation\n"
       k: Kendall's tau\n"
       e: Euclidean distance\n"
       b: City-block distance\n"

     * */
    /*
        method     (input) char
    Defines which hierarchical clustering method is used:
    method=='s': pairwise single-linkage clustering
    method=='m': pairwise maximum- (or complete-) linkage clustering
    method=='a': pairwise average-linkage clustering
    method=='c': pairwise centroid-linkage clustering
    For the first three, either the distance matrix or the gene expression data is
    sufficient to perform the clustering algorithm. For pairwise centroid-linkage
    clustering, however, the gene expression data are always needed, even if the
    distance matrix itself is available.
     */

    clusterObject->dist = d_method; /**put general flag here, but right now euclidean distance is ok*/
    clusterObject->method = c_method; /** clustering method, see doc for options, right now, average clustering*/
    return (clusterObject);
}

/*
 function to free the data structure of vertices for the clusterlib : 
 * double **res=(double**)my_malloc(lvvert->nvert*(sizeof(double *)));
        int i;
        for(i=0;i<lvvert->nvert;i++){
            res[i]=(double*) my_malloc(3*sizeof(double));
 
 */

int free_cluster_lib_vertices(s_clusterlib_vertices *clusterlib_vertices, int nvert) {
    int i;


    for (i = nvert - 1; i >= 0; i--) {
        my_free(clusterlib_vertices->pos[i]);
        my_free(clusterlib_vertices->mask[i]);
    }
    my_free(clusterlib_vertices->pos);
    my_free(clusterlib_vertices->mask);
    my_free(clusterlib_vertices);
    return (0);
}

/**
   ## FUNCTION:
    fill_vertices
  
   ## PARAMETRES:
    @ s_lst_vvertice *lvvert : The structure to fill
    @ const char fpath[]     : File containing vertices
    @ s_atm *atoms           : List of atoms
    @ int natoms             : Number of atoms
    @ int min_apol_neigh  : Number of apolar neighbor of a vertice to be
                            considered as apolar
    @ float asph_min_size : Minimum size of voronoi vertices to retain
    @ float asph_max_size : Maximum size of voronoi vertices to retain
  
   ## SPECIFICATION:
    Fill structure given in argument (must have been allocated) using a file
    containing vertice coordinates and neighbours using p i options of qhull.
  
   ## RETURN:
    void
  
 */
void fill_vvertices(s_lst_vvertice *lvvert, const char fpath[], s_atm *atoms, int natoms,
        int min_apol_neigh, float asph_min_size, float asph_max_size,
        float xshift, float yshift, float zshift, float avg_bfactor,s_pdb *pdb) {
    FILE *f = NULL; /* File handler for vertices coordinates */
    FILE *fNb = NULL; /* File handler for vertices atomic neighbours */
    /*FILE *fvNb = NULL ;  File handler for vertices vertice neighbours */

    s_vvertice *v = NULL;

    float tmpRadius; /* Temporary Ray of voronoi vertice (ray of alpha sphere) */
    float xyz[3] = {0, 0, 0};

    int i, j, nchar_max = 255,
            vInMem = 0, /* Saved vertices counter */
            tmpApolar = 0,
            curNbIdx[4]; /* Current atomic neighbours curVnbIdx[4],  Current vertice neighbours */

    char cline[nchar_max],
            nbline[nchar_max],
            *s_nvert = (char *) my_malloc(sizeof (char) *nchar_max); //vNbline[nchar_max],

    /* Once we have the number of lines, lets allocate memory and get the lines */

    f = fopen(fpath, "r");
    fNb = fopen(fpath, "r");
    //fvNb = fopen(fpath, "r") ;

    char *status = NULL;

    status = fgets(cline, nchar_max, f); /* Skip fir=st line */
    status = fgets(cline, nchar_max, f); /* Load 2nd line containing nbr of coors. */
    status = fgets(nbline, nchar_max, fNb); /* Skip first line */
    status = fgets(nbline, nchar_max, fNb); /* Load 2nd line containing nbr of coors. */
    if(!status) {
        return;
    }
    //status = fgets(vNbline, nchar_max, fvNb) ; /* Skip first line */
    //status = fgets(vNbline, nchar_max, fvNb) ; /* Load 2nd line containing nbr of coors. */

    sscanf(cline, "%d", &(lvvert->nvert));
//    fprintf(stdout, "\nvvortice found %d vertices\n", lvvert->nvert);
    lvvert->qhullSize = lvvert->nvert;
    lvvert->tr = (int *) my_malloc(lvvert->nvert * sizeof (int));
    for (i = 0; i < lvvert->nvert; i++) lvvert->tr[i] = -1;

    lvvert->vertices = (s_vvertice *) my_calloc(M_BUFSIZE, sizeof (s_vvertice));
    lvvert->pvertices = (s_vvertice **) my_calloc(M_BUFSIZE, sizeof (s_vvertice*));

    /* Get the string of number of vertices to read, to look up the neighbour
     * list from qhull */
    sprintf(s_nvert, "%d", lvvert->nvert);
    strcat(s_nvert, "\n");

    /* Advance cursor to neighbour list */
    while (fgets(nbline, nchar_max, fNb) != NULL && strcmp(s_nvert, nbline) != 0);
    /* Advance cursor to the vertice neighbour list */
    //while (fgets(vNbline, nchar_max, fvNb) != NULL && curLineNb++ < lvvert->nvert * 2 + 1) ;

    i = 0;
    while (fgets(cline, nchar_max, f) != NULL) {
        /* Read vertice positions */
        if (fgets(nbline, nchar_max, fNb) != NULL) {
            /* Read neighbours */
            /* Read vertice neighbour vertices */
            if (strcmp("\n", cline) != 0 && strcmp("\n", nbline) != 0
                    ) {

                sscanf(cline, "%f %f %f", &xyz[0], &xyz[1], &xyz[2]);
                sscanf(nbline, "%d %d %d %d", &curNbIdx[0], &curNbIdx[1],
                        &curNbIdx[2], &curNbIdx[3]);
                // sscanf(vNbline, "%d %d %d %d %d", &trash, &curVnbIdx[0], &curVnbIdx[1], &curVnbIdx[2], &curVnbIdx[3]) ;
                //printf("%s\n",vNbline);
                //fflush(stdout);
                /* Test voro. vert. for alpha sphere cond. and returns radius if
                 * cond. are ok, -1 else */

                tmpRadius = testVvertice(xyz, curNbIdx, atoms, asph_min_size,
                        asph_max_size, lvvert, xshift, yshift, zshift, avg_bfactor,pdb);
//                fprintf(stdout, "%f\n", tmpRadius);
                if (tmpRadius > 0) {
                    v = (lvvert->vertices + vInMem);
                    v->x = xyz[0] - xshift;
                    v->y = xyz[1] - yshift;
                    v->z = xyz[2] - zshift;
                    v->ray = tmpRadius;
                    v->sort_x = -1;
                    v->seen = 0;
                    v->electrostatic_energy = 0.0;
                    
                    tmpApolar = 0;

                    for (j = 0; j < 4; j++) {
                        if (atoms[lvvert->h_tr[curNbIdx[j]]].electroneg < 2.8) tmpApolar++;

                        v->neigh[j] = &(atoms[lvvert->h_tr[curNbIdx[j]]]);

                    }
                    //                    v->neigh[0] = &(atoms[lvvert->h_tr[curNbIdx[0]]]);
                    //                    v->neigh[2] = &(atoms[lvvert->h_tr[curNbIdx[2]]]);
                    //                    v->neigh[3] = &(atoms[lvvert->h_tr[curNbIdx[3]]]);
                    //
                    //                    v->neigh[1] = &(atoms[lvvert->h_tr[curNbIdx[1]]]);
                    /*
                                            fprintf(stdout,"%p\n",&(atoms[lvvert->h_tr[curNbIdx[2]]]));
                                            fprintf(stdout,"%p\n",v->neigh[2]);
                     */

                    v->apol_neighbours = 0;
                    lvvert->tr[i] = vInMem;

                    lvvert->pvertices[vInMem] = v;

                    vInMem++; /* Vertices actually read */
                    v->id = natoms + i + 1 - vInMem;

                    if (tmpApolar >= min_apol_neigh) v->type = M_APOLAR_AS;
                    else v->type = M_POLAR_AS;

                    v->qhullId = i; /* Set index in the qhull file */
                    if(pdb->n_xlig_atoms>0) v->resid=1;
                    
                    else v->resid = -1; /* Initialize internal index */

//                    printf("intial resid : %d \n",lvvert->pvertices[vInMem-1]->resid);
                    set_barycenter(v); /* Set barycentre */

                }
                //                else fprintf(stdout,"tmpRadius %f\n",tmpRadius);
                i++;

            }
        }
    }

    my_free(s_nvert);

    lvvert->nvert = vInMem;
    fclose(f);
    fclose(fNb);
    //fclose(fvNb);
}

/**
   ## FUNCTION:
    fill_vertices
  
   ## PARAMETRES:
    @ s_lst_vvertice *lvvert : The structure to fill
    @ const char fpath[]     : File containing vertices
    @ s_atm *atoms           : List of atoms
    @ int natoms             : Number of atoms
    @ int min_apol_neigh  : Number of apolar neighbor of a vertice to be
                            considered as apolar
    @ float asph_min_size : Minimum size of voronoi vertices to retain
    @ float asph_max_size : Maximum size of voronoi vertices to retain
  
   ## SPECIFICATION:
    Fill structure given in argument (must have been allocated) using a file
    containing vertice coordinates and neighbours using p i options of qhull.
  
   ## RETURN:
    void
  
 */
void add_missing_vvertices(s_lst_vvertice *lvvert, const char fpath[], s_atm *atoms, 
        int min_apol_neigh, float asph_min_size, float asph_max_size,
        float xshift, float yshift, float zshift, float avg_bfactor,s_pdb *pdb) {
    FILE *f = NULL; /* File handler for vertices coordinates */
    FILE *fNb = NULL; /* File handler for vertices atomic neighbours */
    FILE *fvNb = NULL; /* File handler for vertices vertice neighbours */

    s_vvertice *tmpv = NULL;

    float tmpRadius; /* Temporary radius of voronoi vertice (ray of alpha sphere) */
    float xyz[3] = {0, 0, 0};

    int j, nchar_max = 255,
            curLineNb = 0, /* Current line number */
            trash = 0,
            tmpApolar = 0,
            curVnbIdx[4], /* Current vertice neighbours */
            curNbIdx[4]; /* Current atomic neighbours */

    char cline[nchar_max],
            nbline[nchar_max],
            vNbline[nchar_max],
            *s_nvert = (char *) my_malloc(sizeof (char) *nchar_max);

    tmpv = (s_vvertice *) my_malloc(sizeof (s_vvertice));
    /* Once we have the number of lines, lets allocate memory and get the lines */

    f = fopen(fpath, "r");
    fNb = fopen(fpath, "r");
    fvNb = fopen(fpath, "r");

    char *status = NULL;

    status = fgets(cline, nchar_max, f); /* Skip fir=st line */
    status = fgets(cline, nchar_max, f); /* Load 2nd line containing nbr of coors. */
    status = fgets(nbline, nchar_max, fNb); /* Skip first line */
    status = fgets(nbline, nchar_max, fNb); /* Load 2nd line containing nbr of coors. */
    status = fgets(vNbline, nchar_max, fvNb); /* Skip first line */
    status = fgets(vNbline, nchar_max, fvNb); /* Load 2nd line containing nbr of coors. */
    if(!status) {
        return;
    }
    int nverttmp = 0;
    sscanf(cline, "%d", &(nverttmp));

    // lvvert->qhullSize = lvvert->nvert ;
    // lvvert->tr = (int *) my_malloc(lvvert->nvert * sizeof (int)) ;
    // for (i = 0 ; i < lvvert->nvert ; i++) lvvert->tr[i] = -1 ;

    // lvvert->vertices = (s_vvertice *) my_calloc(lvvert->nvert, sizeof (s_vvertice)) ;
    // lvvert->pvertices = (s_vvertice **) my_calloc(lvvert->nvert, sizeof (s_vvertice*)) ;



    /* Get the string of number of vertices to read, to look up the neighbour
     * list from qhull */
    sprintf(s_nvert, "%d", nverttmp);
    strcat(s_nvert, "\n");


    /* Advance cursor to neighbour list */
    while (fgets(nbline, nchar_max, fNb) != NULL && strcmp(s_nvert, nbline) != 0);

    /* Advance cursor to the vertice neighbour list */
    while (fgets(vNbline, nchar_max, fvNb) != NULL && curLineNb++ < nverttmp * 2 + 1);

    //i = 0 ;
    int nbv = 0;
    while (fgets(cline, nchar_max, f) != NULL) {
        /* Read vertice positions */
        if (fgets(nbline, nchar_max, fNb) != NULL) {
            /* Read neighbours */
            if (fgets(vNbline, nchar_max, fvNb) != NULL) {
                /* Read vertice neighbour vertices */
                if (strcmp("\n", cline) != 0 && strcmp("\n", nbline) != 0
                        && strcmp("\n", vNbline) != 0) {

                    sscanf(cline, "%f %f %f", &xyz[0], &xyz[1], &xyz[2]);
                    sscanf(nbline, "%d %d %d %d", &curNbIdx[0], &curNbIdx[1],
                            &curNbIdx[2], &curNbIdx[3]);

                    sscanf(vNbline, "%d %d %d %d %d", &trash, &curVnbIdx[0],
                            &curVnbIdx[1], &curVnbIdx[2], &curVnbIdx[3]);

                    /* Test voro. vert. for alpha sphere cond. and returns radius if
                     * cond. are ok, -1 else */

                    tmpRadius = testVvertice(xyz, curNbIdx, atoms, asph_min_size,
                            asph_max_size, lvvert, xshift, yshift, zshift, avg_bfactor,pdb);
                    if (tmpRadius > 0) {
                        tmpv->x = xyz[0] - xshift;
                        tmpv->y = xyz[1] - yshift;
                        tmpv->z = xyz[2] - zshift;
                        tmpv->ray = tmpRadius;

                        for (j = 0; j < 4; j++) {
                            if (atoms[lvvert->h_tr[curNbIdx[j]]].electroneg < 2.8) tmpApolar++;
                            // We take the indice as is only if it is > to 0.
                            // Thihich mean that indexes starts
                            if (curVnbIdx[j] >= 0) tmpv->vneigh[j] = curVnbIdx[j];
                            else tmpv->vneigh[j] = -1;

                            tmpv->neigh[j] = &(atoms[lvvert->h_tr[curNbIdx[j]]]);

                        }
                        tmpv->neigh[0] = &(atoms[lvvert->h_tr[curNbIdx[0]]]);
                        tmpv->neigh[1] = &(atoms[lvvert->h_tr[curNbIdx[1]]]);
                        tmpv->neigh[2] = &(atoms[lvvert->h_tr[curNbIdx[2]]]);
                        tmpv->neigh[3] = &(atoms[lvvert->h_tr[curNbIdx[3]]]);



                        tmpv->apol_neighbours = 0;
                        //                        lvvert->tr[i] = vInMem ;

                        //                        lvvert->pvertices[vInMem] = v ;

                        //                        vInMem++ ; /* Vertices actually read 
                        //                        v->id = natoms + i + 1 - vInMem ;

                        if (tmpApolar >= min_apol_neigh) tmpv->type = M_APOLAR_AS;
                        else tmpv->type = M_POLAR_AS;

                        //                        v->qhullId = i ; /* Set index in the qhull file */
                        tmpv->resid = -1; /* Initialize internal index */


                        set_barycenter(tmpv); /* Set barycentre */
                        /*fprintf(stdout,"bary: %f\n",lvvert->vertices[lvvert->nvert-1].bary[0]);
                        fflush(stdout);*/

                        unsigned short check = check_if_similar_vertice_in_list(tmpv, lvvert);
                        if (!check) {
                            //printf("vertice list length :%d \n",lvvert->nvert);
                            add_vertice_to_vertice_list(lvvert, tmpv); /*TODO handle pvert*/
                            nbv++;
                        }
                    }
                    //i++ ;

                }
            } //else printf("error reading neighbour list\n");
        } //else printf("error reading atom neighbours\n");
    }//else printf("error reading vertice positions\n");
    //    fprintf(stdout,"%d vertices out of %d not in previous vertice list, currently %d vv\n",nbv,nverttmp,lvvert->nvert);


    //lvvert->nvert = vInMem ;
    my_free(s_nvert);
    my_free(tmpv);
    if (f != NULL) fclose(f);
    if (fNb != NULL) fclose(fNb);
    if (fvNb != NULL) fclose(fvNb);

}

void copy_vertice(s_vvertice *vorig, s_vvertice *vdest, int n) {
    vdest->x = vorig->x;
    vdest->y = vorig->y;
    vdest->z = vorig->z;

    vdest->apol_neighbours = vorig->apol_neighbours;

    vdest->bary[0] = vorig->bary[0];
    vdest->bary[1] = vorig->bary[1];
    vdest->bary[2] = vorig->bary[2];
    //vdest->bary[0]=0.0;vdest->bary[1]=0.0;vdest->bary[2]=0.0;
    vdest->id = n;
    vdest->qhullId = -1; /*todo change that here*/
    vdest->ray = vorig->ray;
    vdest->resid = vorig->resid;
    vdest->seen = vorig->seen;
    vdest->sort_x = vorig->sort_x;
    vdest->type = vorig->type;
    vdest->electrostatic_energy = vorig->electrostatic_energy;

    vdest->neigh[0] = vorig->neigh[0];
    vdest->neigh[1] = vorig->neigh[1];
    vdest->neigh[2] = vorig->neigh[2];
    vdest->neigh[3] = vorig->neigh[3];
    //vdest->neigh[0]=0; vdest->neigh[1]=0; vdest->neigh[2]=0; vdest->neigh[3]=0;
}

void add_vertice_to_vertice_list(s_lst_vvertice *lvvert, s_vvertice *v) {
    /*increment the vertice counter before starting */
    if (v) {
        lvvert->nvert = lvvert->nvert + 1;

        int n = lvvert->nvert;
        //s_vvertice *newVertice=(s_vvertice *)my_malloc(sizeof(s_vvertice));

        copy_vertice(v, (lvvert->vertices + n - 1), n);
        lvvert->pvertices[lvvert->nvert - 1] = (lvvert->vertices + n - 1);
        //lvvert->vertices=(s_vvertice *)my_realloc(&(lvvert->vertices),sizeof(s_vvertice)*(n+1));
        /*TODO CHECK IF WE CAN GET RID OF SOME THINGS FROM lvvert , like tr and so on*/

        //lvvert->pvertices=(s_vvertice **)my_realloc(lvvert->pvertices,sizeof(s_vvertice*)*(n+1));
        //s_vvertice *curVert=&(lvvert->vertices[n-1]);
        //curVert=newVertice;

        //lvvert->pvertices[n-1]=newVertice;
    } else {
        fprintf(stdout, "vertice to add to vertice list contained a NULL pointer.\n");
        fflush(stdout);
    }
    //lvvert->tr[n] = n ;/*careful tr not used anymore !! */

}

unsigned short check_if_similar_vertice_in_list(s_vvertice *v, s_lst_vvertice *lvvert) {
    int idx1;
    s_vvertice *cur_vertice = NULL;
    idx1 = 0;
    unsigned short flag = 0;
    while (idx1 < lvvert->nvert - 1 && !flag) {
        cur_vertice = (lvvert->vertices + idx1);
        if (fabs(cur_vertice->bary[0] - v->bary[0]) < 1.0e-3) {
            if (fabs(cur_vertice->bary[1] - v->bary[1]) < 1.0e-3) {
                if (fabs(cur_vertice->bary[2] - v->bary[2]) < 1.0e-3 && fabs(v->ray - cur_vertice->ray) < 1.0e-3) {
                    return (1);
                }
            }
        }

        idx1++;
    }
    return (0);

}

s_lst_vvertice *compare_vvertice_shifted_lists(s_lst_vvertice *lvvert, s_lst_vvertice *list_shifted, float xshift, float yshift, float zshift) {

    s_vvertice *cur_vert = NULL;
    s_vvertice *cur_shifted_vert = NULL;
    s_lst_vvertice *new_lvvert = my_malloc(sizeof (s_lst_vvertice));
    double dist = 0.0;
    new_lvvert->h_tr = lvvert->h_tr;
    new_lvvert->n_h_tr = lvvert->n_h_tr;

    int idx1 = 0, idx2 = 0;
    int i;
    short found = 0;
    double diff_x = 0.0, diff_y = 0.0, diff_z = 0.0;

    /*allocate a new vertice list prior to calculation*/
    new_lvvert->vertices = (s_vvertice *) my_malloc(sizeof (s_vvertice) * lvvert->nvert); /**< List of voronoi vertices */
    new_lvvert->pvertices = (s_vvertice **) my_malloc(sizeof (s_vvertice*) * lvvert->nvert);
    for (i = 0; i < lvvert->nvert; i++) new_lvvert->pvertices[i] = NULL;
    new_lvvert->tr = (int*) my_malloc(lvvert->nvert * sizeof (int));
    short *shifted_vertice_found_flags = (short *) my_malloc(sizeof (short) *list_shifted->nvert); //just a flag list to put 1 if we already found a vertice
    for (i = 0; i < list_shifted->nvert; i++) shifted_vertice_found_flags[i] = 0;
    /*new_lvvert->nvert=lvvert->nvert;
    for (i = 0 ; i < new_lvvert->nvert ; i++) new_lvvert->tr[i] = -1 ;
     */
    int n_found = 0;
    /*
        fprintf(stdout,"%d nverts\n",lvvert->nvert);
     */
    /*
        fflush(stdout);
     */
    for (idx1 = 0; idx1 < lvvert->nvert; idx1++) {
        found = 0;
        cur_vert = lvvert->pvertices[idx1];

        /*
                printf("%d\n",list_shifted->nvert);
         */
        for (idx2 = 0; idx2 < list_shifted->nvert && !found; idx2++) {
            cur_shifted_vert = list_shifted->pvertices[idx2];

            diff_x = cur_vert->x - (cur_shifted_vert->x - xshift);
            diff_x = diff_x*diff_x;
            diff_y = cur_vert->y - (cur_shifted_vert->y - yshift);
            diff_y = diff_y*diff_y;
            diff_z = cur_vert->z - (cur_shifted_vert->z - zshift);
            diff_z = diff_z*diff_z;
            dist = sqrt(diff_x + diff_y + diff_z);
            /*
                        printf("%f\n",diff_x);
             */

            if (dist < 1.0e-5 && shifted_vertice_found_flags[idx2] < 1) {
                shifted_vertice_found_flags[idx2] = 1;
                /*
                                printf("found %d vs %d\n",idx1,idx2);
                 */
                found = 1;
                memcpy(new_lvvert->vertices + n_found, cur_vert, sizeof (s_vvertice));

                new_lvvert->pvertices[n_found] = &(new_lvvert->vertices[n_found]); /*just pointer to ancient vertice list!!!*/

                /*
                                memcpy(new_lvvert->pvertices[n_found],new_lvvert->vertices+n_found,sizeof(s_vvertice));
                 */

                //printf("%.3f vs %.3f\n",new_lvvert->vertices[n_found].y,lvvert->vertices[idx1].y);
                //printf("found : %d\n",idx1);

                n_found++;

            }
        }
    }
    my_free(shifted_vertice_found_flags);
    /*
        printf("nfound here : %d\n",n_found);
     */
    new_lvvert->nvert = n_found;
    new_lvvert->qhullSize = lvvert->qhullSize;

    return (new_lvvert);
}

/**
   ## FUNCTION:
    set_barycenter
  
   ## SPECIFICATION:
    Set barycenter of a vertice using it's 4 contacting atoms.
  
   ## PARAMETERS:
    @ s_vvertice *v: The vertice
  
   ## RETURN: void
  
 */
void set_barycenter(s_vvertice *v) {
    int i;
    float xsum = 0.0,
            ysum = 0.0,
            zsum = 0.0;
    /*
        fprintf(stdout,"%.3f\n",v->neigh[2]->x);
        fflush(stdout);
     */
    for (i = 0; i < 4; i++) {
        /*
                fprintf(stdout,"i : %d\n",i);
         */

        xsum += v->neigh[i]->x;
        ysum += v->neigh[i]->y;
        zsum += v->neigh[i]->z;

    }

    v->bary[0] = xsum * 0.25;
    v->bary[1] = ysum * 0.25;
    v->bary[2] = zsum * 0.25;
}

/**
   ## FUNCTION:
    testVvertice
  
   ## SPECIFICATION:
    Test if alpha sphere conditions are fulfilled for current vertice
  
   ## PARAMETERS:
    @ float xyz[3]        : Coordinates of current vertice
    @ int curNbIdx[4]     : Indexes of atomic neighbours of the current vertice
    @ s_atm *atoms        : List of all atoms
    @ float min_asph_size : Minimum size of alpha spheres.
    @ float max_asph_size : Maximum size of alpha spheres.
  
   ## RETURN:
    float : -1 if conditions are not fulfilled, else the alpha sphere radius
            is returned.
  
 */
float testVvertice(float xyz[3], int curNbIdx[4], s_atm *atoms,
        float min_asph_size, float max_asph_size,
        s_lst_vvertice *lvvert,
        float xshift, float yshift, float zshift, float avg_bfactor,s_pdb *pdb) {
    float x = xyz[0] - xshift,
            y = xyz[1] - yshift,
            z = xyz[2] - zshift;
    float baryx = 0.0, baryy = 0.0, baryz = 0.0;
    float barybf = 0.0; /*temporary b factor for all atoms contacting the sphere*/
    //    if(curNbIdx[0]!=lvvert->h_tr[curNbIdx[0]]) printf("%d vs %d : %s vs %s\n",curNbIdx[0],lvvert->h_tr[curNbIdx[0]],atoms[curNbIdx[0]].symbol,atoms[lvvert->h_tr[curNbIdx[0]]].symbol);
    s_atm *cura = &(atoms[lvvert->h_tr[curNbIdx[0]]]);
    baryx += cura->x;
    baryy += cura->y;
    baryz += cura->z;
    barybf += cura->bfactor;
    float xlig_x=0.0;
    float xlig_y=0.0;
    float xlig_z=0.0;
    float distVatom1 = dist(x, y, z, cura->x, cura->y, cura->z);
    float distVatom2,
            distVatom3,
            distVatom4;
    int i_explicit_ligand=0;
    
    if (min_asph_size <= distVatom1 + M_PREC_TOLERANCE && distVatom1 - M_PREC_TOLERANCE <= max_asph_size) {
        cura = &(atoms[lvvert->h_tr[curNbIdx[1]]]);
        distVatom2 = dist(x, y, z, cura->x, cura->y, cura->z);
        baryx += cura->x;
        baryy += cura->y;
        baryz += cura->z;
        barybf += cura->bfactor;
        cura = &(atoms[lvvert->h_tr[curNbIdx[2]]]);
        distVatom3 = dist(x, y, z, cura->x, cura->y, cura->z);
        baryx += cura->x;
        baryy += cura->y;
        baryz += cura->z;
        barybf += cura->bfactor;
        cura = &(atoms[lvvert->h_tr[curNbIdx[3]]]);
        distVatom4 = dist(x, y, z, cura->x, cura->y, cura->z);
        baryx += cura->x;
        baryy += cura->y;
        baryz += cura->z;
        barybf += cura->bfactor;
        baryx *= 0.25;
        baryy *= 0.25;
        baryz *= 0.25;
        barybf *= 0.25;
        /* Test if all 4 neighbours are on the alpha sphere surface
         * (approximate test) */
        if (fabs(distVatom1 - distVatom2) < M_PREC_TOLERANCE &&
                fabs(distVatom1 - distVatom3) < M_PREC_TOLERANCE &&
                fabs(distVatom1 - distVatom4) < M_PREC_TOLERANCE) {

            
            if(pdb->n_xlig_atoms){
                for(i_explicit_ligand=0;i_explicit_ligand<pdb->n_xlig_atoms;i_explicit_ligand++){
                    xlig_x=pdb->xlig_x[i_explicit_ligand];
                    xlig_y=pdb->xlig_y[i_explicit_ligand];
                    xlig_z=pdb->xlig_z[i_explicit_ligand];
                    /*printf("%f %f %f\n",x,y,z);
                    printf("here %d\n",dist(xlig_x,xlig_y,xlig_z, x,y,z));*/
                    if(dist(xlig_x, xlig_y, xlig_z, x,y,z)<=(distVatom1)){
                        /*TODO, debug why not working here*/
                        /*TODO: add manual clustering for explicit pockets*/
                        return distVatom1;
                    };
                }
                return(-1.0);
            }
            
            
            if (avg_bfactor > 0.0 && barybf / avg_bfactor > 1.4) return (-1.0);
            /*now test if the vertice is not too far away from the pocket*/
            if (dist(baryx, baryy, baryz, xyz[0], xyz[1], xyz[2]) > 1.0 && distVatom1 > (max_asph_size - 1.5)) {
                /*printf("vertice dropped %f %f \n",dist(baryx,baryy,baryz,xyz[0],xyz[1],xyz[2]),barybf/avg_bfactor);*/
                return (-2.0);
            }
            return distVatom1;
        }

    }
    return -3.0;
}

/**
   ## FUNCTION:
    print_vvertices
  
   ## SPECIFICATION:
    Print function.
  
   ## PARAMETERS:
    @ FILE *f                : Buffer to print in
    @ s_lst_vvertice *lvvert : Vertices to print
  
   ## RETURN: void
  
 */
void print_vvertices(FILE *f, s_lst_vvertice *lvvert) {
    if (lvvert) {
        if (lvvert->vertices) {
            int i;
            for (i = 0; i < lvvert->nvert; i++) {
                s_vvertice *v = &(lvvert->vertices[i]);
                if (v->neigh[0] && v->neigh[1] && v->neigh[2] && v->neigh[3]) {
                    fprintf(f, "====== Vertice %d: =====\n", i);
                    fprintf(f, "- x = %f, y = %f, z = %f\n", v->x, v->y, v->z);
                    fprintf(f, "- ix = %d\n", v->sort_x);

                    float d1 = dist(v->x, v->y, v->z, v->neigh[0]->x, v->neigh[0]->y, v->neigh[0]->z);
                    float d2 = dist(v->x, v->y, v->z, v->neigh[1]->x, v->neigh[1]->y, v->neigh[1]->z);
                    float d3 = dist(v->x, v->y, v->z, v->neigh[2]->x, v->neigh[2]->y, v->neigh[2]->z);
                    float d4 = dist(v->x, v->y, v->z, v->neigh[3]->x, v->neigh[3]->y, v->neigh[3]->z);

                    fprintf(f, "- Neighbour: \n1 - %f (%f %f %f: %d) \n2 - %f (%f %f %f: %d)\n3 - %f (%f %f %f: %d)\n4 - %f (%f %f %f: %d)\n", d1, v->neigh[0]->x, v->neigh[0]->y, v->neigh[0]->z, v->neigh[0]->id, d2, v->neigh[1]->x, v->neigh[1]->y, v->neigh[1]->z, v->neigh[1]->id, d3, v->neigh[2]->x, v->neigh[2]->y, v->neigh[2]->z, v->neigh[2]->id, d4, v->neigh[3]->x, v->neigh[3]->y, v->neigh[3]->z, v->neigh[3]->id);
                }
            }
        }
    }
}

/**
   ## FUNCTION:
    get_verts_volume_ptr
  
   ## SPECIFICATION:
    Get an monte carlo approximation of the volume occupied by the alpha spheres
    given in argument (list of pointers)
  
   ## PARAMETRES:
    @ s_vvertice **verts: List of pointer to alpha spheres
    @ int nvert: Number of spheres
    @ int niter: Number of monte carlo iteration to perform
        @ float correct: radius for which the size of an alpha sphere should be 
          corrected in order to calculate the volume
  
   ## RETURN:
    float: volume.
  
 */
float get_verts_volume_ptr(s_vvertice **verts, int nvert, int niter, float correct) {
    int i = 0, j = 0,
            nb_in = 0;

    float xmin = 0.0, xmax = 0.0,
            ymin = 0.0, ymax = 0.0,
            zmin = 0.0, zmax = 0.0,
            xtmp = 0.0, ytmp = 0.0, ztmp = 0.0,
            xr = 0.0, yr = 0.0, zr = 0.0,
            vbox = 0.0;
    int li, nreps = 100;
    float sum_volume=0.0;
    s_vvertice *vcur = NULL;

    /* First, search extreme coordinates to get a contour box of the molecule */
    for (i = 0; i < nvert; i++) {
        vcur = verts[i];

        if (i == 0) {
            xmin = vcur->x - vcur->ray + correct;
            xmax = vcur->x + vcur->ray + correct;
            ymin = vcur->y - vcur->ray + correct;
            ymax = vcur->y + vcur->ray + correct;
            zmin = vcur->z - vcur->ray + correct;
            zmax = vcur->z + vcur->ray + correct;
        } else {
            /* Update the minimum and maximum extreme point */
            if (xmin > (xtmp = vcur->x - vcur->ray + correct)) xmin = xtmp;
            else if (xmax < (xtmp = vcur->x + vcur->ray + correct)) xmax = xtmp;

            if (ymin > (ytmp = vcur->y - vcur->ray + correct)) ymin = ytmp;
            else if (ymax < (ytmp = vcur->y + vcur->ray + correct)) ymax = ytmp;

            if (zmin > (ztmp = vcur->z - vcur->ray + correct)) zmin = ztmp;
            else if (zmax < (ztmp = vcur->z + vcur->ray + correct)) zmax = ztmp;
        }
    }

    /* Next calculate the contour box volume */
    vbox = (xmax - xmin)*(ymax - ymin)*(zmax - zmin);
    for (li = 0; li < nreps; li++) {
        nb_in = 0;
        /* Then apply monte carlo approximation of the volume.	 */
        for (i = 0; i < niter; i++) {
            xr = rand_uniform(xmin, xmax);
            yr = rand_uniform(ymin, ymax);
            zr = rand_uniform(zmin, zmax);

            for (j = 0; j < nvert; j++) {
                vcur = verts[j];
                xtmp = vcur->x - xr;
                ytmp = vcur->y - yr;
                ztmp = vcur->z - zr;

                /* Compare r^2 and dist(center, random_point)^2 */
                if (((correct + vcur->ray)*(vcur->ray + correct)) > (xtmp * xtmp + ytmp * ytmp + ztmp * ztmp)) {
                    /* The point is inside one of the vertice!! */
                    nb_in++;
                    break;
                }
            }
        }
        sum_volume += ((float) nb_in) / ((float) niter) * vbox;

    }

    /* Ok lets just return the volume Vpok = Nb_in/Niter*Vbox */
    /*    return ((float) nb_in) / ((float) niter) * vbox ;*/
    return (sum_volume / (float) nreps);
}

float get_convex_hull_volume(s_vvertice **verts, int nvert) {
    int i;
    s_vvertice *vcur = NULL;
    char tmpn1[250] = "";
    char tmpn2[250] = "";
    pid_t pid = getpid();
    int nchar_max = 255;
    char cline[nchar_max];
    if (nvert < 10) return (0.0);
    sprintf(tmpn1, "/tmp/qhull_in_fpocket_%d.dat", pid);
    sprintf(tmpn2, "/tmp/qhull_out_fpocket_%d.dat", pid);
    FILE *ftmp = fopen(tmpn2, "w");
    FILE *fvoro = fopen(tmpn1, "w+");
    /* Write the header for qvoronoi */

    fprintf(fvoro, "3 rbox D3\n%d\n", nvert);

    for (i = 0; i < nvert; i++) {
        vcur = verts[i];
        fprintf(fvoro, "%.6f %.6f %.6f\n", vcur->x, vcur->y, vcur->z);
    }

    fflush(fvoro);
    rewind(fvoro);
    //printf("tmpn1 %s %d\n",tmpn1,nvert);
    int int_status=run_qconvex(fvoro, ftmp);
    fclose(ftmp);
    fclose(fvoro);
    ftmp = fopen(tmpn2, "r");
    char *status = NULL;

    status = fgets(cline, nchar_max, ftmp); /* Skip fir=st line */
    //printf("cline : %s\n",cline);
    status = fgets(cline, nchar_max, ftmp); /* Load 2nd line containing nbr of coors. */
    if(!status || int_status){
        return(-1);
    }
    //printf("cline : %s\n",cline);
    float area, volume;
    int tmpint;
    fclose(ftmp);

    sscanf(cline, "%d %f %f", &tmpint, &area, &volume);
    //printf("cline : %d %f %f \n",tmpint,area,volume);
    remove(tmpn1);
    remove(tmpn2);

    return (volume);


}

/**
   ## FUNCTION:
    free_vert_lst
  
   ## SPECIFICATION:
    Free memory
  
   ## PARAMETERS:
    @ s_lst_vvertice *lvvert : Data to free
  
   ## RETURN: void
  
 */
void free_vert_lst(s_lst_vvertice *lvvert) {
    if (lvvert) {

        if (lvvert->vertices) {
            my_free(lvvert->vertices);
            lvvert->vertices = NULL;
        }
        if (lvvert->pvertices) {
            my_free(lvvert->pvertices);
            lvvert->pvertices = NULL;
        }
        if (lvvert->tr) {
            my_free(lvvert->tr);
            lvvert->tr = NULL;
        }
        if (lvvert->h_tr) {
            my_free(lvvert->h_tr);
            lvvert->h_tr = NULL;
        }
        my_free(lvvert);
    }
}

/**
   ## FUNCTION:
    is_in_lst_vert
  
   ## SPECIFICATION:
    Says wether a vertice of id v_id is in a list of vertices or not
  
   ## PARAMETRES:
  
   ## RETURN:
    1 if the vertice is in the tab, 0 if not
  
 */
int is_in_lst_vert(s_vvertice **lst_vert, int nb_vert, int v_id) {
    int i;
    for (i = 0; i < nb_vert; i++) {
        if (v_id == lst_vert[i]->id) return 1;
    }

    return 0;
}

/**
   ## FUNCTION:
    is_in_lst_vert
  
   ## SPECIFICATION:
    Says wether a vertice of id v_id is in a list of vertices or not
  
   ## PARAMETRES:
  
   ## RETURN:
    1 if the vertice is in the tab, 0 if not
  
 */
int is_in_lst_vert_p(s_vvertice **lst_vert, int nb_vert, s_vvertice *vert) {
    int i;
    for (i = 0; i < nb_vert; i++) {
        if (vert == lst_vert[i]) return 1;
    }

    return 0;
}
/**
    --
    --

    OUTPUT FUNCTIONS

    --
    --
    --
 */

/**
   ## FUNCTION:
    void write_pdb_vertice(FILE *f, s_vvertice *v)
  
   ## SPECIFICATION:
    Write a voronoi vertice in pdb format.
  
   ## PARAMETRES:
    @ FILE *f: file to write in
    @ s_vvertice *v: The vertice
  
   ## RETURN:
  
 */
void DEPR_write_pdb_vert(FILE *f, s_vvertice *v) {
    if (v->type == M_APOLAR_AS) write_pdb_atom_line(f, "HETATM", v->id, "APOL",
            ' ', "STP", "C", v->resid, ' ',
            v->x, v->y, v->z, 0.0, 0.0, 0,
            "Ve", -1, 0.0);

    else write_pdb_atom_line(f, "HETATM", v->id, " POL", ' ', "STP", "C",
            v->resid, ' ', v->x, v->y, v->z, 0.0, 0.0, 0,
            "Ve", -1, 0.0);
}

/**
   ## FUNCTION:
    void write_pdb_vertice(FILE *f, s_vvertice *v)
  
   ## SPECIFICATION:
    Write a voronoi vertice in pdb format.
  
   ## PARAMETRES:
    @ FILE *f: file to write in
    @ s_vvertice *v: The vertice
  
   ## RETURN:
  
 */
void write_pdb_vert(FILE *f, s_vvertice *v, int i) {

    if (v->electrostatic_energy <= -0.05) write_pdb_atom_line(f, "HETATM", i, " POL",
            ' ', "ACC", "O", v->resid, ' ',
            v->x, v->y, v->z, 0.0, 0.0, 0,
            "Ve", -1, 0.0);
    else if (v->electrostatic_energy >= 0.05) write_pdb_atom_line(f, "HETATM", i, " POL", ' ', "DON", "N",
            v->resid, ' ', v->x, v->y, v->z, 0.0, 0.0, 0,
            "Ve", -1, 0.0);
    else write_pdb_atom_line(f, "HETATM", i, "APOL", ' ', "STP", "C",
            v->resid, ' ', v->x, v->y, v->z, 0.0, 0.0, 0,
            "Ve", -1, 0.0);
}

/**
   ## FUNCTION:
    write_pqr_vertice
  
   ## SPECIFICATION:
    Write a voronoi vertice in pqr format.
  
   ## PARAMETRES:
    @ FILE *f       : file to write in
    @ s_vvertice *v : The vertice
  
   ## RETURN:
    void
  
 */

/*void write_pqr_vert(FILE *f, s_vvertice *v)
{
    if (v->type == M_APOLAR_AS) write_pqr_atom_line(f, "ATOM", v->id, "APOL", ' ',
                                                    "STP", " ", v->resid, ' ',
                                                    v->x, v->y, v->z, 0.0, v->ray) ;

    else write_pqr_atom_line(f, "ATOM", v->id, " POL", ' ', "STP", " ",
                             v->resid, ' ', v->x, v->y, v->z, 0.0, v->ray) ;
}*/
void write_pqr_vert(FILE *f, s_vvertice *v, int i) {
    
    if (v->electrostatic_energy >= 0.05) write_pqr_atom_line(f, "ATOM", i, "   O", ' ',
            "ACC", " ", v->resid, ' ',
            v->x, v->y, v->z, 0.0, v->ray);
    else if (v->electrostatic_energy <= -0.05) write_pqr_atom_line(f, "ATOM", i, "   N", ' ',
            "DON", " ", v->resid, ' ',
            v->x, v->y, v->z, 0.0, v->ray);
    else if(v->type == M_APOLAR_AS) write_pqr_atom_line(f, "ATOM", i, "   C", ' ', "STP", " ",
            v->resid, ' ', v->x, v->y, v->z, 0.0, v->ray);
    else write_pqr_atom_line(f, "ATOM", i, "   O", ' ', "STP", " ",
            v->resid, ' ', v->x, v->y, v->z, 0.0, v->ray);
}
