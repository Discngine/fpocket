#include "../headers/topology.h"
/*
 * Copyright <2012> <Vincent Le Guilloux,Peter Schmidtke, Pierre Tuffery>
 * Copyright <2013-2018> <Peter Schmidtke, Vincent Le Guilloux>

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

 */
static molfile_plugin_t *api;
static int register_cb(void *v, vmdplugin_t *p) {
  api = (molfile_plugin_t *)p;
  return 0;
}


static const short n_mm_atom_type=35;

static const s_mm_atom_type_a mm_atom_type_ST[36] ={
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
    {"N*", 1.8240, 0.1700},
    {"C*", 1.9080, 0.0860}      //keep C* always as last element !
    
};


short get_ff_type(char *atom_type){
    int i;
    for(i=0;i<n_mm_atom_type;i++){
        
        if(strcmp(atom_type,mm_atom_type_ST[i].name)==0){
            return(i);
        }
        
    }
    if(atom_type[0]=='C') return(n_mm_atom_type-1);
    if(atom_type[0]=='N') return(n_mm_atom_type-2);
    return(-1);
}


s_topology *init_topology(void){
    s_topology *topol=my_malloc(sizeof(*topol));
    topol->natoms_topology=0;
    topol->topology_atoms=NULL;
    topol->ff_charge=NULL;
    topol->ff_mass=NULL;
    topol->ff_radius=NULL;
    
    
    return(topol);
}

void read_topology(char *topology_path, s_pdb *pdb){
        s_topology *topol=init_topology();
    
        int optflags[8] = {MOLFILE_INSERTION, MOLFILE_OCCUPANCY, MOLFILE_BFACTOR, MOLFILE_ALTLOC, MOLFILE_ATOMICNUMBER, MOLFILE_MASS, MOLFILE_CHARGE, MOLFILE_RADIUS};
        if(topology_path){
            molfile_parm7plugin_init();
            molfile_parm7plugin_register(NULL, register_cb);
        }
        int natoms,i;
        molfile_atom_t *atoms;
        printf("Reading topology\n");
        void *h_in;
        
        h_in=api->open_file_read(topology_path,"parm7",&natoms);          /*open the snapshot*/
        
        atoms=(void *)my_malloc(sizeof(molfile_atom_t)*(natoms));
        fprintf(stdout,"Successfully read %d atoms from topology %s \n",natoms,topology_path);
        
        topol->ff_charge=(float *)my_malloc(sizeof(float)*(natoms));
        topol->ff_radius=(float *) my_malloc(sizeof(float)*natoms);
        topol->ff_mass=(float *) my_malloc(sizeof(float)*natoms);
        topol->ff_type=(char **)my_malloc(natoms*sizeof(char*));
        for(i=0;i<natoms;i++){
                topol->ff_charge[i]=0.0;
                topol->ff_radius[i]=0.0;
                topol->ff_mass[i]=0.0;
//                topol->ff_type[i]=(char *)my_malloc(sizeof(char)*15);
                
        }
        //topol->ff_type=(char *) my_malloc(sizeof(char)*natoms);
        
//        fprintf(stdout,"Reading structure\n");
        
        api->read_structure(h_in, optflags, atoms);
//        fprintf(stdout,"atoms %s\n",atoms[0].resname);
        fflush(stdout);
        topol->natoms_topology=natoms;
        topol->topology_atoms=atoms;
        short ff_type_index;
        for(i=0;i<natoms;i++){
            
            if(i<pdb->natoms){// strcmp(pdb->latoms[i].name,atoms[i].name)==0 && strcmp(pdb->latoms[i].res_name,atoms[i].resname)==0){
                
                
                pdb->latoms[i].ff_charge=atoms[i].charge;
                pdb->latoms[i].ff_radius=atoms[i].radius;
                pdb->latoms[i].ff_mass=atoms[i].mass;
                pdb->latoms[i].ff_type=atoms[i].type;
                str_trim(pdb->latoms[i].ff_type);
                ff_type_index=get_ff_type(pdb->latoms[i].ff_type);
                
                if(ff_type_index>=0) {
                    pdb->latoms[i].ff_well_depth=mm_atom_type_ST[ff_type_index].w;
                    pdb->latoms[i].ff_well_depth_set=1;
                    if(pdb->latoms[i].ff_radius==0.0) pdb->latoms[i].ff_radius= mm_atom_type_ST[ff_type_index].radius;
                } 
                else {
                    fprintf(stderr,"not set %s %s \n",atoms[i].type,pdb->latoms[i].ff_type);
                       pdb->latoms[i].ff_well_depth_set=0;
                }
                
            }
            topol->ff_charge[i]=atoms[i].charge;
            topol->ff_radius[i]=atoms[i].radius;
            topol->ff_mass[i]=atoms[i].mass;
            topol->ff_type[i]=atoms[i].type; // PS : 01/06/2018 : dropped & to drop warning
//            printf("type %s\n",topol->ff_type[i]);
            //str_trim(topol->ff_type[i]);
//            fprintf(stdout,"mass : %f \t",topol->ff_mass[i]);
        }
        
 
        
        
}
