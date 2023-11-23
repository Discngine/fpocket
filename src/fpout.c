
#include "../headers/fpout.h"
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
## FILE 					fpout.h
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##	Write output for fpocket.
##
## MODIFICATIONS HISTORY
##
##	12-02-09	(v)  No more pocket.info output (useless...)
##	15-12-08	(v)  Minor bug corrected (output dir in the current dir...)
##	28-11-08	(v)  Last argument of write_out_fpocket changed to char *
##					 Comments UTD
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
##
##	(v) Handle system command failure, clean!

*/

/**
   ## FUNCTION:
	write_out_fpocket
  
   ## SPECIFICATION:
	Output routine. See the documentation for more information.
  
   ## PARAMETRES:
 *  @ c_lst_pockets *pockets : All pockets found and kept.
 *  @ s_pdb *pdb : The (input) pdb structure
	@ char *pdbname          : Name of the pdb
  
   ## RETURN: 
	void

*/
extern char write_mode[10];
void write_out_fpocket(c_lst_pockets *pockets, s_pdb *pdb, char *pdbname)
{
   char pdb_code[350] = "";
   char pdb_path[350] = "";
   char out_path[350] = "";
   char pdb_out_path[350] = "";
   char info_out_path[350] = "";
   char mmcif_out_path[350] = "";
   char fout[350] = "";
   char command[370] = "";
   int status;

   if (pockets) {
      /* Extract path, pdb code... */
      strcpy(pdb_code, pdbname);
      extract_path(pdbname, pdb_path);
      remove_ext(pdb_code);
      remove_path(pdb_code);

      if (strlen(pdb_path) > 0) {
         sprintf(out_path, "%s/%s_out", pdb_path, pdb_code);
      } else {
         sprintf(out_path, "%s_out", pdb_code);
      }

      sprintf(command, "mkdir -p %s", out_path);
      status = system(command);
      if (status != 0) {
         return;
      }

      sprintf(out_path, "%s/%s", out_path, pdb_code);
      sprintf(pdb_out_path, "%s_out.pdb", out_path);
      sprintf(mmcif_out_path, "%s_out.cif", out_path);

      /* Write vmd and pymol scripts */
      sprintf(fout, "%s_out.pdb", pdb_code);
      write_visualization(out_path, fout);

      /* Writing full pdb */
      if (write_mode[0] == 'p' || write_mode[0] == 'b') {
         sprintf(pdb_out_path, "%s_out.pdb", out_path);
         write_pockets_single_pdb(pdb_out_path, pdb, pockets);
      }

      /* Writing full mmcif */
      if (write_mode[0] == 'm' || write_mode[0] == 'b') {
         sprintf(mmcif_out_path, "%s_out.cif", out_path);
         write_pockets_single_mmcif(mmcif_out_path, pdb, pockets);
      }

      sprintf(info_out_path, "%s_info.txt", out_path);
      write_out_fpocket_info_file(pockets, info_out_path);

      /* Writing pockets as a single pqr */
      sprintf(fout, "%s_pockets.pqr", out_path);
      write_pockets_single_pqr(fout, pockets);

      /* Writing individual pockets pqr */
      if (strlen(pdb_path) > 0) {
         sprintf(out_path, "%s/%s_out", pdb_path, pdb_code);
      } else {
         sprintf(out_path, "%s_out", pdb_code);
      }

      sprintf(out_path, "%s/pockets", out_path);
      sprintf(command, "mkdir %s", out_path);
      status = system(command);


      write_each_pocket(out_path, pockets);
   }
}
/**
   ## FUNCTION:
	write_out_fpocket_info_file

   ## SPECIFICATION:
        Writing the pocket information file to the output directory, as a json record

   ## PARAMETRES:
 *  @ c_lst_pockets *pockets : All pockets found and kept.
 *  @ char *output_file_name : The filename of the output file

   ## RETURN:
	void

*/
void write_out_fpocket_info_file(c_lst_pockets *pockets, char *output_file_name) {
   FILE *f = NULL;
   f = fopen(output_file_name, "w");
   node_pocket *pcur = NULL;
   s_desc *pdesc = NULL;
   int i = 0;
   fprintf(f, "[");
   if (pockets) {
      pcur = pockets->first;
      while (pcur) {
         if (i > 0) {
            fprintf(f, ",");
         }
         pdesc = pcur->pocket->pdesc;
         fprintf(f, "{");
         fprintf(f, "\"Pocket\":%d", i + 1);
         fprintf(f, ",\"Score\":%.5f", pcur->pocket->score);
         fprintf(f, ",\"Druggability Score\":%.5f", pdesc->drug_score);
         fprintf(f, ",\"Number of Alpha Spheres\":%d", pcur->pocket->size);
         fprintf(f, ",\"Total SASA\":%.5f", pdesc->surf_vdw14);
         fprintf(f, ",\"Polar SASA\":%.5f", pdesc->surf_pol_vdw14);
         fprintf(f, ",\"Apolar SASA\":%.5f", pdesc->surf_apol_vdw14);
         fprintf(f, ",\"Volume\":%.5f", pdesc->volume);
         fprintf(f, ",\"Mean local hydrophobic density\":%.5f", pdesc->mean_loc_hyd_dens);
         fprintf(f, ",\"Mean alpha sphere radius\":%.5f", pdesc->mean_asph_ray);
         fprintf(f, ",\"Mean alp. sph. solvent access\":%.5f", pdesc->masph_sacc);
         fprintf(f, ",\"Apolar alpha sphere proportion\":%.5f", pdesc->apolar_asphere_prop);
         fprintf(f, ",\"Hydrophobicity score\":%.5f", pdesc->hydrophobicity_score);
         fprintf(f, ",\"Volume score\": %.5f", pdesc->volume_score);
         fprintf(f, ",\"Polarity score\":%d", pdesc->polarity_score);
         fprintf(f, ",\"Charge score\":%d", pdesc->charge_score);
         fprintf(f, ",\"Proportion of polar atoms\":%.5f", pdesc->prop_polar_atm);
         fprintf(f, ",\"Alpha sphere density\":%.5f", pdesc->as_density);
         fprintf(f, ",\"Cent. of mass - Alpha Sphere max dist\":%.5f", pdesc->as_max_dst);
         fprintf(f, ",\"Flexibility\":%.5f", pdesc->flex);
         fprintf(f, "}");

         pcur = pcur->next;
         i++;
      }
   } else {
      fprintf(f, "{\"Error\":\"No pockets found\"}");
   }
   fprintf(f, "]");
}

/**-----------------------------------------------------------------------------
   ## FUNCTION:
	void write_out(c_lst_pockets *pockets)
   -----------------------------------------------------------------------------
   ## SPECIFICATION:
	Output routine.
   -----------------------------------------------------------------------------
*/
void write_out_fpocket_DB(c_lst_pockets *pockets, s_pdb *pdb, char *input_name) {
   char pdb_code[350] = "";
   char pdb_path[350] = "";
   char out_path[350] = "";
   char pdb_out_path[350] = "";
   char command[370] = "";

   if (pockets) {
      // Extract path, pdb code...
      strcpy(pdb_code, input_name);
      extract_path(input_name, pdb_path);
      remove_ext(pdb_code);
      remove_path(pdb_code);
      /*sprintf(out_path, "%s/%s_out", pdb_path, pdb_code) ;*/
      if (strlen(pdb_path) > 0) {
         sprintf(out_path, "%s/%s_out", pdb_path, pdb_code);
      } else {
         sprintf(out_path, "%s_out", pdb_code);
      }

      sprintf(command, "mkdir -p %s", out_path);
      int status = system(command);
      // Writing full pdb
      sprintf(pdb_out_path, "%s_out.pdb", out_path);

      write_each_pocket_for_DB(out_path, pockets, pdb);
      //write_each_matrix(out_path,pockets);
   }
}

void write_descriptors_DB(c_lst_pockets *pockets, FILE *f) {
   /*Todo adapt things here*/

   int n = 1;
   s_pocket *p;
   node_pocket *npcur;
   npcur = pockets->first;
   int r = 1, i;
   fprintf(f, "cav_id drug_score volume nb_asph inter_chain apol_asph_proportion mean_asph_radius "
              "as_density mean_asph_solv_acc mean_loc_hyd_dens flex hydrophobicity_score volume_score charge_score "
              "polarity_score a0_apol a0_pol af_apol af_pol n_abpa "
              "ala cys asp glu phe gly his ile lys leu met asn pro gln arg ser thr val trp tyr "
              "chain_1_type chain_2_type num_res_chain_1 "
              "num_res_chain_2 lig_het_tag name_chain_1 name_chain_2\n");
   while (npcur) {
      p = npcur->pocket;
      fprintf(f, "%d %.4f %.4f %d %d %.4f %.4f", r, p->pdesc->drug_score, p->pdesc->volume,
              p->pdesc->nb_asph, p->pdesc->interChain, (float)p->nAlphaApol / (float)p->pdesc->nb_asph, p->pdesc->mean_asph_ray);
      fprintf(f, " %.4f %.4f %.4f %.4f %.4f %.4f %d", p->pdesc->as_density, p->pdesc->masph_sacc, p->pdesc->mean_loc_hyd_dens, p->pdesc->flex, p->pdesc->hydrophobicity_score,
              p->pdesc->volume_score, p->pdesc->charge_score);
      fprintf(f, " %d %.4f %.4f %.4f %.4f %d", p->pdesc->polarity_score, p->pdesc->surf_apol_vdw14, p->pdesc->surf_pol_vdw14,
              p->pdesc->surf_apol_vdw22, p->pdesc->surf_pol_vdw22, p->pdesc->n_abpa);
      for (i = 0; i < 20; i++) {
         fprintf(f, " %d", p->pdesc->aa_compo[i]);
      }

      fprintf(f, " %d %d %d %d %s %s %s", p->pdesc->characterChain1, p->pdesc->characterChain2, p->pdesc->numResChain1, p->pdesc->numResChain2, p->pdesc->ligTag, p->pdesc->nameChain1, p->pdesc->nameChain2);
      //fprintf(f,"%s %s %s",p->pdesc->nameChain1,p->pdesc->nameChain2);
      fprintf(f, "\n");
      fflush(f);

      npcur = npcur->next;
      n++;
      r++;
   }
}
