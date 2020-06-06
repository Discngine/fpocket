# Getting started

#### Quicklinks:

* [fpocket basics](#fpocket-simple-pocket-detection)
* [mdpocket basics](#mdpocket-pocket-detection-on-md-trajectories)
* [dpocket basics](#dpocket-descriptor-extraction)
* [tpocket basics](#tpocket-scoring-ranging-and-evaluation)

## fpocket - simple pocket detection

To run the following examples, we use several sample input file `data/sample/` directory). 

### Example

Here you have a very simple and straightforward example of how to run fpocket on a single PDB file downloaded from the RCSB PDB. The following command line will execute fpocket on the 1UYD.pdb file situated in the sample directory.

`fpocket -f sample/1UYD.pdb`

It is mandatory to give a PDB input file using the -f flag in command line. If nothing is given, fpocket prints the fpocket usage/help to the screen. fpocket will use standard parameters for the detection of pockets. Fore more information about these parameters see the [advanced fpocket features](#fpocket-advanced).

If fpocket works properly the output on the screen should look like this :
```bash
=========== Pocket hunting begins ==========
=========== Pocket hunting ends ============
```

If you have a look now in the sample directory, you will notice that fpocket created a folder named 1UYD_out/. This folder contains all the output from fpocket, so what you are actually interested in. If you just want to see rapidly the results, go to the 1UYD_out directory and launch the 1UYD_VMD.sh script. This script will launch the VMD molecular visualizer and load the protein with binding site information coming from fpocket.

![VMD with fpocket output](images/vmd1.png)

The illustration above is somehow what you will see if you launch the VMD script. VMD is well suited for representing the volume of alpha spheres and their respective centers. Usually the visual volume information is not of primordial importance, as the larger alpha spheres tend to reach far out of the protein and smaller alpha spheres are not visible because they are recovered by larger ones. As it can be seen within the Main VMD window, the visualization script loads 3 structures, all of them are explained in more detail in the output section of this chapter.

If you had a closer look before on the methodological aspects of this algorithm (we invite you to read the paper) a natural question would be how to represent apolar and polar alpha spheres. Currently the color code represents only the residue ID (rank of the cavity). If you want to see characteristics of alpha spheres we invite you to change the representation of alpha spheres. This can be found by clicking Graphics -> Representations. Another window will show up. There you select the first molecule (1UYD_out.pdb), like represented on the figure below.

![VMD representations](images/vmd2.png)

A script for fast visualization using PyMOL is also provided. PyMOL provides nice features browsing and selecting different pockets, using the predefined selection patterns on the right side of the main window. However, PyMOL does not interpret well the pqr file format, so alpha sphere volumes are not accurate and only alpha sphere centers can be shown.

![VMD representations](images/pymol1.png)

### Basic input

#### Mandatory (1 OR 2):

	1: flag -f :    one standard PDB file name.
	2: flag -F :    one text file containing a simple list of pdb path

#### Optional:
For more details on optional fpocket arguments see [advanced fpocket features](#fpocket-advanced).


### Output
Fpocket output is made of many files. To have a detailed overview of those files, see [advanced fpocket features](#fpocket-advanced).

Is there something else? No, you are done. Congratulations, you have successfully performed your first pocket prediction with fpocket...without any accidents we hope. As you might have seen, usage of fpocket is rather simple, although it is command line based software. Furthermore you should have seen that fpocket is very fast, well, lets say if you do not run it on a P1 100Mhz.
As mentioned before, fpocket provides much more possibilities especially for filtering out unwanted pockets, clustering of alpha spheres. For all these issues and usage of these more advanced features, refer to [advanced fpocket features](#fpocket-advanced)



## mdpocket pocket detection on MD trajectories

The fpocket developer team is proud to present a very new feature as part of the fpocket software package. As programmers are very creative people, as you might know, we called this program mdpocket, as acronym of Molecular Dynamics pocket (very original isn't it?). In the next paragraphs we will refer to Molecular Dynamics as MD.

Well, mdpocket is a freely available software that allows you to do the following very nice things in a quite fast way :

* pocket detection on MD trajectories (I already said this one)
* visualization of transient pockets (oh, will we have all the Pharma people on our back?)
* extraction of pocket descriptors during the MD trajectory (like pocket volume for example)
* get a static image of pocket occurrences during the MD trajectory (this you do not necessarily see the usefulness, but this will become clearer later)
* perform on the fly energy calculations within a detected pocket

If you are already used to run and analyze MD trajectories you know that there is a bunch of different software available to perform calculation and analysis of MD trajectories. Mdpocket is able to read plain PDB files describing the conformations of a protein, but now you can also read Amber crd files, gromacs xtc, netcdf and charmm and Namd dcd files (that was a nightmare to integrate and compile, so please make use of it).

### Example
It is VERY IMPORTANT to first align (superimpose) all snapshots onto each other. Why? Well, you have to do this due to the methodology used behind mdpocket. For more information on how mdpocket works feel free to read the mdpocket paper:
(http://bioinformatics.oxfordjournals.org/content/27/23/3276.long)

Below is an example for Amber for instance, but you can do the same with gromacs tools, mdtraj in python or in VMD analyzing NAMD trajectories for instance:

 With Amber you can do the structural alignment and transformation using the freely available ptraj or cpptraj program and the following steps:

- 1: create a ptraj input file with the following content :

        trajin ../md_1.x.gz 1 250 10
        trajin ../md_2.x.gz 1 250 10
        trajin ../md_3.x.gz 1 250 10
        reference ../reference.pdb
        strip !:1-208
        rms reference :25-88,120-196@CA,C,N,O
        trajout trajectory_superimposed.dcd charmm
        go
- 2: 	Run ptraj using the following command:
`ptraj your_topology.top < ptraj_input_file.ptr`

A few words about what we are doing here. First, the ptraj input reads trajectory files. In this example, the trajectory is split up in 3 files. Each file has 250 snapshots. Here we only read every tenth snapshot of the 250. We set a reference PDB structure for the alignment.

The strip command allows you to drop residues, here everything other than the protein (solvent, counter ions etc...).

Next, we align each snapshot on the reference structure, using only the heavy atoms of residues 25-88 and 120 to 196.

The output is written to trajectory_superimposed.dcd. Here we write a dcd file just for demonstration purposes, you can write mdcrd or netcdf files as well with ptraj.

Now, here we are, we can run mdpocket (finally...):

`mdpocket --trajectory_file trajectory_superimposed.dcd --trajectory_format dcd -f reference.pdb`

NB: you still have to provide a pdb file containing the actual topology of the structure as most of the supported MD formats only store coordinates, but no information on the actual atom & residue types of the structure.

The following part will take a while, depending on the number of atoms in your system and the number of snapshots you analyze. In average on a sample MD of 4000 snapshots (3258 atoms) 0.4 seconds of calculation time were necessary for analysis of 1 snapshot on one core of a 2.66Ghz Intel Quad with 4Gb of RAM.  

Mdpocket will print out some things and the actual status of advance of the calculation. Once finished you will be able to find the following output files in your current folder :

* `mdpout_freq_grid.dx`: This is an output grid file. The grid contains only a measure of frequency of how many times the pocket was open during a MD trajectory. This, averaged by the number of snapshots, gives a range of possible iso-values between 0 and 1. Currently we provide both types of grid files (frequency & density, as both have proven their usefulness during in-house studies. However, the frequency grid file is usually much easier to interpret.
This representation gives you already a lot of information especially about existing paths during a MD. For mechanistic studies this can often be enough, However, if you want to do measurements of the volume (for example) of a certain pocket you have to select this region first. As VMD and the grid file are not really suitable for selection, mdpocket provides two last output files called :

* `mdpout_dens_grid.dx`: This is one of the two grid output files coming from mdpocket. Briefly, a grid is superposed to all alpha spheres of all snapshots and the number of alpha spheres around each grid point is counted. This output is very useful as working file for a first crude visualization using PyMOL or VMD. In the following example we will show VMD as the visualization of grids is easier and less heavy with it. Open VMD and load the DX file. You should have something like this (colors are different) :

![VMD with mdpocket output](images/vmd3.png)

Well, this is nice, but you can hardly see anything interpretable in there. In order to see more clearly we recommend to change the representation by going to Graphics -> Representations as shown in the following illustration:

![VMD with mdpocket output](images/vmd4.png)

Now you basically can play with the Isovalue slider to get more or less conserved cavities during the MD trajectory. The unit of this isovalue can be expressed as number of Voronoi Vertices (alpha sphere centers) in a 8Å3 cube around each grid point per snapshot. The more a cavity is conserved (or dense) the higher this value. Thus, you will usually get internal pockets and protein internal channels. If you are interested in very superficial or transient binding sites you should decrease the isovalue until you see it.

* `mdpout_dens_iso_8.pdb`: This file contains all grid points having 3 or more Voronoi Vertices in the 8A3 volume around the grid point for each snapshot. Using PyMOL you can now select and save only the grid points of the pocket you are interested in. Save these points to another pdb file. Let us call this file my_pocket.pdb. The choice of the correct grid points for your pocket definition depends completely on you. As rule of a thumb we would recommend to use a high (like 5) isovalue if you want to show open channels in a protein or protein internal binding pockets. You should lower this isovalue (maybe to 2 or 3) if you are interested in transient phenomena (opening, closing of paths, transient pockets etc...). Refer to advanced features to know how to extract these pdb files with other iso values.

* `mdpout_freq_iso_0_5.pdb`: This is similar to the previous pdb file, just being produced on the frequency grid with a cut-off of 0.5.

In order to measure the pocket around your previously defined pocket during the MD trajectory you have to rerun mdpocket in a slightly different way:

`mdpocket --trajectory_file trajectory_superimposed.dcd --trajectory_format dcd -f reference.pdb --selected_pocket my_pocket.pdb`

As you can see, now you have to pass your pocket definition using the --selected_pocket flag of mdpocket. To see how to define your pocket, see the section [Pocket Selection](#pocket-selection). The -v flag is optional, it is just to provide reasonably good volume calculations in a reasonably good execution time. As during the first mdpocket run you should see some output first and the advancement of mdpocket through all you snapshots. Once finished you will find some other output files in your folder:

* `mdpout_mdpocket.pdb`: This is a pdb file that contains all Voronoi vertices in the selected pocket zone for each snapshot. Each snapshot is handled as separated model (like a NMR structure) and can thus be viewed as MD using PyMOL. Show the surface of the vertices and you can visualize the movement of your pocket. Be careful, VMD does not read this file, as from one snapshot to the other a different number and type of Voronoi vertices can be part of the model.

* `mdpout_mdpocket_atoms.pdb`: This is a pdb file similar to the previous output, but this time containing all receptor atoms defining the binding pocket.

* `mdpout_descritpors.txt`: Last but not least, maybe the most important file containing the pocket descriptors. You will find for each snapshot the pocket volume, the number of alpha spheres and all other default fpocket descriptors:

        snapshot 	pock_volume 	nb_AS 	mean_as_ray ...
        1 		793.47 		183 		3.76
        2 		726.95 		158 		3.86
        3 		711.87 		213 		3.59
        4 		700.82 		172 		3.61
        5 		762.24 		196 		3.85
        6 		618.31 		193 		3.77

This output file can be easily analyzed using R, gnuplot or other suitable software. An example R output for the pocket volume would be:

![Pocket volume plot](images/volume.png)

If you want to reproduce this, simply launch R and type:

```R
r=read.table("mdpout_descriptors.txt",h=T)
ylim=c(400,1200)
plot(r[,"pock_volume"],ty='l',ylim=ylim,main="",xlab="",ylab="")
par(new=T)
plot(smooth.spline(r[,"pock_volume"],df=40),col="red",lwd=3,ylim=ylim,ty="l",xlab="snapshot",ylab="volume")
```

On this figure you can see a clear volume increase of the pocket in the beginning of the trajectory. Now you can check to what phenomena this increase is due to by analyzing the mdpout_mdpocket.pdb output  in PyMOL. Not shown in this example, mdpocket now provides also measurements of the polar and apolar surface area (van der Waals + 1.4Å probe) of the pocket.

### Pocket Selection
In order to be able to track some nifty properties of your cavities, like the solvent accessible surface area, the volume or other fpocket descriptors, you have to select the zone you are interested in. This process is crucial and can depply influence sub-sequent results.

But first of all, what is a selected pocket here? Here, this means a PDB file containing dummy atoms at the positions of grid points that overlap with grid points in the pocket grid you calculated in the first run (frequency or density grid). How can you obtain these dummy atoms? This can be done in two different ways.

__The fast way:__ The first, easy and not very accurate way is to use the defaut pdb files coming from the first run of mdpocket to detect the pocket grids. If you read this manual with a huge attention and did not fall asleep in between, then you remember that mdpocket provides two files called `mdpout_freq_iso_0_5.pdb` and `mdpout_dens_8.pdb`. These files contain dummy atoms at grid point positions that were extracted at grid points having a given value or higher (iso-value of 0.5 and 8 respectively). Now you can use one of these files (depending on if you are more comfortable with one or the other grid, and open them in a molecular viewer that is able to edit structures. PyMOL is an excellent choice to perform this task. Simply select all dummy atoms in the zone of interest (your pocket you want to track) and then create an object with this selection. In the end, the result should look somehow like this:

![pocket selection](images/pymol2.png)

Here the red cloud corresponds to the grid points I have selected by hand. You can now save the grid points that you selected as a PDB file and use this as an input for tracking the properties of the cavity.

__The better way:__ In order to get a good estimate of the volume and extent of the pocket you will notice that the default output pdb files for the two grids are not always sufficient, because of their predefined iso-values. This why you should extract the grid points as a PDB file using your own choice of iso-values. As a general rule, take the iso-values as low as possible. You should still be able to distinguish the different pockets in the density grid, but it's volume should not be very tiny!

You can extract these grid points using a python script that is available in the scripts directory of the fpocket distribution, called `extractIso.py`. Simply execute it with `python extractIso.py` to see how to use it.

### Basic Input
#### Mandatory (running mode 1 - detecting pockets):
##### either: 
    --trajectory_file   : input trajectory file in one of the supported formats
    --trajectory_format : (dcd,xtc,netcdf,crd,crdbox,dtr,trr)
    -f                  : topology of the structure as input PDB file

##### or : 
	-L: a mdpocket input file, this file has to contain the paths to the PDB files of all snapshots (one path per line)

#### Mandatory (running mode 2 - calculating descriptors):
##### either: 

    --trajectory_file   : input trajectory file in one of the supported formats
    --trajectory_format : (dcd,xtc,netcdf,crd,crdbox,dtr,trr)
    -f                  : topology of the structure as input PDB file
    --selected_pocket   : a PDB file containing the sitepoints in the pocket to be selected

##### or : 

	-L: a mdpocket input file, this file has to contain the paths to the PDB files of all snapshots (one path per line)
    --selected_pocket   : a PDB file containing the sitepoints in the pocket to be selected

#### Optional:

	-o : the prefix you want to give to mdpocket output files

Note that mdpocket determines its running mode by the input given by the user. Thus if you do not provide a wanted pocket using the --selected_pocket flag, mdpocket will automatically only perform cavity detection. mdpocket offers much more optional parameters in order to guide the pocket detection. All fpocket parameters for pocket clustering and filtering are also available in mdpocket. For this see [advanced mdpocket features](#mdpocket-advanced).

### Output (running mode 1 - pocket detection)

* `mdpout_dens_grid.dx`: A dx formatted grid output. This grid contains the number of Voronoi vertices seen per snapshot nearby the grid point. It can be easily visualized using VMD.
* `mdpout_freq_grid.dx`: Similar to the prevous file, this grid file contains the frequency of opening of a pocket at each grid point. It can be visualized using VMD.
* `mdpout_dens_iso_8.pdb`: A pdb file of all grid point positions corresponding to grid points having 8 or more Voronoi vertices nearby per snapshot. This file is provided in order to be able to edit the grid points using PyMOL and select only the points defining the pocket of interest. This pocket of interest should be used as input of mdpocket in the 2nd running mode. If you want to extract gridpoints with other isovalues, use the provided `extractISO.py` file in the scripts directory.
* `mdpout_freq_iso_0_5.pdb`: A pdb file of all grid point positions corresponding to grid points that are 50% of the trajectory overlapping with a pocket. This file is provided in order to be able to edit the grid points using PyMOL and select only the points defining the pocket of interest. This pocket of interest should be used as input of mdpocket in the 2nd running mode. If you want to extract gridpoints with other isovalues, use the provided `extractISO.py` file in the scripts directory.

### Output (running mode 2 - pocket characterization)

* `mdpout_mdpocket.pdb`: A pdb file containing all Voronoi vertices within the selected pocket region for all snapshots. This file is an NMR like file, containing each snapshot as 
separated model. This file is best viewed using PyMOL and can be used to create pocket motion movies.

* `mdpout_mdpocket_atoms.pdb`: A pdb file containing all receptor atoms surrounding the selected pocket region. Like the previous output file, this is a NMR like file, containing each snapshot as separated model. This file can be viewed with VMD and PyMOL.

* `mdpout_descriptors.txt`: A text file containing the fpocket pocket descriptors of the selected pocket region for each snapshot. This file can be easily analyzed using standard statistical software like R.

## dpocket descriptor extraction

Until now you have seen what the majority of cavity detection algorithms can do. So a part from speed and hopefully prediction results, nothing distinguishes fpocket from other algorithms like ligsite, sitemap, sitefinder, pocketpicker, pass ...
This is just partially true, because the fpocket package contains dpocket. D is an acronym for describing. One purpose a cavity detection algorithm can be used for is the extraction of descriptors of the physico-chemical environment of the cavity. dpocket allows to do this in a very simple and straightforward way. As extracting binding pocket descriptors on only one protein would be somehow meaningless for studying pocket characteristics, dpocket enables analysis of multiple structures. So now, no longer scripting and automation is necessary to do these kind of things. But lets have a closer look using again a very simple example you can try on your workstation.

### Example 

Here we go. dpocket requires one single input file. This input file must be a text file containing the following information: 
- 1: the PDB file of the protein you want to analyze and 
- 2: the ID of the ligand you would like to have as reference in order to define an explicitly defined binding pocket. The file used in this example (data/sample/test_dpocket.txt) looks like this :

```
data/sample/3LKF.pdb   pc1	
data/sample/1ATP.pdb   atp
data/sample/7TAA.pdb   abc
```

Here we analyze three pdb files. Note that the ligand name should be separated by a tabulation from the pdb file name. You can launch dpocket on this sample file using the following command:

`dpocket -f sample/test_dpocket.txt`

dpocket will yield 3 results files in the current directory. These files will be by default :

    - dpout_explicitp.txt
    - dpout_fpocketnp.txt
    - dpout_fpocketp.txt

If you want to change naming of these files, use the `-o` flag in command line to define a new prefix for the fpocket output files, for example `my_test` as prefix would yield `my_test_explicitp.txt`. The three output files contain the in fpocket implemented pocket descriptors for each binding pocket found by fpocket :

- __fpocketp.txt__:  describes all binding pockets found by fpocket that match one of the detection criteria. In other word, fpocket found several pocket in the protein, and this file will contain descriptors of pocket that are considered to be the binding pocket using some detection criteria.
- __fpocketnp.txt__: describes on the contrary all pockets found by fpocket that are not found to be the actual pocket using the detection criteria.
- __explicitp.txt__: describes the pockets explicitely defined. By explicitely defined here, we mean that the pocket will be defined as all vertices/atoms situated at a given distance of the ligand (4A by default), regardless of what fpocket found during the algorithm.


The ouput files are tab separated ASCII text files that are easy to parse using statistical software such as R. Thus statistical analysis of pocket descriptors becomes a very straightforward and easy process. Basically, the two first files might be used to establish a new scoring function as they describe what fpocket finds, while the last file could be used for a more detailed and accurate analysis of the exact part of the protein that interact with the ligand.
For more details of the output refer to the output section below, or to [advanced dpocket features](#dpocket-advanced).


### Basic input

#### Mandatory:

	flag -f : a dpocket input file, this file  has to contain the path to the PDB file, as well as the residuename of the reference ligand, separated by tabulation.

#### Optional:

	flag -o : the prefix you want to give to dpocket output files
dpocket offers much more optional parameters in order to guide the pocket detection. For this see Advanced features chapter – [advanced dpocket features](#dpocket-advanced).

### Output

Refer to [advanced dpocket features](#dpocket-advanced) for a detailed description of the dpocket output files. 

In conclusion of this first very easy dpocket run, you can see that you have a very fast and reliable tool to extract pocket descriptors, of binding pockets and “non binding pockets” on a large scale level. These descriptor files provide an excellent tool for further statistical analysis and model building, which leads immediately to your wish to write a new scoring function for ranking pockets using the different descriptors. Well, fpocket, dpocket and tpocket are very useful tools to do exactly this! So go ahead. Lets suppose you have passed several thousands of PDB files and analyzed statistically the significance of all descriptors. You have set up a new scoring function. Now you have an external test set of PDB files you haven't tested. How can you evaluate your scoring function? This is actually also a very easy task, using tpocket.


## tpocket scoring ranging and evaluation

As already mentioned in the previous paragraph, tpocket can be used in order to evaluate rapidly cavity scoring functions. If you are for example in the pharmaceutical industry and you want to set up the ultimate drugability prediction score, you might be able to do this with fpocket and dpocket. Afterwards you can actually test your method using tpocket. T is an acronym for testing, here. 

Something fancy we did not tell you about before is that you can also test your scoring function on apo structures using tpocket. The only requirement is the need to align holo and apo structure to obtain superposed apo and holo pockets. But lets explain this with an example. Of course, testing a holo dataset is even more easy, you just need to provide the resname of the ligand and tpocket will do the rest.

### Example – tpocket on apo structures

If you had a look to the fpocket paper, you might have seen that the algorithm was validated on a dataset of 48 proteins previously used to evaluate several pocket detection algorithms. As fpocket programmers are, by definition, very nice people, they have included this data set (holo and aligned apo structures) in the distribution of fpocket, released as `fpocket-1.0-data` with the original fpocket 1 release. [The tar.gz is available on sourceforge](https://sourceforge.net/projects/fpocket/files/fpocket-1.0/fpocket-src-1.0/fpocket-data-1.0.tgz/download)

So let us use this set as example here. When you extract the dataset in your folder you should have a data folder containing among others two files, `pp_apo-t.txt` and `pp_cplx-t.txt`. The first file is a tpocket input file in order to assess the capacity of the scoring function to rank correctly known binding sites on apo structures. The second file is also a tpocket inputfile, but this time for known binding sites on holo structures. Here is a part of `pp_apo-t.txt`:

    data/pp_data/unbound/1QIF-1ACJ.pdb      data/pp_data/complex/1ACJ.pdb   tha
    data/pp_data/unbound/3APP-1APU.pdb      data/pp_data/complex/1APU.pdb   iva
    data/pp_data/unbound/1HSI-1IDA.pdb      data/pp_data/complex/1IDA.pdb   qnd
    data/pp_data/unbound/1PSN-1PSO.pdb      data/pp_data/complex/1PSO.pdb   iva
    data/pp_data/unbound/1L3F-2TMN.pdb      data/pp_data/complex/2TMN.pdb   po3
    data/pp_data/unbound/3TMS-1BID.pdb      data/pp_data/complex/1BID.pdb   UMP
    data/pp_data/unbound/8ADH-1CDO.pdb      data/pp_data/complex/1CDO.pdb   NAD
    data/pp_data/unbound/1HXF-1DWD.pdb      data/pp_data/complex/1DWD.pdb   MID

Here the first column contains the path to the apo structure, aligned to the holo structure, which is given in the second column. Using a holo dataset, the first and the second column would be the same. The third column indicates the PDB HETATM code of the ligand in the holo structure that is situated in the binding site.

You can use this file to run tpocket using the following command line :

`tpocket -L data/pp_apo-t.txt`

Let us continue with the more interesting case, the first example, with a lot of structures. After some time of calculation, tpocket will provide two standard output files. The moment has come, you will finally know if you discovered the ultimate method of drugability prediction, or sugar binding site prediction or whatever. The first file is called by default `stats_g.txt`. It contains global statistics about the prediction using all evaluation criterias available in tpocket, so for example how many binding sites you found among the 3 first ranked cavities. For representational purposes only the first of the six tables available in this file is depicted hereafter:

    Ratio of good predictions (dist = 4A)
    -------------------------------------
    Rank <=  1  :		  0.69
    Rank <=  2  :		  0.83
    Rank <=  3  :		  0.94
    Rank <=  4  :		  0.94
    Rank <=  5  :		  0.94
    Rank <=  6  :		  0.94
    Rank <=  7  :		  0.94
    Rank <=  8  :		  0.94
    Rank <=  9  :		  0.94
    Rank <= 10  :		  0.94
    -------------------------------------
    Mean distance          : 2.924573
    Mean relative overlap  : 39.373226

This table schedules the capacity of your scoring function to identify the binding sites of the 48 apo structures using the criteria published within the original pocket picker paper. Not represented here, tpocket provides two other, maybe more accurate, measures for a correctly identified binding site. These measures are explained in more detail in the [advanced tpocket features section](#tpocket-advanced), as they can be a bit more tricky.

The second output file provides more accurate statistics about each structure analyzed. This file, called `stats_p.txt` enables the user to analyze more closely why scoring might not work well on a specific structure. Here is an extract of the first columns and lines of this file:

    LIG | COMPLEXE | APO | NB_PCK | OVLP1 | OVLP2 | DIST_CM | POS1 | POS2 | POS3
    THA 1ACJ.pdb 1QIF-1ACJ.pdb    22   79.31   78.33    0.00    1    1    0
    IVA 1APU.pdb 3APP-1APU.pdb     4    0.00    0.00    3.43    0    0    1
    QND 1IDA.pdb 1HSI-1IDA.pdb     4   82.69   81.65    3.19    1    1    1
    IVA 1PSO.pdb 1PSN-1PSO.pdb     9   80.00   51.38    3.49    1    1    1
    PO3 2TMN.pdb 1L3F-2TMN.pdb    10   58.33   72.00    2.69    1    1    1
    UMP 1BID.pdb 3TMS-1BID.pdb    15   63.64   60.78    3.52    1    1    1
    NAD 1CDO.pdb 8ADH-1CDO.pdb    18    0.00    0.00    3.41    0    0    1
    MID 1DWD.pdb 1HXF-1DWD.pdb    10   93.48   81.37    3.86    1    1    1

Using this output you have a detailed view of what worked and what did not worked for all criteria. For instance, in this example, fpocket detects well all apo binding sites a part from the first one using the PocketPicker criterion for binding site identification (DIST_CM). POS3 corresponds to the rank  of the cavity using the scoring function of fpocket. You have further information about the number of pockets per protein and the exact overlap with the actual pocket.

Now if you want to assess your scoring function on holo structures, you also can use tpocket. This time you only have to provide the `pp_cplx.txt`, also provided within the sample tar.gz file. As you can see, this file is very similar to `pp_apo.txt`. Only the first column repeats the path to the complex structure like this:

    data/pp_data/complex/1acj.pdb   data/pp_data/complex/1acj.pdb   tha
    data/pp_data/complex/1apu.pdb   data/pp_data/complex/1apu.pdb   iva
    data/pp_data/complex/1ida.pdb   data/pp_data/complex/1ida.pdb   qnd
    data/pp_data/complex/1pso.pdb   data/pp_data/complex/1pso.pdb   iva
    data/pp_data/complex/2tmn.pdb   data/pp_data/complex/2tmn.pdb   po3
    data/pp_data/complex/1bid.pdb   data/pp_data/complex/1bid.pdb   ump
    data/pp_data/complex/1cdo.pdb   data/pp_data/complex/1cdo.pdb   nad

### Basic Input

#### Mandatory:

	flag -L : a tpocket input file, this file  has to contain the paths to the PDB files (apo, holo or holo,holo if you want to test fpocket only on holo structures), as well as the residuename of the reference ligand, separated by tabulation.

#### Optional:
	flag -o : the prefix you want to give to tpocket detailed statistics
	flag -e : the prefix you want to give to tpocket general statistics

tpocket offers much more optional parameters in order to guide the pocket detection. For this see the [advanced tpocket features section](#tpocket-advanced).

### Output
Using standard parameters on the example tpocket list given in the example paragraph above, tpocket returns two output files:

* `stats_p.txt`: This file contains the detailed statistics of tpocket. The name and the ligand of the analyzed PDB structure are repeated, as well as the exact overlap of the fpocket identified binding pocket with the actual binding pocket (identified with the help of the ligand, called OVLP here). You will see two different overlaps in the output. For further informations refer to the  [advanced tpocket features section](#tpocket-advanced). Furthermore, the distance criterion used in the Chemistry Central Journal paper for publication of PocketPicker was used (DIST_CM). Next, you can also have exact information about the rank of the cavity using the fpocket scoring function.
* `sats_g.txt`: Second, tpocket provides more general statistics about pocket identification on the dataset provided. For both overlap criterions the ranking performance (the capacity of the fpocket scoring to rank correctly a binding site having a certain minimum overlap with the actual binding site) is printed into this file. Thus, statistics in this file gives you a rapid overview over the global performance of your method.

Summarizing features of tpocket, one could retain, that tpocket is a very fast way to test fpockets performance on your own dataset and test your own scoring functions for ranking purposes of identified binding sites.

You have finished the Getting started section. We hope that you notice the usefulness (hopefully;) of this package of programs for the research of new features, descriptors and scoring functions in the binding site identification field. Well, this was only a very fast overview over the very basic features of fpocket, dpocket and tpocket. If you want to dive into development of your own pocket descriptors and scoring functions, or if you want to change the pocket detection parameters for your purposes, continue with the Advanced features section, next.


# Advanced Features

You want to know more about fpocket? This is the section for you, here we tried to compile in a (we hope) comprehensive manner the most important details of fpocket, dpocket and tpocket, to which you have access by command line. It is primordial to know, that fpockets performance was assessed and scoring function was established for standard parameters. The performance of pocket detection and scoring is highly dependent on these parameters, so keep in mind that you might have to adapt scoring to your specific problem.
Note that this section does not provide too much information about the theoretical background of the way fpocket works. In order to learn more about this read the Materials & Methods of the [freely available paper on the BMC Bioinformatics](https://bmcbioinformatics.biomedcentral.com/articles/10.1186/1471-2105-10-168) website. Nevertheless, we tried to keep it as clear as possible, using some application examples.

## fpocket advanced

### Input command line arguments

#### Mandatory:
The simplest way to run fpocket is either by providing a single pdb file, or by providing a list of pdb file, stored in a simple text file. You will need one of these two input to run fpocket:

    -f string : one standard PDB filename that you want to analyze with fpocket
##### or:
    -F string : filename of a simple list of pdb files.


#### Optional:

    -m float: (default 3.4Å) This flag enables the user to modify the minimum radius an alpha sphere might have in a binding pocket. An alpha sphere is a contact sphere, that touches 4 atoms in 3D space without having any internal atoms. Here 3Å allow filtering of too small (protein internal) alpha spheres. I you want to analyze internal interstices, lower this parameter. In the contrary, if you want to analyze more solvent exposed cavities, you can raise this parameter in order to filter out too buried cavities.

    -M float: (default 6.2Å) Here you can modify the maximum radius of alpha spheres in a pocket. An alpha sphere is a contact sphere, that touches 4 atoms in 3D space without having any internal atoms. Here 7Å allow to filter out too large contact spheres, that are lying on the protein surface. If you want to analyze very flat and solvent exposed surface depressions, raise this parameter. For analysis of buried parts of the protein you can lower this parameter. Higher radii might be more interesting for identification of protein protein binding sites or polysaccharide binding sites. Smaller radii enable detection of buried cavities for small organic molecules (drugs, for instance).

    -l int: (None) If you have an input PDB file of an NMR structure or one with multiple models you can specify which model (conformation) you'd like to analyse

    -C char: (default s) The clustering method to be used here. By default a pairwise single linkage clustering is used here. 
        's': pairwise single linkage clustering,
        'm': pairwise maximum- (or complete-) linkage clustering, 
        'a': pairwise average-linkage clustering, 
        'c': pairwise centroid-linkage clustering

    -e char: (default e) The distance measure used for the clustering algorithm. 
        'e': Euclidean distance
        'b': City-block distance
        'c': correlation
        'a': absolute value of the correlation
        'u': uncentered correlation
        'x': absolute uncentered correlation
        's': Spearman's rank correlation
        'k': Kendall's tau

    -i int: (default 15) This flag indicates how many alpha spheres a pocket must contain at least in order to figure in the results provided by fpocket. This parameter enables filtering of too small cavities. Thus, if you want to analyze smaller cavities also, lower this parameter, if you are only interested in huge cavities, like NADP binding sites, you can raise it in order to retain only very few pockets in the end. To give you an idea, a rather big cavity, like a NADP binding site, can have hundreds of alpha spheres. Thus, 30 as standard parameter enables also to keep smaller binding sites.

    -A int: (default 3) Fpocket distinguishes between two types of alpha spheres. Polar alpha spheres and apolar alpha spheres. This flag ranges from 0 to 4 and modifies the definition of the alpha sphere type. By default, an alpha sphere contacting at least 3 apolar atoms (having an electronegativity below 2.8) is considered as apolar. If this is not the case it is considered as polar.

    -D float: (default 2.4Å) this parameter changed compared to the previous versions of fpocket as we completely replaced the clustering algorithms entirely. This measure is now used to analyze a hierarchical distance and cut sub-trees at the desired distance. The bigger the distance, the larger the clusters you'll get. 

    -p float: (default 0.0) This is another parameter for filtering unwanted pockets. It defines the maximum ratio of apolar alpha spheres and the number of alpha spheres in a pocket in order to keep the pocket in the results list. That is to say, by default every pocket is kept (0.0). Now, if you would like to filter rather hydrophobic pockets, raise this parameter and very polar cavities will be filtered out. This parameter is a ratio, not a percentage, thus it ranges from 0 to 1.

    -v int: (default 2500) By default, pockets volume are calculated using a monte-carlo algorithm. Basically, the algorithm picks a random point in the space and check if it is included in any alpha sphere, and stores this status. This is repeated N times, and we estimate the volume of the pocket using ratio between the number of hit and the number of iteration, scaled by the size of the box. This parameter defines the number of iteration to perform. Of course, the higher the value is, the greater the accuracy will be, but the performance will be slowed down.

    -b (none): (NOT USED BY DEFAULT) This option allows the user to chose a discrete algorithm  to calculate  the  volume of each pocket instead of the Monte Carlo method. This algorithm puts each pocket into a grid of  dimention (1/N*X  ;  1/N*Y  ;  1/N*Z),  N being the value given using this option, and X, Y and Z being the box dimensions,  determined using coordinates of vertices. Then, a triple iteration on each dimensions is used to estimate the volume, checking if each points  given  by the iteration is in one of the pocket’s vertices. This parameter defines the grid discretization. If this parameter is used, this algorithm will be used instead of the Monte Carlo algorithm. 
    Warning: Although this algorithm could be more accurate, a high value might dramatically slow down the program, as this algorithm has a maximum complexity of N*N*N*nb_vertices, and a minimum of N*N*N !!!
    

    -d (none): Option allowing you to output pockets and properties in a condensed format. This will put to the stdout pocket properties in a tab separated string and write pocket files in a subfolder

    -r string: (None) This parameter allows you to run fpocket in a restricted mode. Let's suppose you have a very shallow or large pocket with a ligand inside and the automatic pocket prediction always splits up you pocket or you have only a part of the pocket found. Specifying your ligand residue with -r allows you to detect and characterize you ligand binding site explicitely. For instance for `1UYD.pdb` you can specify `-r 1224:PU8:A` (residue number of the ligand: residue name of the ligand: chain of the ligand)

    -y string: (filename) EXPERIMENTAL: here you can specify a topology filename in the Amber prmtop format. This can then be used by fpocket & mdpocket to calculate energy grids for your pockets. NB: you have to specify the -x flag to run energy calculations

    -x None: (None) EXPERIMENTAL: specify this flag if you want to run energy calculations on calculated pockets. That's not fully functional and only one or two probes are currently generated and output density grids written. Use with caution
    

###  Output files description

fpocket yields output directly in the directory of the data file, creating a directory using the name of the PDB file followed bu the _out extension. Here, the command ll sample/3LKF_out of the current sample run would look something like this:

        total 332
        -rw-r--r-- 1 peter users    769 Nov 29 00:14 3LKF.pml
        -rw-r--r-- 1 peter users    698 Nov 29 00:14 3LKF.tcl
        -rwxr-xr-x 1 peter users     30 Nov 29 00:14 3LKF_PYMOL.sh
        -rwxr-xr-x 1 peter users     41 Nov 29 00:14 3LKF_VMD.sh
        -rw-r--r-- 1 peter users 245835 Nov 29 00:14 3LKF_out.pdb
        -rw-r--r-- 1 peter users   6725 Nov 29 00:14 3LKF_pockets.info
        -rw-r--r-- 1 peter users  49355 Nov 29 00:14 3LKF_pockets.pqr
        -rw-r--r-- 1 peter users   4073 Nov 29 00:14 3LKF_info.txt
        drwxr-xr-x 2 peter users   4096 Nov 29 00:14 pockets

As you can see, fpocket provides a lot of files and another subdirectory. However, majority of these files are necessary for easy visualization of binding pockets. Lets explain the content and utility of each file:

* `3LKF_info.txt`: this file contains human readable information (descriptors) about the pockets found on the protein, here an extract:
    Pocket 1 :
            Score :         0.490
            Druggability Score :    0.019
            Number of Alpha Spheres :       21
            Total SASA :    19.687
            Polar SASA :    7.611
            Apolar SASA :   12.076
            Volume :        270.934
            Mean local hydrophobic density :        3.000
            Mean alpha sphere radius :      3.816
            Mean alp. sph. solvent access :         0.519
            Apolar alpha sphere proportion :        0.190
            Hydrophobicity score:   23.889
            ...

* `3LKF.pml`: this is a PyMOL script for visualization of binding pockets using PyMOL
* `3LKF.tcl`: this a tcl script for visualization of binding pockets using VMD
* `3LKF_PYMOL.sh`: this is the executable script to launch fast visualization using PYMOL
* `3LKF_VMD.sh`: this is the executable script to launch fast visualization using VMD
* `3LKF_out.pdb`: this is the most important file, it contains the initial PDB structure given as input. Non cofactor HETATM occurrences will be stripped off in this file compared to the original PDB input file. The PDB file contains centers of alpha spheres using the HETATM definition as dummy atoms. These alpha sphere centers are attached in the end of the PDB file, using the STP residue name (for site point). Apolar alpha spheres carry the atom name APOL, polar alpha spheres the atom name POL. Pockets are sets of alpha spheres. They can be distinguished by residue number. Thus residue STP 1 would be the first binding pocket according to fpocket. To show this more clearly here is an extract of the `3LKF_out.pdb`:
        
        ATOM   2346    O LYS A 299       5.196  17.918 108.327  0.00  0.00           O 0
        ATOM   2347   CB LYS A 299       7.597  17.980 106.440  0.00  0.00           C 0
        ATOM   2348   CG LYS A 299       8.273  17.265 105.299  0.00  0.00           C 0
        ATOM   2349   CD LYS A 299       9.679  16.827 105.636  0.00  0.00           C 0
        ATOM   2350   CE LYS A 299      10.371  16.314 104.370  0.00  0.00           C 0
        ATOM   2351   NZ LYS A 299      11.749  15.794 104.597  0.00  0.00           N 0
        ATOM   2352  OXT LYS A 299       5.240  20.009 107.670  0.58  9.64           O 0
        HETATM    1 APOL STP C   1      27.849  33.435 123.906  0.00  0.00          Ve  
        HETATM    2 APOL STP C   1      29.108  33.195 122.206  0.00  0.00          Ve  
        HETATM    3 APOL STP C   1      28.611  33.141 119.797  0.00  0.00          Ve  
        HETATM    4 APOL STP C   1      26.830  32.143 118.779  0.00  0.00          Ve  

* `3LKF_pockets.pqr`: This file contains all alpha sphere centers, as the 3LKF_out.pdb file, but contains no information about the protein structure. Furthermore using the pqr format enables writing of the van der Waals radius of atoms explicitely in this file. Here this possibility was used to output the radii of alpha spheres of a pocket. Charging this pqr file, one can analyze more precisely the volume recognized by fpocket. Note that, currently only VMD supports reading this format correctly. PyMOL is able to read pqr file, but does not interpret van der Waals radii.    

* `pockets/`: Well, again a subdirectory. But I promise, it's the last one. For development purposes or easy analysis, fpocket proposes this directory which contains according to the current example:

        pocket0_atm.pdb   pocket2_vert.pqr  pocket5_atm.pdb   pocket7_vert.pqr
        pocket0_vert.pqr  pocket3_atm.pdb   pocket5_vert.pqr  pocket8_atm.pdb
        pocket1_atm.pdb   pocket3_vert.pqr  pocket6_atm.pdb   pocket8_vert.pqr
        pocket1_vert.pqr  pocket4_atm.pdb   pocket6_vert.pqr  pocket9_atm.pdb
        pocket2_atm.pdb   pocket4_vert.pqr  pocket7_atm.pdb   pocket9_vert.pqr

* `*_atm.pdb`: These files contain only the atoms contacted by alpha spheres in the given pocket. Complementary to this information, `*_vert.pqr` files contain only the centers and radii of alpha spheres within the respective pocket. As extensions mention, atoms are output in the PDB file format and alpha sphere centers in the PQR file format.

