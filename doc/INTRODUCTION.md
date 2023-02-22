

# Introduction

Thanks for taking the time to read this official userguide of fpocket. In this guide are presented general functionalities of the fpocket program and its derivatives, dpocket, tpocket and mdpocket. Yes, indeed fpocket is a package of four distinct programs, mentioned here before. fpocket is an acronym for “finding” pocket; dpocket is an acronym for “describing” pockets as it is for extraction of physico-chemical descriptors of pockets; tpocket is an acronym for “testing” pockets, as it is used for testing on a large scale scoring function for ranking protein cavities developed with fpocket, among each other. mdpocket was named after pocket detection on molecular dynamics (MD) trajectories.

This is not a usual guide. You can find here elements you can find in usual user guides, but we included several examples in the getting started section, which should enhance fast understanding of how to work with fpocket. The getting started guide can be understood like a mini tutorial of basic functionality of this software.

Furthermore, we don't take ourselves too seriously, so the way this manual is written might not correspond to the industry standard ;)

## License & Copyright

This program is published under the MIT Licence. Basically do whatever you want with it. 
Vincent Le Guilloux, Peter Schmidtke are authors of fpocket, dpocket, tpocket (which perform protein cavity detection, cavity descriptor extraction, large scale cavity prediction evaluations) Peter Schmidtke is the author of mdpocket which performs pocket detection and descriptor extraction on MD trajectories).
Contributions
The initial fpocket software was developed, validated, documented and distributed by Vincent Le Guilloux & Peter Schmidtke. Both, contributed equally to this project. The initial work on fpocket was initiated and supervised by Pierre Tufféry.
Latest extensions were developed, validated, documented and distributed by Peter Schmidtke (mdpocket, druggability score, energy calculations) supervised by Xavier Barril.


## Publication & Citation

The methods paper about this software was published in BMC Bioinformatics. In order to cite fpocket in the future, please cite this paper :

- Vincent Le Guilloux, Peter Schmidtke and Pierre Tuffery, “Fpocket: An open source platform for ligand pocket detection”, BMC Bioinformatics 2009, 10:168

If you use the druggability score of fpocket, please cite :

- Peter Schmidtke & Xavier Barril “Understanding and predicting druggability. A high-throughput method for detection of drug binding sites.”, J Med Chem, 2010, 53(15):5858-67

Last, the mdpocket paper has been published too and can be cited using:

- Peter Schmldtke, Axel Bidon-Chanal, Javier Luque, Xavier Barril, “MDpocket: open-source cavity detection and characterization on molecular dynamics trajectories.”, Bioinformatics. 2011 Dec 1;27(23):3276-85

Contact
If you want to contact the fpocket developers please create a github issue here: https://github.com/Discngine/fpocket/issues

We are happy about positive, negative, in any way constructive feedback.

## Read next

* [Installation](INSTALLATION.md)

* [Getting Started](GETTINGSTARTED.md)