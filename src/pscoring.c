
#include "../headers/pscoring.h"

/*

## GENERAL INFORMATION
##
## FILE 					pscoring.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
## This file stores scoring functions for pockets.
##
## MODIFICATIONS HISTORY
##
##	21-01-09	(v) Added new scoring function
##	28-11-08	(v) Created + Comments UTD
##	
## TODO or SUGGESTIONS
##
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
        score_pocket2
  
   ## SPECIFICATION: 
        Set a score to a given pocket. The current scoring function has been determined
        using a logistic regression based on an analysis of pocket descriptors.

  
   ## PARAMETRES:
        @ s_pocket *pocket: The pocket
  
   ## RETURN:
        float: The score
  
 */
float score_pocket(s_desc *pdesc) {
    float score;

    /**
     * Data to use for mean-center normalization step: N = 2
     *                     MEAN     SD
     * nas_norm            0.183    0.243
     * apol_asprop_norm    0.402    0.259
     * mean_loc_hd_norm    0.334    0.261
     * polarity_score      7.193    4.197
     * polarity_score_norm 0.291    0.242
     * as_density          5.194    1.707
     * as_density_norm     0.387    0.252
     *
     */

    /*
            Using m 3.0 M 6.0 D 1.73 i 25 we have for the training set this PLS model
            having 4 components

            CURRENT !!!!!!!!!!!!!!!!! SCORING 1
     */
    /*
            Perf:
            Scoring function 1:
                              CPP     OVL
            Data      T1/T3 | T1/T3
	
            Train   : 62/86 - 65/89
            PP holo : 79/92 - 79/90
            PP apo  : 69/90
            Cheng   : 70/85 - 70/100
            Gold    : 69/90 - 71/90
     */


//    score =
//            -1.50335
//            + 30.27950 * (float) pdesc->nas_norm
//            - 3.40435 * (float) pdesc->prop_asapol_norm
//            + 11.04704 * (float) pdesc->mean_loc_hyd_dens_norm
//            + 1.18610 * (float) pdesc->polarity_score
//            - 2.01214 * (float) pdesc->as_density;

    score =
            -0.65784
            + 29.78270 * (float) pdesc->nas_norm
            - 4.06632 * (float) pdesc->prop_asapol_norm
            + 11.72346 * (float) pdesc->mean_loc_hyd_dens_norm
            + 1.16349 * (float) pdesc->polarity_score
            - 2.06835 * (float) pdesc->as_density;


    /*
            Using m 3.0 M 6.0 D 1mean_loc_hyd_dens_norm.73 i 25 n 2 we have for the training set this PLS model
            having 4 components

             SCORING 2
     */
    /*
            Perf:
            Scoring function 1:
                              CPP     OVL
            Data      T1/T3 | T1/T3
	
            Train   : 62/86 - 65/89
            PP holo : 79/92 - 79/90
            PP apo  : 69/90
            Cheng   : 70/85 - 70/100
            Gold    : 69/91 - 71/90
     */

    /*
            score =
            -0.65784
           +29.78270 * (float)pdesc->nas_norm
            -4.06632 * (float)pdesc->prop_asapol_norm
           +11.72346 * (float)pdesc->mean_loc_hyd_dens_norm
            +1.16349 * (float)pdesc->polarity_score
            -2.06835 * (float)pdesc->as_density ;
     */
    /*
            Using m 3.0 M 6.0 D 1mean_loc_hyd_dens_norm.73 i 25 n 3 we have for the training set this PLS model
            having 4 components

             SCORING 3
     */
    /*
            Perf:
            Scoring function 1:
                              CPP     OVL
            Data      T1/T3 | T1/T3
	
            Train   : 59/84 - 64/89
            PP holo : 79/94 - 81/94
            PP apo  : 69/90
            Cheng   : 70/85 - 75/100
            Gold    : 71/91 - 72/89
     */

    /*
            score =
            -1.48906
           +29.54059 * (float)pdesc->nas_norm
           +10.73666 * (float)pdesc->mean_loc_hyd_dens_norm
            -3.30562 * (float)pdesc->prop_asapol_norm
            +1.15711 * (float)pdesc->polarity_score
            -1.94912 * (float)pdesc->as_density ;
     */

    /*	ON GOLD
            Using m 3.0 M 6.0 D 1mean_loc_hyd_dens_norm.73 i 25 n 2 we have for the training set this PLS model
            having 4 components

             SCORING 4
     */
    /*
            Perf:
            Scoring function 1:
                              CPP     OVL
            Data      T1/T3 | T1/T3
	
            Train   : 59/84 - 64/89
            PP holo : 79/94 - 81/94
            PP apo  : 71/90
            Cheng   : 70/85 - 75/100
            Gold    : 69/91 - 71/90
     */

    /*
            score =
            -1.29456
           +33.45117 * (float)pdesc->nas_norm
           +17.78868 * (float)pdesc->mean_loc_hyd_dens_norm
            -5.23046 * (float)pdesc->prop_asapol_norm
            +1.07977 * (float)pdesc->polarity_score
            -2.00073 * (float)pdesc->as_density ;
     */

    /*	ON GOLD
            Using m 3.0 M 6.0 D 1mean_loc_hyd_dens_norm.73 i 25 n 3 we have for the training set this PLS model
            having 4 components

             SCORING 5
     */

    /*
            Perf:
            Scoring function 1:
                              CPP     OVL
            Data      T1/T3 | T1/T3
	
            Train   : 62/86 - 65/89
            PP holo : 79/90 - 79/88
            PP apo  : 67/90
            Cheng   : 70/85 - 70/100
            Gold    : 70/91 - 71/90
     */
    /*

            score =
             -2.29256
           +33.86433 * (float)pdesc->nas_norm
           +17.55332 * (float)pdesc->mean_loc_hyd_dens_norm
            -4.90910 * (float)pdesc->prop_asapol_norm
            +1.11252 * (float)pdesc->polarity_score
            -1.88681 * (float)pdesc->as_density;
     */

    /*
            score =
            -0.04719
           +27.28918 * (float)pdesc->nas_norm
            -3.28306 * (float)pdesc->prop_asapol_norm
           +11.24130 * (float)pdesc->mean_loc_hyd_dens_norm
            +1.24804 * (float)pdesc->polarity_score
            -2.63044 * (float)pdesc->as_density
            +5.42051 * (float)pdesc->as_max_dst_norm ;
     */

    /*
    AVGAUC 0.9964742         0.0009241223   EXTAUC   0.9954173       nb_AS_norm+as_density+convex_hull_volume+surf_pol_vdw14+surf_apol_vdw14 
83  druggable pockets vs  1042 
          (Intercept) nb_AS_norm as_density convex_hull_volume surf_pol_vdw14
meanCoefs -0.03783394 0.48461469 0.09093926       0.0004155899   -0.003995233
          -0.38101212 0.05272438 0.04973804       0.1796027083   -0.045518871
          surf_apol_vdw14
meanCoefs    -0.004072336
             -0.046469110
    */
    
score =
            -0.03783394
            + 0.48461469 * (float) pdesc->nas_norm
            + 0.09093926 * (float) pdesc->as_density
            + 0.0004155899 * (float) pdesc->convex_hull_volume
             -0.003995233 * (float) pdesc->surf_pol_vdw14
             -0.004072336 * (float) pdesc->surf_apol_vdw14;

    return score;
}

/**
   ## FUNCTION:
        drug_score_pocket

   ## SPECIFICATION:
        Set a drug score to a given pocket. The current scoring function has been determined
        using a logistic regression based on an analysis of pocket descriptors.


   ## PARAMETRES:
        @ s_desc *pdesc: The pocket descriptors

   ## RETURN:
        float: The score

 */
float drug_score_pocket(s_desc *pdesc) {


    //	float score ;
    //        float l1,l2,l3;
    //        float b10=-5.140959;
    //        float b11=6.579424;
    //        float b20=-2.668468;
    //        float b21=0.05581948;
    //        float b30=-2.445236;
    //        float b31=2.762473 ;
    //        float b0=-6.238031;
    //        float b1= 4.592376 ;
    //        float b2= 5.717858;
    //        float b3= 3.985070;
    //        l1=exp(b10+b11*(float)pdesc->mean_loc_hyd_dens_norm)/(1.0+exp(b10+b11*(float)pdesc->mean_loc_hyd_dens_norm));
    //        l2=exp(b20+b21*(float)pdesc->hydrophobicity_score)/(1.0+exp(b20+b21*(float)pdesc->hydrophobicity_score));
    //        l3=exp(b30+b31*(float)pdesc->polarity_score_norm)/(1.0+exp(b30+b31*(float)pdesc->polarity_score_norm));
    //
    //        score=exp(b0+b1*l1+b2*l2+b3*l3)/(1.0+exp(b0+b1*l1+b2*l2+b3*l3));
    //        

    /*        Avg AUC :  0.9816682  ::  0.005729263  for :  nb_AS+mean_loc_hyd_dens+surf_apol_vdw14 
                    21  druggable pockets vs  434 
                                 (Intercept) nb_AS          mean_loc_hyd_dens   surf_apol_vdw14
                    meanCoefs   -5.942568 0.1105141         0.1995158      -0.1281088
                                -0.104561 0.1950147         0.1788811      -0.1643329
     */
    
    
    //Avg AUC :  0.9702868  ::  0.009916588  for :  mean_loc_hyd_dens_norm+surf_apol_vdw22 
    //18  druggable pockets vs  68 
    //External AUC :  0.9776215 
    //          (Intercept) mean_loc_hyd_dens_norm surf_apol_vdw22
    //meanCoefs   -5.424089              9.6381209      -0.1008210
    //            -0.238034              0.2337366      -0.3507961
//    float b0 = -5.424089;
//    float b1 = 9.6381209;
//    float b2 = -0.1008210;
    
//    float score = 1.0 / (1.0 + exp(-(b0 + b1 * (float) pdesc->mean_loc_hyd_dens_norm + b2 * (float) pdesc->surf_apol_vdw22)));
//    fprintf(stdout, "drug score %.3f\n", score);
//    fflush(stdout);
    
    //    float b0 = -5.424089;
//    float b1 = 9.6381209;
//    float b2 = -0.1008210;
    
    
    
    
//    Avg AUC :  0.9855209  ::  0.003909686  for :  mean_loc_hyd_dens_norm+as_max_dst+surf_pol_vdw22 
//21  druggable pockets vs  292 
//External AUC :  0.9714854 
//          (Intercept) mean_loc_hyd_dens_norm as_max_dst surf_pol_vdw22
//meanCoefs  -9.5698768               7.479844  0.3696134    -0.04671833
//           -0.1315622               0.132979  0.3051646    -0.29385810
    float b0=-9.5698768;
    float b1=7.479844;
    float b2=0.3696134;
    float b3=-0.04671833;
    float score = 1.0 / (1.0 + exp(-(b0 + b1 * (float) pdesc->mean_loc_hyd_dens_norm + b2 * (float) pdesc->as_max_dst+b3*(float)pdesc->surf_pol_vdw22)));
    fprintf(stdout,"%.3f\t%.3f\t%.3f\n",(float) pdesc->mean_loc_hyd_dens_norm,(float) pdesc->as_max_dst,(float)pdesc->surf_pol_vdw22);
    
    return score;

}
