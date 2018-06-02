#include "../headers/write_visu.h"
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
## FILE 					write_visu.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			02-12-08
##
## SPECIFICATIONS
##
##		Write output script to launch visualization of fpocket output using
##		pymol and VMD.
##
## MODIFICATIONS HISTORY
##
##  01-12-12    (p)  Integrating modifications to VMD visualization as contributed by Chris MacDermaid
##  02-12-08    (v)  Comments UTD
##  29-11-08    (p)  Enhanced VMD output, corrected bug in pymol output
##  20-11-08    (p)  Just got rid of a memory issue (fflush after fclose) 
##	01-04-08	(v)  Added template for comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
## (v) Handle system command failure
##
*/

 
/**
   ## FUNCTION: 
	write_visualization
  
   ## SPECIFICATION: 
	Write visualization scripts for VMD and PyMol
  
   ## PARAMETERS:
	@ char *pdb_name     : pdb code
	@ char *pdb_out_name : name of the pdb output file
  
   ## RETURN: void
  
*/

void write_visualization(char *pdb_name,char *pdb_out_name)
{
	write_vmd(pdb_name,pdb_out_name);
 	write_pymol(pdb_name,pdb_out_name);
}

/**
   ## FUNCTION: 
	write_vmd
  
   ## SPECIFICATION: 
	Write visualization script for VMD
  
   ## PARAMETERS:
	@ char *pdb_name : pdb code
	@ char *pdb_out_name : name of the pdb output file
  
   ## RETURN: void
  
*/


void write_vmd(char *pdb_name,char *pdb_out_name)
{
	char fout[250] = "" ;
	char fout2[250] = "" ;
	char sys_cmd[250] ="";
	char c_tmp[255];
	int status ;
	
	strcpy(c_tmp,pdb_name);
	remove_ext(c_tmp) ;
	remove_path(c_tmp) ;
	FILE *f,*f_tcl;
	sprintf(fout,"%s_VMD.sh",pdb_name);
	f = fopen(fout, "w") ;
	if(f){
		sprintf(fout2,"%s.tcl",pdb_name);

		f_tcl=fopen(fout2,"w");
		if(f_tcl){
			/* Write bash script for visualization using VMD */
			fprintf(f,"#!/bin/bash\nvmd %s -e %s.tcl\n",pdb_out_name,c_tmp);
                        fflush(f);
			fclose(f);
			
			/* Make tcl script executable, and Write tcl script */
			sprintf(sys_cmd,"chmod +x %s",fout);
			status = system(sys_cmd);

			
			fprintf(f_tcl,"proc highlighting { colorId representation id selection } {\n");
			fprintf(f_tcl,"   puts \"highlighting $id\"\n");
   			fprintf(f_tcl,"   mol representation $representation\n");
                        fprintf(f_tcl,"   mol material \"Diffuse\" \n ");
   			fprintf(f_tcl,"   mol color $colorId\n");
   			fprintf(f_tcl,"   mol selection $selection\n");
   			fprintf(f_tcl,"   mol addrep $id\n}\n\n");
                        
                        
                        fprintf(f_tcl,"set id [mol new %s_out.pdb type pdb]\n",c_tmp);
			fprintf(f_tcl,"mol delrep top $id\n");
                        
   			fprintf(f_tcl,"highlighting Name \"Lines\" $id \"protein\"\n");
                        fprintf(f_tcl,"highlighting Name \"Licorice\" $id \"not protein and not resname STP\"\n");
                        fprintf(f_tcl,"highlighting Element \"NewCartoon\" $id \"protein\"\n");
                        fprintf(f_tcl,"highlighting \"ColorID 7\" \"VdW 0.4\" $id \"protein and occupancy>0.95\"\n");
                        
                        //fprintf(f_tcl,"mol new \"../%s.pdb\"\n",c_tmp);
                        fprintf(f_tcl,"set id [mol new %s_pockets.pqr type pqr]\n\
                        mol selection \"all\" \n \
                        mol material \"Glass3\" \n \
                        mol delrep top $id \n \
                        mol representation \"QuickSurf 0.3\" \n \
                        mol color ResId $id \n \
                        mol addrep $id \n",c_tmp);
                        fprintf(f_tcl,"highlighting Index \"Points 1\" $id \"resname STP\"\n");
                        fprintf(f_tcl,"display rendermode GLSL\n");
                        fclose(f_tcl);
		}
		else {
			fprintf(stderr, "! The file %s could not be opened!\n", fout2);
		}
	}
	else{
		fprintf(stderr, "! The file %s could not be opened!\n", fout);
	}

}

/**
   ## FUNCTION: 
	write_pymol
  
   ## SPECIFICATION: 
	write visualization script for PyMol
  
   ## PARAMETERS:
	@ char *pdb_name     : pdb code
	@ char *pdb_out_name : name of the pdb output file
  
   ## RETURN: void
  
*/
void write_pymol(char *pdb_name,char *pdb_out_name)
{
	char fout[250] = "" ;
	char fout2[250] = "" ;
	char sys_cmd[250] ="";
	FILE *f,*f_pml;
	char c_tmp[255];
	int status ;
	
	strcpy(c_tmp,pdb_name);
	remove_ext(c_tmp) ;
	remove_path(c_tmp) ;
	sprintf(fout,"%s_PYMOL.sh",pdb_name);
	f = fopen(fout, "w") ;
	if(f){
		sprintf(fout2,"%s.pml",pdb_name);
		f_pml=fopen(fout2,"w");
		if(f_pml){
			/* Write bash script for visualization using VMD */
			fprintf(f,"#!/bin/bash\npymol %s.pml\n",c_tmp);
                        fflush(f);
			fclose(f);
			
			sprintf(sys_cmd,"chmod +x %s",fout);
			status = system(sys_cmd);
			/* Write pml script */
			fprintf(f_pml,"from pymol import cmd,stored\n");
			fprintf(f_pml,"load %s\n",pdb_out_name);
			fprintf(f_pml,"#select pockets, resn STP\n");
   			fprintf(f_pml,"stored.list=[]\n");
   			fprintf(f_pml,"cmd.iterate(\"(resn STP)\",\"stored.list.append(resi)\")	#read info about residues STP\n");
   			fprintf(f_pml,"#print stored.list\n");
   			fprintf(f_pml,"lastSTP=stored.list[-1]	#get the index of the last residu\n");
   			fprintf(f_pml,"hide lines, resn STP\n\n");
			fprintf(f_pml,"#show spheres, resn STP\n");
			fprintf(f_pml,"for my_index in range(1,int(lastSTP)+1): cmd.select(\"pocket\"+str(my_index), \"resn STP and resi \"+str(my_index))\n");
			fprintf(f_pml,"for my_index in range(2,int(lastSTP)+2): cmd.color(my_index,\"pocket\"+str(my_index))\n");
   			fprintf(f_pml,"for my_index in range(1,int(lastSTP)+1): cmd.show(\"spheres\",\"pocket\"+str(my_index))\n");
   			fprintf(f_pml,"for my_index in range(1,int(lastSTP)+1): cmd.set(\"sphere_scale\",\"0.3\",\"pocket\"+str(my_index))\n");
   			fprintf(f_pml,"for my_index in range(1,int(lastSTP)+1): cmd.set(\"sphere_transparency\",\"0.1\",\"pocket\"+str(my_index))\n");
   			
			fclose(f_pml);
		}
		else {
			fprintf(stderr, "! The file %s could not be opened!\n", fout2);
		}
	}
	else{
		fprintf(stderr, "! The file %s could not be opened!\n", fout);
	}
}
