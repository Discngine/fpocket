#include "../headers/asa.h"

/*

## GENERAL INFORMATION
##
## FILE 					asa.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			01-04-08
##
## SPECIFICATIONS
##
##	Top function to call fpocket routines. Get and check programm parameters,
##	call functions, write output and free memory.
##
## MODIFICATIONS HISTORY
##
##	01-04-08	(p)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##
## TODO or SUGGESTIONS
##

*/

/*
    COPYRIGHT DISCLAIMER

    Vincent Le Guilloux, Peter Schmidtke and Pierre Tuffery, hereby
	claim all copyright interest in the program “fpocket” (which
	performs protein cavity detection) written by Vincent Le Guilloux and Peter
	Schmidtke.

    Vincent Le Guilloux  01 Decembre 2012
    Peter Schmidtke      01 Decembre 2012
    Pierre Tuffery       01 Decembre 2012

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
	atom_not_in_list

   ## SPECIFICATION:
	This function checks if the atom a is in the list of atoms "atoms"

   ## PARAMETRES:
	@ s_atm *a : The query atom,
	@ s_atm **atoms : The set of atoms to test
        @ int natoms : number of atoms in the set of atoms

   ## RETURN:
	1 if a is in atoms, 0 if not
 */
int atom_in_list(s_atm *a, s_atm **atoms, int natoms){
    int i;
    if(atoms){
        for(i = 0 ; i < natoms ; i++){
            if(atoms[i]==a) {
                if(atoms[i]->id != a->id) {
                    fprintf(stdout,"WARNING asa.c: atom in the list but with different ID!") ;
                }
                return 1;
            }
        }
    }
    return 0;
}


/**
   ## FUNCTION:
        get_surrounding_atoms_idx

   ## SPECIFICATION:
        Get atom ids around a given set of voronoi vertices

   ## PARAMETRES:
	@ s_vvertices **tvert : List of pointers to voronoi vertices,
	@ int nvert : Number of Voronoi vertices
        @ s_pdb *pdb : Structure of the protein
        @ int *n_sa : Pointer to int holding the number of surrounding atoms

   ## RETURN:
        int * : atom ids of surrounding atoms
 */

int *get_surrounding_atoms_idx(s_vvertice **tvert,int nvert,s_pdb *pdb, int *n_sa){
    s_atm *a=NULL;
    int *sa=NULL;
    int i,z,flag=0;
    *n_sa=0;
    for(i=0;i<pdb->natoms;i++){
        a=pdb->latoms_p[i];
        //consider only heavy atoms for vdw incr.
        if(strncmp(a->symbol,"H",1)){
            flag=0;
            for(z=0;z<nvert && !flag;z++){
                //flag=atom_not_in_list(a,sa,*n_sa);
                flag=in_tab(sa,*n_sa,i);
                if(!flag && ddist(a->x,a->y,a->z,tvert[z]->x,tvert[z]->y,tvert[z]->z)<(tvert[z]->ray+M_PADDING)*(tvert[z]->ray+M_PADDING)){
                    *n_sa=*n_sa+1;
                    if(sa==NULL){
                        sa=(int *)malloc(sizeof(int));
                        sa[*n_sa-1]=i;
                    }
                    else {
                        sa=(int *)realloc(sa,sizeof(int)*(*n_sa));
                        sa[*n_sa-1]=i;
                    }
                }
            }
        }
    }
    return sa;
}


/**
   ## FUNCTION:
        get_unique_atoms

   ## SPECIFICATION:
        Get a list of unique atom ids near the pocket

   ## PARAMETRES:
	@ s_vvertices **tvert : List of pointers to voronoi vertices,
	@ int nvert : Number of Voronoi vertices
        @ int *n_sa : Pointer to int holding the number of surrounding atoms
        @ s_atm **atoms : List of pointers to atoms
        @ int na : Number of atoms in atoms


   ## RETURN:
        int * : atom ids of unique atoms
 */

int *get_unique_atoms(s_vvertice **tvert,int nvert, int *n_ua, s_atm **atoms,int na){
    s_atm *a=NULL;
    int *ua=NULL;
    int z,j;
    int ca_idx;
    *n_ua=0;
    int flag=0;

    s_vvertice *vcur = NULL ;
    s_atm **neighs = NULL ;
/*
    fprintf(stdout, "\nIn get unique atom\n") ;
*/
    for(z=0;z<nvert;z++){
        vcur = tvert[z] ;
        neighs = tvert[z]->neigh ;
        for(j=0;j<4;j++){
            a=neighs[j];
            flag=in_tab(ua,*n_ua,a->id);
            if(!flag) {
                *n_ua=*n_ua+1;
                if(ua==NULL) ua=(int *)malloc(sizeof(int));
                else ua=(int *)realloc(ua,sizeof(int)*(*n_ua));
                
                if(a->id-1 < na && a==atoms[a->id-1]) {
                    ua[*n_ua-1]=a->id-1;
               /*     if(a->id >= 1631) {
                        fprintf(stdout, "\nSetting bad id! %d", a->id ) ;
                    }*/
                }
                else {
                    for(ca_idx=0;ca_idx<na;ca_idx++){
                        if(a==atoms[ca_idx]) {
                            ua[*n_ua-1]=ca_idx;

                 /*           if(ca_idx >= 1631) {

                                fprintf(stdout, "\nSetting bad id! %d", ca_idx ) ;
                            }*/
                            break;
                        }
                    }
                }
            }
        }
    }

    return ua;
}


s_atm **get_unique_atoms_DEPRECATED(s_vvertice **tvert,int nvert, int *n_ua)
{
    s_vvertice *vcur = NULL ;
    s_atm **neighs = NULL ;

    s_atm *a=NULL;
    s_atm **ua=(s_atm **) malloc(sizeof(s_atm*)*10);

    int tab_size = 10 ;
    int nb_ua = 0;
    int z = 0, j = 0;

    /* Loop over each vertice */
    for(z = 0 ; z < nvert ; z++){
        vcur = tvert[z] ;
        neighs = tvert[z]->neigh ;

        /* Loop over each vertice neighbors */
        for(j = 0 ; j < 4 ; j++) {
            a = neighs[j];
            if(atom_in_list(a, ua, nb_ua) == 0) {
                ua[nb_ua] = a;

                nb_ua = nb_ua + 1;
                if(nb_ua >= tab_size){
                    ua = (s_atm **) realloc(ua,sizeof(s_atm*)*(nb_ua+10));
                    tab_size += 10 ;
                }
            }
        }
    }

    *n_ua = nb_ua ;

    return ua;
}


/**
   ## FUNCTION:
        set_ASA

   ## SPECIFICATION:
        The actual ASA calculation, resulst are written to the descriptor
        structure

   ## PARAMETRES:
	@ s_desc *desc : Structure of descriptors
	@ s_pdb *pdb : Structure containing the protein
        @ s_vvertices **tvert : List of pointers to Voronoi vertices
        @ int nvert : Number of vertices


   ## RETURN:
        void
 */



void set_ASA(s_desc *desc,s_pdb *pdb, s_vvertice **tvert,int nvert)
{
    desc->surf_pol_vdw14=0.0;
    desc->surf_apol_vdw14=0.0;
    desc->surf_vdw14=0.0;
    desc->surf_vdw22=0.0;
    desc->surf_pol_vdw22=0.0;
    desc->surf_apol_vdw22=0.0;
    desc->n_abpa=0;
    float n_abpa_apol_sourrounding=0.0;
    float n_abpa_pol_sourrounding=0.0;
    int *sa=NULL;    /*surrounding atoms container*/
    /*int *ua=NULL;    unique atoms contacting vvertices*/
    s_atm ** ua = NULL ;
    
    int n_sa = 0;
    int n_ua = 0;
    int i;
    sa=get_surrounding_atoms_idx(tvert,nvert,pdb, &n_sa);
    /*ua=get_unique_atoms_DEPRECATED(tvert,nvert, &n_ua,pdb->latoms_p,pdb->natoms);*/

    ua=get_unique_atoms_DEPRECATED(tvert,nvert, &n_ua);
    float *abpatmp=NULL;
    abpatmp=(float *)my_malloc(sizeof(float)*n_ua);
/*
    for(i = 0 ; i < pdb->natoms ; i++) {
        if(pdb->latoms_p[i]->id > 1631) {
            fprintf(stdout, "\nWTF at %d %d", i,pdb->latoms_p[i]->id) ;
        }
    }
    for( i = 0 ; i < n_ua ; i++) {
        if(ua[i] > 1631)
            fprintf(stdout, "Atom %d: %d\n", i, ua[i]) ;

    }
*/

    s_atm *a,*cura;
    float *curpts=NULL,tz,tx,ty,dsq,area;
    int j=0,iv,k,burried,nnburried,vidx,vrefburried;
    curpts=get_points_on_sphere(M_NSPIRAL);
    for(i=0;i<n_ua;i++){
        n_abpa_pol_sourrounding=0;
        n_abpa_apol_sourrounding=0;
        abpatmp[i]=0.0;
/*
        fprintf(stdout, "\nUA %d (%d): %d (%d)", i, pdb->natoms, ua [i], n_ua);
*/
/*
        if(ua [i] >= pdb->natoms) {
            fprintf(stdout, "\nWOOPS at %d! %d \n", i, ua[i]) ;//exit(0) ;
        }
*/
/*
        cura=pdb->latoms_p[ua[i]];
*/
        cura = ua[i] ;
        nnburried=0;
        
        for(k=0;k<M_NSPIRAL;k++){
            burried=0;
            j=0;
            tx=cura->x+curpts[3*k]*(cura->radius+M_PROBE_SIZE);
            ty=cura->y+curpts[3*k+1]*(cura->radius+M_PROBE_SIZE);
            tz=cura->z+curpts[3*k+2]*(cura->radius+M_PROBE_SIZE);
            vrefburried=1;
            for(iv=0;iv<nvert;iv++){
                for(vidx=0;vidx<4;vidx++){
                    if(cura==tvert[iv]->neigh[vidx]){
                        if(ddist(tx,ty,tz,tvert[iv]->x,tvert[iv]->y,tvert[iv]->z)<=tvert[iv]->ray*tvert[iv]->ray) vrefburried=0;
                    }
                }
            }
            while(!burried && j< n_sa && !vrefburried){
                a=pdb->latoms_p[sa[j]];
                if(a!=cura){
                    dsq=ddist(tx,ty,tz,a->x,a->y,a->z);
                    if(dsq<(a->radius+M_PROBE_SIZE)*(a->radius+M_PROBE_SIZE)) {
                        burried=1;
                        if(a->electroneg<2.8) n_abpa_apol_sourrounding++;
                        else n_abpa_pol_sourrounding++;
                    }
                }
                
                j++;
            }
            if(!burried && !vrefburried) {
                nnburried++;
            }
        }
        area=(4*M_PI*(cura->radius+M_PROBE_SIZE)*(cura->radius+M_PROBE_SIZE)/(float)M_NSPIRAL)*nnburried;
        abpatmp[i]=area;
        if(cura->electroneg<2.8) {
            desc->surf_apol_vdw14=desc->surf_apol_vdw14+area;
        }
        else desc->surf_pol_vdw14=desc->surf_pol_vdw14+area;
        desc->surf_vdw14=desc->surf_vdw14+area;
        cura->abpa_sourrounding_prob=n_abpa_apol_sourrounding/(n_abpa_apol_sourrounding+n_abpa_pol_sourrounding);
    }
    
    

    /*now test with vdw +2.2*/
    for(i=0;i<n_ua;i++){
/*
        fprintf(stdout, "\nUA %d (%d): %d (%d)", i, pdb->natoms, ua [i], n_ua);
*/
/*
        if(ua [i] >= pdb->natoms) {
            fprintf(stdout, "\nWOOPS at %d! %d \n", i, ua[i]) ;//exit(0) ;
        }
*/
/*
        cura=pdb->latoms_p[ua[i]];
*/
        cura = ua[i] ;
        nnburried=0;

        for(k=0;k<M_NSPIRAL;k++){
            burried=0;
            j=0;
            tx=cura->x+curpts[3*k]*(cura->radius+M_PROBE_SIZE2);
            ty=cura->y+curpts[3*k+1]*(cura->radius+M_PROBE_SIZE2);
            tz=cura->z+curpts[3*k+2]*(cura->radius+M_PROBE_SIZE2);
            vrefburried=1;
            for(iv=0;iv<nvert;iv++){
                for(vidx=0;vidx<4;vidx++){
                    if(cura==tvert[iv]->neigh[vidx]){
                        if(ddist(tx,ty,tz,tvert[iv]->x,tvert[iv]->y,tvert[iv]->z)<=tvert[iv]->ray*tvert[iv]->ray) vrefburried=0;
                    }
                }
            }
            while(!burried && j< n_sa && !vrefburried){
                a=pdb->latoms_p[sa[j]];
                if(a!=cura){
                    dsq=ddist(tx,ty,tz,a->x,a->y,a->z);
                    if(dsq<(a->radius+M_PROBE_SIZE2)*(a->radius+M_PROBE_SIZE2)) burried=1;
                }
                j++;
            }
            if(!burried && !vrefburried) {
                nnburried++;
            }
        }
        area=(4*M_PI*(cura->radius+M_PROBE_SIZE2)*(cura->radius+M_PROBE_SIZE2)/(float)M_NSPIRAL)*nnburried;
        if(cura->electroneg<2.8) {
         
            desc->surf_apol_vdw22=desc->surf_apol_vdw22+area;
        }
        else {
            if(area<abpatmp[i] && abpatmp[i] <=10.0 && area >= 0.0){
                desc->n_abpa+=1;
                cura->abpa=1;
                //cura->abpa_sourrounding_prob=;
                
                cura->a0=abpatmp[i];
                cura->dA=area-abpatmp[i];
            }
            desc->surf_pol_vdw22=desc->surf_pol_vdw22+area;
        }
        
        desc->surf_vdw22=desc->surf_vdw22+area;
        
    }
    free(curpts);



    curpts=NULL;
   /* for(i=0;i<n_ua-1;i++){
        free(ua[i]);
    }*/
    
    free(ua);
    free(sa);
    my_free(abpatmp);

    sa=NULL;
    ua=NULL;
}

/**
   ## FUNCTION:
	get_points_on_sphere

   ## SPECIFICATION:
	This function takes an integer as argument and returns a unit sphere
        with distributed points on its surface according to the Golden Section
        Spiral Distribution

   ## PARAMETRES:
	@ int nop : number of points to create on the unit sphere (resolution of the surface)

   ## RETURN:
	float* : list of points on the unit sphere

*/

float *get_points_on_sphere(int nop) {
    float *pts =NULL;
    pts=(float *) malloc(sizeof (float) * nop * 3);
    float inc = M_PI * (3.0 - sqrt(5.0));
    float off = 2.0 / (float) nop;
    float y, r, phi;
    int k;
    for (k = 0; k < nop; k++) {
        y = ((float) k) * off - 1.0 + (off / 2.0);
        r = sqrt(1.0 - y * y);
        phi = k * inc;
        pts[3 * k] = cos(phi) * r;
        pts[3 * k + 1] = y;
        pts[3 * k + 2] = sin(phi) * r;
    }
    return pts;
}


