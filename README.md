
![fpocket logo](doc/images/fpocket_logo.png) 

[![Build Status](https://dev.azure.com/3decision/fpocket/_apis/build/status/Discngine.fpocket?branchName=master)](https://dev.azure.com/3decision/fpocket/_build/latest?definitionId=2&branchName=master)
[![Join the chat at https://gitter.im/fpocket/community](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/fpocket-official/community?utm_source=badge&utm_medium=badge&utm_content=badge)

The fpocket suite of programs is a very fast open source protein pocket detection algorithm based on Voronoi tessellation. The platform is suited for the scientific community willing to develop new scoring functions and extract pocket descriptors on a large scale level.

Detailed documentation is available here: [User Manual](doc/MANUAL.md). 
The documentation below here is just a quick & rough overview.

## Content

* __fpocket__   : the original pocket prediction on a single protein structure 
* __mdpocket__  : extension of fpocket to analyse conformational ensembles of proteins (MD trajectories for instance)
* __dpocket__   : extract pocket descriptors
* __tpocket__   : test your pocket scoring function

## What's new compared to fpocket 2.0 (old sourceforge repo)
__fpocket__: 
- is now able to consider explicit pockets when you want to calculate properties for a known binding site
- cli changed a bit
- pocket flexibility using temperature factors is better considered (less very flexible pockets on very solvent exposed areas)
- druggability score has been reoptimized vs original paper. Yields now slightly better results than the original implementation.
- compiler bug on newer compilers fixed

mdpocket: 
- can now read Gromacs XTC, netcdf and dcd trajectories
- can also read prmtop topologies
- if topology provided, interaction energy grids can be calculated for transient pockets and channels (experimental)


## Getting Started

### Prerequisites (if you want to compile it)

The most recent versions (starting with fpocket 3.0) make use of the molfile plugin from VMD. This plugin is shipped with fpocket. However, now you need to install the netcdf library on your system. This is typically called netcdf-devel or so, depending on you linux distribution.
fpocket needs to be compiled to run on your machine. For this you'll need the gnu c compiler (or another one).

install netcdf-devel on ubuntu type : 
```
sudo apt-get install libnetcdf-dev
```
on a RHEL based distribution something like this should do:
```
sudo yum install netcdf-devel.x86_64
```

on OSX:

Install MacPorts https://www.macports.org/ for instance (needed for netcdf install)

```bash
sudo port install netcdf
export LIBRARY_PATH=/opt/local/lib
```

### Docker Image

#### Using the official fpocket docker image

The following command will pull the latest fpocket docker image from the dockerhub. 

```bash
docker pull fpocket/fpocket
```

#### Building the docker image


You can create a docker image with fpocket using the provided Dockerfile of the repo (obviously you'd need docker to do that): 

```bash
docker build -t fpocket/fpocket .
```

#### Using the docker image

This will build fpocket into your local fpocket/fpocket image. You can then run fpocket/mdpocket etc using: 

```bash
docker run -v `pwd`:/WORKDIR fpocket/fpocket fpocket -f data/sample/1UYD.pdb
```

Here you mount your current directory with your input files into the preconfigured `/WORKDIR` in the docker container and then run fpocket on a file in that mounted folder.

### Installing

Download the sources from github via the website or using git clone and then build and deploy fpocket using the following commands.

#### Compiling on Linux

```
git clone https://github.com/Discngine/fpocket.git
cd fpocket
make 
sudo make install
```

#### Compiling on Mac
```
git clone https://github.com/Discngine/fpocket.git
cd fpocket
make ARCH=MACOSXX86_64
sudo make install
```

#### Using conda

There's also a conda package of fpocket available thanks to Simon Bray. You can install fpocket using conda with:
```
conda config --add channels conda-forge
conda install fpocket
```

#### Testing your installation

In order to test if the compilation went well you can compare results from fpocket sample files to reference results shipped with fpocket. The easiest way to do that is by using pytest. If you do not have pytest yet, you can install the required library using the conda environment file in the tests folder: 

```bash
conda env create -f tests/environment.yml
conda activate fpocket_test
```

Once your conda environment activated you can run 

```
pytest

```

If everything works fine you should get something like this output here:
```bash
fpocket_test) Mac-Pro:fpocket peter$ pytest 
============================================================= test session starts ==============================================================
platform darwin -- Python 3.7.7, pytest-5.4.2, py-1.8.1, pluggy-0.13.1
rootdir: /Users/peter/Documents/Work/fpocket_git/fpocket
collected 4 items                                                                                                                              

tests/test_fpocket.py ....                                                                                                               [100%]

============================================================== 4 passed in 40.92s ==============================================================

```
If something fails in there you'll have a rather verbose and red output ... trust me you'll notice and panic ;)


### Running fpocket

You can run fpocket using the following command line as an example:
```bash
fpocket -f 1uyd.pdb
```

fpocket now also eats cif as input, so this would work as well. Make sure to use proper file extensions
```bash
fpocket -f 1uyd.cif
```

This will detect all pockets on the input pdb file, named 1uyd.pdb
If you want to get all command line args for fpocket, simply type `fpocket``

### Running mdpocket
To detect all pockets and create a pocket frequency grid on a sample input trajectory in an xtc format for instance you can run: 

```bash
mdpocket --trajectory_file input.xtc --trajectory_format xtc -f topology.pdb
```

## Detailed User Manual

You can access the detailed user manual here * [User Manual](doc/MANUAL.md)

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.

## Authors

* **Peter Schmidtke** - *Initial work* - [pschmidtke](https://github.com/pschmidtke)
* **Vincent Le Guilloux** - *Initial work* - [leguilv](https://github.com/leguilv)
* **Mael Shorkar** - *Chain handling, MMCIF support* - [shorkarmael](https://github.com/shorkarmael)


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

