
#include "../headers/neighbor.h"
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
## FILE 					neighbor.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
## This file define functions used to perform a space search
## operation like looking for all neighbors of a given molecule
## situated at a given distance. It makes use of a sorting system,
## which sort all atoms/vertices according to each dimension.
##
## See sort.c for information on the sorting procedure.
##
## MODIFICATIONS HISTORY
##
##	11-02-09	(v)  Modified argument type for sorting function
##	28-11-08	(v)  Comments UTD + relooking.
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Check the algorithms more deeply... Try to make the code more lisible! 
##

 */

/**
   ## FUNCTION: 
        get_mol_atm_neigh
  
   ## SPECIFICATION: 
        Return a list of pointer to the atoms situated a distance lower or equal
        to dcrit from a molecule represented by a list of atoms.

        This functon use a list of atoms that is sorted on the X dimension to accelerate
        the research.
  
   ## PARAMETRES:
        @ s_atm **atoms        : The molecule atoms.
        @ int natoms		   : Number of atoms in the molecule
        @ s_pdb *pdb           : The pdb structure containing all atoms of the system
        @ float dcrit  	   : The distance criteria.
        @ int *nneigh          : OUTPUT A pointer to the number of neighbour found,
                                                         will be modified in the function...
  
   ## RETURN:
        A tab of pointers to the neighbours, with the number of neighbors stored in
        nneigh
  
 */
s_atm** get_mol_atm_neigh(s_atm **atoms, int natoms, s_atm **all, int nall,
        float dcrit, int *nneigh) {
    /* No vertices, we only search atoms... */
    s_vsort *lsort = get_sorted_list(all, nall, NULL, 0);
    s_vect_elem *xsort = lsort->xsort;

    int ip, im,
            stopm, stopp,
            nb_neigh,
            sort_x,
            ntest_x,
            dim = lsort->nelem;

    float vvalx, vvaly, vvalz;

    int real_size = 10,
            i, seen;

    s_atm *curap = NULL, *curam = NULL;
    s_atm **neigh = (s_atm**) my_malloc(sizeof (s_atm*) * real_size);

    nb_neigh = 0;
    for (i = 0; i < natoms; i++) {
        s_atm *cur = atoms[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0;
        sort_x = cur->sort_x;
        ntest_x = 1;
        vvalx = cur->x;
        vvaly = cur->y;
        vvalz = cur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while wa are in tab and we dont reach a 
             * distance up to our criteria */
            ip = ntest_x + sort_x;
            if (ip >= dim) stopp = 1;

            if (stopp == 0) {
                curap = (s_atm*) xsort[ip].data;

                if (curap->x - vvalx > dcrit) stopp = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so 
                     * calculate real distance */
                    if (dist(curap->x, curap->y, curap->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule is not one part of the 
                                input, and if we have not already seen it. */
                        seen = is_in_lst_atm(atoms, natoms, curap->id)
                                + is_in_lst_atm(neigh, nb_neigh, curap->id);
                        if (!seen) {
                            if (nb_neigh >= real_size - 1) {
                                real_size *= 2;
                                neigh = (s_atm**) my_realloc(neigh, sizeof (s_atm) * real_size);
                            }
                            neigh[nb_neigh] = curap;
                            nb_neigh++;
                        }
                    }
                }
            }

            im = sort_x - ntest_x;
            if (im < 0) stopm = 1;

            if (stopm == 0) {
                curam = (s_atm*) xsort[im].data;

                if (vvalx - curam->x > dcrit) stopm = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so 
                     * calculate real distance */
                    if (dist(curam->x, curam->y, curam->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule is not one part of the 
                                input, and if we have not already seen it. */
                        seen = is_in_lst_atm(atoms, natoms, curam->id)
                                + is_in_lst_atm(neigh, nb_neigh, curam->id);
                        if (!seen) {
                            if (nb_neigh >= real_size - 1) {
                                real_size *= 2;
                                neigh = (s_atm**) my_realloc(neigh, sizeof (s_atm) * real_size);
                            }
                            neigh[nb_neigh] = curam;
                            nb_neigh++;
                        }
                    }
                }
            }

            ntest_x += 1;
        }
    }

    *nneigh = nb_neigh;
    free_s_vsort(lsort);

    return neigh;
}

/**
   ## FUNCTION: 
        get_mol_vert_neigh
  
   ## SPECIFICATION: 
        Return a list of pointer to the vertices situated a distance lower or equal
        to dcrit of a molecule represented by it's list of atoms.

        This functon use a list of atoms that is sorted on the X dimension to accelerate
        the research.
  
   ## PARAMETRES:
        @ s_atm **atoms         : The molecule.
        @ int natoms		    : Number of atoms in the molecule
    @ s_lst_vvertice *lvert : Full list of vertices present in the system 
        @ float dcrit       : The distance criteria.
        @ int *nneigh           : OUTPUT A pointer to the number of neighbour found,
                                                          will be modified in the function...
  
   ## RETURN:
        A tab of pointers to the neighbours.
  
 */
s_vvertice** get_mol_vert_neigh(s_atm **atoms, int natoms,
        s_vvertice **pvert, int nvert,
        float dcrit, int *nneigh) {
    s_vsort *lsort = get_sorted_list(atoms, natoms, pvert, nvert);
    s_vect_elem *xsort = lsort->xsort;

    int ip, im,
            stopm, stopp,
            nb_neigh,
            sort_x,
            ntest_x,
            dim = lsort->nelem;

    float vvalx, vvaly, vvalz;

    int real_size = 10,
            i, seen;

    s_vvertice *curvp = NULL, *curvm = NULL;
    s_vvertice **neigh = (s_vvertice**) my_malloc(sizeof (s_vvertice*) * real_size);

    nb_neigh = 0;
    for (i = 0; i < natoms; i++) {
        s_atm *cur = atoms[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0;
        sort_x = cur->sort_x;
        ntest_x = 1;
        vvalx = cur->x;
        vvaly = cur->y;
        vvalz = cur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while wa are in tab and we dont reach a 
             * distance up to our criteria */
            ip = ntest_x + sort_x;
            if (ip >= dim) stopp = 1;

            if (stopp == 0 && xsort[ip].type == M_VERTICE_TYPE) {
                curvp = (s_vvertice*) xsort[ip].data;

                if (curvp->x - vvalx > dcrit) stopp = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so 
                     * calculate real distance */
                    if (dist(curvp->x, curvp->y, curvp->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule have not been already seen. */
                        seen = is_in_lst_vert(neigh, nb_neigh, curvp->id);
                        if (!seen) {
                            if (nb_neigh >= real_size - 1) {
                                real_size *= 2;
                                neigh = (s_vvertice **) my_realloc(neigh,
                                        sizeof (s_vvertice) * real_size);
                            }
                            neigh[nb_neigh] = curvp;
                            nb_neigh++;
                        }
                    }
                }
            }

            im = sort_x - ntest_x;
            if (im < 0) stopm = 1;

            if (stopm == 0 && xsort[im].type == M_VERTICE_TYPE) {
                curvm = (s_vvertice*) xsort[im].data;

                if (vvalx - curvm->x > dcrit) stopm = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so 
                     * calculate real distance */
                    if (dist(curvm->x, curvm->y, curvm->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule is not one part of the 
                         * input, and if we have not already seen it. */
                        seen = is_in_lst_vert(neigh, nb_neigh, curvm->id);
                        if (!seen) {
                            if (nb_neigh >= real_size - 1) {
                                real_size *= 2;
                                neigh = (s_vvertice**) my_realloc(neigh, sizeof (s_vvertice) * real_size);
                            }
                            neigh[nb_neigh] = curvm;
                            nb_neigh++;
                        }
                    }
                }
            }

            ntest_x += 1;
        }
    }

    *nneigh = nb_neigh;
    free_s_vsort(lsort);

    return neigh;
}

/**
   ## FUNCTION: 
        get_mol_ctd_atm_neigh
  
   ## SPECIFICATION:
        Return a list of atoms contacted by voronoi vertices situated at dcrit
        of a given molecule represented by a list of its atoms.
  
   ## PARAMETRES:
        @ s_atm **atoms         : The molecule.
        @ int natoms		    : Number of atoms in the molecule
    @ s_lst_vvertice *lvert : Full list of vertices present in the system 
        @ float dcrit       : The distance criteria.
    @ int interface_search  : Perform an interface-type search ?
        @ int *nneigh           : OUTPUT A pointer to the number of neighbour found,
                                                          will be modified in the function...
  
   ## RETURN:
        A tab of pointers to atoms describing the pocket.
  
 */
s_atm** get_mol_ctd_atm_neigh(s_atm **atoms, int natoms,
        s_vvertice **pvert, int nvert,
        float vdcrit, int interface_search, int *nneigh) {


    fprintf(stdout, "sorting atoms and vertices or something like this \n");
    fflush(stdout);
    s_vsort *lsort = get_sorted_list(atoms, natoms, pvert, nvert);
    s_vect_elem *xsort = lsort->xsort;
    fprintf(stdout, "sort finished\n");
    fflush(stdout);

    int ip, im, /* Current indexes in the tab (start at the current 
						   atom position, and check the tab in each directions */
            stopm, stopp, /* Say weteher the algorithm has to continue the search 
						   in each direction */
            nb_neigh = 0,
            sort_x = 0, /* Index of the current ligand atom in the sorted list.*/
            ntest_x = 0,
            dim = lsort->nelem,
            real_size = 10,
            i, j;

    float lx, ly, lz;

    s_vvertice *curvp = NULL, *curvm = NULL;
    s_atm *curatm = NULL;
    s_atm **neigh = (s_atm**) my_malloc(sizeof (s_atm*) * real_size);

    for (i = 0; i < nvert; i++) {
        for (j = 0; j < 4; j++) {
            pvert[i]->neigh[j]->seen = 0;
        }
    }

    for (i = 0; i < natoms; i++) {
        s_atm *cur = atoms[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0; /* We can search in each directions */
        sort_x = cur->sort_x; /* Get the index of the current lidang atom 
									   in the sorted list. */
        ntest_x = 1;

        /* Coordinates of the current atom of the ligand */
        lx = cur->x;
        ly = cur->y;
        lz = cur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while we are in tab and we dont reach a 
             * distance up to our criteria */
            ip = ntest_x + sort_x;

            /* If we are out of the tab, stop the search in this direction */
            if (ip >= dim) stopp = 1;

            if (stopp == 0 && xsort[ip].type == M_VERTICE_TYPE) {
                curvp = (s_vvertice*) xsort[ip].data;

                /* Stop when the distance reaches the criteria */
                if (curvp->x - lx > vdcrit) stopp = 1;
                else {
                    /*OK we have a vertice which is near our atom on the X axis, 
                      so calculate real distance */
                    if (dist(curvp->x, curvp->y, curvp->z, lx, ly, lz) < vdcrit) {
                        /* If the distance from the atom to the vertice is small enough*/
                        for (j = 0; j < 4; j++) {
                            curatm = curvp->neigh[j];
                            if (!curatm->seen) {
                                if (interface_search &&
                                        dist(curatm->x, curatm->y, curatm->z, lx, ly, lz)
                                        < M_INTERFACE_SEARCH_DIST) {
                                    /* If we have not seen yet this atom and if he 
                                     * is not too far away from the ligand, add it*/
                                    if (nb_neigh >= real_size - 1) {
                                        real_size *= 2;
                                        neigh = (s_atm**) my_realloc(neigh, sizeof (s_atm) * real_size);
                                    }
                                    neigh[nb_neigh] = curatm;
                                    curatm->seen = 1;
                                    nb_neigh++;
                                } else if (!interface_search) {
                                    /* If we have not seen yet this atom and if he 
                                     * is not too far away from the ligand, add it*/
                                    if (nb_neigh >= real_size - 1) {
                                        real_size *= 2;
                                        neigh = (s_atm**) my_realloc(neigh, sizeof (s_atm) * real_size);
                                    }
                                    curatm->seen = 1;
                                    neigh[nb_neigh] = curatm;
                                    nb_neigh++;
                                }
                            }
                        }
                    }
                }
            }

            im = sort_x - ntest_x;
            /* If we are out of the tab, stop the search in this direction */
            if (im < 0) stopm = 1;

            if (stopm == 0 && xsort[im].type == M_VERTICE_TYPE) {
                curvm = (s_vvertice*) xsort[im].data;

                if (lx - curvm->x > vdcrit) stopm = 1;
                else {
                    /* OK we have a vertice which is near our atom on the X axe, 
                     * so calculate real distance*/
                    if (dist(curvm->x, curvm->y, curvm->z, lx, ly, lz) < vdcrit) {
                        /* If the distance from the atom to the vertice is small enough */
                        for (j = 0; j < 4; j++) {
                            curatm = curvm->neigh[j];
                            if (!curatm->seen) {
                                if (interface_search &&
                                        dist(curatm->x, curatm->y, curatm->z, lx, ly, lz)
                                        < M_INTERFACE_SEARCH_DIST) {
                                    /* If we have not seen yet this atom and if he 
                                     * is not too far away from the ligand, add it */
                                    if (nb_neigh >= real_size - 1) {
                                        real_size *= 2;
                                        neigh = (s_atm**)
                                                my_realloc(neigh, sizeof (s_atm) * real_size);
                                    }
                                    curatm->seen = 1;
                                    neigh[nb_neigh] = curatm;
                                    nb_neigh++;
                                } else if (!interface_search) {
                                    /* If we have not seen yet this atom and if he 
                                     * is not too far away from the ligand, add it */
                                    if (nb_neigh >= real_size - 1) {
                                        real_size *= 2;
                                        neigh = (s_atm**) my_realloc(neigh, sizeof (s_atm) * real_size);
                                    }
                                    curatm->seen = 1;
                                    neigh[nb_neigh] = curatm;
                                    nb_neigh++;
                                }
                            }
                        }
                    }
                }
            }

            ntest_x += 1;
        }
    }

    *nneigh = nb_neigh;
    free_s_vsort(lsort);

    return neigh;
}

/**
   ## FUNCTION:
        count_pocket_lig_vert_ovlp
  
   ## SPECIFICATION:
        Return the proportion of alpha sphere given in parameter that lies within
        dcrit A of the ligand -> we loop on each ligand atom and we count the
        number of unique vertices next to each atoms using dist-crit.
  
   ## PARAMETRES:
        @ s_atm **lig         : The molecule.
        @ int nlig		      : Number of atoms in the molecule
    @ s_vvertice *pvert   : List of vertices to check.
        @ int nvert		      : Number of verties (tipically in a given pocket)
        @ float dcrit     : The distance criteria.s
  
   ## RETURN:
        A tab of pointers to the neighbours.
  
 */
float count_pocket_lig_vert_ovlp(s_atm **lig, int nlig, s_vvertice **pvert, int nvert, float dcrit) {
    s_vsort *lsort = get_sorted_list(lig, nlig, pvert, nvert);
    s_vect_elem *xsort = lsort->xsort;

    int ip, im, i,
            stopm, stopp,
            nb_neigh,
            sort_x,
            ntest_x,
            dim = lsort->nelem;

    float vvalx, vvaly, vvalz;

    //s_vvertice * ids[nvert];
    for (i = 0; i < nvert; i++) {
        pvert[i]->seen = 0;
        //ids[i] = NULL;
    }

    s_vvertice *curvp = NULL, *curvm = NULL;

    nb_neigh = 0;
    for (i = 0; i < nlig; i++) {
        s_atm *cur = lig[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0;
        sort_x = cur->sort_x;
        ntest_x = 1;
        vvalx = cur->x;
        vvaly = cur->y;
        vvalz = cur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while wa are in tab and we dont reach a
             * distance up to our criteria */
            ip = ntest_x + sort_x;
            if (ip >= dim) stopp = 1;

            if (stopp == 0 && xsort[ip].type == M_VERTICE_TYPE) {
                curvp = (s_vvertice*) xsort[ip].data;

                if (curvp->x - vvalx > dcrit) stopp = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so
                     * calculate real distance */
                    if (dist(curvp->x, curvp->y, curvp->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule have not been already seen. */
                        if (!curvp->seen) {
                            //ids[nb_neigh] = curvp;
                            curvp->seen = 1;
                            nb_neigh++;
                        }
                    }
                }
            }

            im = sort_x - ntest_x;
            if (im < 0) stopm = 1;

            if (stopm == 0 && xsort[im].type == M_VERTICE_TYPE) {
                curvm = (s_vvertice*) xsort[im].data;

                if (vvalx - curvm->x > dcrit) stopm = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so
                     * calculate real distance */
                    if (dist(curvm->x, curvm->y, curvm->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule is not one part of the
                         * input, and if we have not already seen it. */
                        if (!curvm->seen) {
                            //ids[nb_neigh] = curvm;
                            curvm->seen = 1;
                            nb_neigh++;
                        }
                    }
                }
            }

            ntest_x += 1;
        }
    }

    free_s_vsort(lsort);
    return (float) nb_neigh / (float) nvert;
}

/**
   ## FUNCTION:
        count_pocket_lig_vert_ovlp
  
   ## SPECIFICATION:
        Return the proportion of atoms given in parameter that have at least one
        vertice that lies within dcrit A
  
   ## PARAMETRES:
        @ s_atm **lig         : The molecule.
        @ int nlig		      : Number of atoms in the molecule
    @ s_vvertice *pvert   : List of vertices to check.
        @ int nvert		      : Number of verties (tipically in a given pocket)
        @ float dcrit     : The distance criteria.s
  
   ## RETURN:
        The proportion of atoms with dcrit A of at least 1 vertice.
  
 */
float count_atm_prop_vert_neigh(s_atm **lig, int nlig, s_vvertice **pvert, int nvert,
        float dcrit, int n_lig_molecules) {
    s_vsort *lsort = get_sorted_list(lig, nlig, pvert, nvert);
    s_vect_elem *xsort = lsort->xsort;

    int ip, im, i,
            stopm, stopp,
            nb_neigh,
            sort_x,
            ntest_x,
            dim = lsort->nelem;

    float vvalx, vvaly, vvalz;
    int multi_nb_neigh[n_lig_molecules];
    int multi_nb_lig_atoms[n_lig_molecules];

    int c_lig_mol = 0;
    float max_prop = 0.0;
    float tmp = 0.0;
    char chain_tmp[2];
    int resnumber_tmp;
    strcpy(chain_tmp, lig[0]->chain);
    resnumber_tmp = lig[0]->res_id;

    s_vvertice *curvp = NULL, *curvm = NULL;

    nb_neigh = 0;
    multi_nb_neigh[0] = 0;
    multi_nb_lig_atoms[0] = 0;
    for (i = 0; i < nlig; i++) {
        /*check if we are in a new ligand molecule*/
        if (strcmp(chain_tmp, lig[i]->chain) != 0 || resnumber_tmp != lig[i]->res_id) {
            c_lig_mol++;
            strcpy(chain_tmp, lig[i]->chain);
            resnumber_tmp = lig[i]->res_id;
            multi_nb_neigh[c_lig_mol] = 0;
            multi_nb_lig_atoms[c_lig_mol] = 0;
        }
        multi_nb_lig_atoms[c_lig_mol]++;
        s_atm *cur = lig[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0;
        sort_x = cur->sort_x;
        ntest_x = 1;
        vvalx = cur->x;
        vvaly = cur->y;
        vvalz = cur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while we are in tab and we dont reach a
             * distance up to our criteria */
            ip = ntest_x + sort_x;
            if (ip >= dim) stopp = 1;

            if (stopp == 0 && xsort[ip].type == M_VERTICE_TYPE) {
                curvp = (s_vvertice*) xsort[ip].data;

                if (curvp->x - vvalx > dcrit) stopp = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so
                     * calculate real distance */
                    if (dist(curvp->x, curvp->y, curvp->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, break the loop */
                        multi_nb_neigh[c_lig_mol]++;
                        nb_neigh++;
                        break;
                    }
                }
            }

            im = sort_x - ntest_x;
            if (im < 0) stopm = 1;

            if (stopm == 0 && xsort[im].type == M_VERTICE_TYPE) {
                curvm = (s_vvertice*) xsort[im].data;

                if (vvalx - curvm->x > dcrit) stopm = 1;
                else {
                    /* OK we have an atom which is near our vertice on X, so
                     * calculate real distance */
                    if (dist(curvm->x, curvm->y, curvm->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, see if the molecule is not one part of the
                         * input, and if we have not already seen it. */
                        multi_nb_neigh[c_lig_mol]++;
                        nb_neigh++;
                        break;
                    }
                }
            }

            ntest_x += 1;
        }
    }
    /*get only the max proportion between overlap for different lig mols*/
    for (i = 0; i < n_lig_molecules; i++) {
        tmp = (float) multi_nb_neigh[i] / (float) multi_nb_lig_atoms[i];
        if (tmp > max_prop) max_prop = tmp;
    }
    free_s_vsort(lsort);
    return max_prop;
}

/**
   ## FUNCTION:
        count_vert_neigh_P
  
   ## SPECIFICATION:
        Count the number of vertices that lies within a distance <= dist_crit from
        a list of query vertices.
        The user must provide the query vertices, the full list of vertices to
        consider, and the distance criteria.
  
   ## PARAMETRES:
    @ s_vvertice *pvert     : List of pointer to query vertices
    @ int nvert				: Number of query vertices
    @ s_vvertice *pvert_all : List of pointer to all vertice to consider
    @ int nvert_all			: Total number of vertices to consider
        @ float dcrit			: The distance criteria.
  
   ## RETURN:
        int: The total number of vertices lying within dist_crit A of the query vertices
  
 */
int count_vert_neigh_P(s_vvertice **pvert, int nvert,
        s_vvertice **pvert_all, int nvert_all,
        float dcrit) {
    s_vsort *lsort = get_sorted_list(NULL, 0, pvert_all, nvert_all);
    int res = count_vert_neigh(lsort, pvert, nvert, dcrit);

    free_s_vsort(lsort);

    return res;
}

/**
   ## FUNCTION:
        count_vert_neigh
  
   ## SPECIFICATION:
        Count the number of vertices that lies within a distance <= dist_crit from
        a list of query vertices.
        The user must provide the list of sorted vertices (that should include the
        query vertices and all other vertices to consider), the query vertices and
        the distance criteria.

        Note that if the query vertices are not present in the list of ordered
        vertices, the function will return 0.
  
   ## PARAMETRES:
    @ s_vsort *lsort	    : List of sorted vertices.
    @ s_vvertice **pvert    : List of pointer to query vertices
    @ int nvert				: Number of query vertices
        @ float dcrit			: The distance criteria.
  
   ## RETURN:
        int: The total number of vertices lying within dist_crit A of the query vertices
  
 */
int count_vert_neigh(s_vsort *lsort, s_vvertice **pvert, int nvert, float dcrit) {
    s_vect_elem *xsort = lsort->xsort;

    s_vvertice *vcur = NULL;

    int ip, im, i,
            stopm, stopp,
            nb_neigh,
            sort_x,
            ntest_x,
            dim = lsort->nelem;

    float vvalx, vvaly, vvalz;

    /* Set all vertices to NOT SEEN, except the query vertices */
    for (i = 0; i < dim; i++) ((s_vvertice*) lsort->xsort[i].data)->seen = 0;
    for (i = 0; i < nvert; i++) pvert[i]->seen = 2;

    s_vvertice *curvp = NULL, *curvm = NULL;
    nb_neigh = 0;
    for (i = 0; i < nvert; i++) {
        vcur = pvert[i];

        /* Reinitialize variables */
        stopm = 0;
        stopp = 0;
        sort_x = vcur->sort_x;
        ntest_x = 1;
        vvalx = vcur->x;
        vvaly = vcur->y;
        vvalz = vcur->z;

        /* Search neighbors */
        while (!stopm || !stopp) {
            /* Do the neighbor search while wa are in tab and we dont reach a
             * distance up to our criteria */
            ip = ntest_x + sort_x;

            /* Stop the search if we reach dim*/
            if (ip >= dim) stopp = 1;

            if (stopp == 0) {
                curvp = (s_vvertice*) xsort[ip].data;

                /* Stop the search the distance on X is > dcrit*/
                if (curvp->x - vvalx > dcrit) stopp = 1;
                    /* Check if the current vertice has not already been counted */
                else if (curvp->seen == 0) {
                    if (dist(curvp->x, curvp->y, curvp->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, count and mark the vertice */
                        curvp->seen = 1;
                        nb_neigh++;
                    }
                }
            }

            im = sort_x - ntest_x;
            if (im < 0) stopm = 1;

            if (stopm == 0) {
                curvm = (s_vvertice*) xsort[im].data;

                /* Stop the search the distance on X is > dcrit*/
                if (vvalx - curvm->x > dcrit) stopm = 1;
                    /* Check if the current vertice has not already been counted */
                else if (curvp->seen == 0) {
                    /* OK we have an atom which is near our vertice on X, so
                     * calculate real distance */
                    if (dist(curvm->x, curvm->y, curvm->z, vvalx, vvaly, vvalz) < dcrit) {
                        /* Distance OK, count and mark the vertice */
                        curvm->seen = 1;
                        nb_neigh++;
                    }
                }
            }

            ntest_x += 1;
        }
    }

    return nb_neigh;
}
