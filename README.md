# fpocket project
The fpocket suite of programs is a very fast open source protein pocket detection algorithm based on Voronoi tessellation. The platform is suited for the scientific community willing to develop new scoring functions and extract pocket descriptors on a large scale level.

## Content
fpocket: the original pocket prediction on a single protein structure 
mdpocket: extension of fpocket to analyse conformational ensembles of proteins (MD trajectories for instance)
dpocket: extract pocket descriptors
tpocket: test your pocket scoring function

## What's new compared to fpocket 2.0 (old sourceforge repo)
fpocket: 
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

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

The most recent versions (starting with fpocket 3.0) make use of the molfile plugin from VMD. This plugin is shipped with fpocket. However, now you need to install the netcdf library on your system. This is typically called netcdf-devel or so, depending on you linux distribution.
fpocket needs to be compiled to run on your machine. For this you'll need the gnu c compiler (or another one, but didn't test with others than GCC).
install netcdf-devel on ubuntu type : 
```
sudo apt-get install libnetcdf-dev
```
on a RHEL based distribution something like this should do:
```
sudo yum install netcdf-devel.x86_64
```

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
Install MacPorts https://www.macports.org/ for instance (needed for netcdf install)
```
sudo port install netcdf
export LIBRARY_PATH=/opt/local/lib
git clone https://github.com/Discngine/fpocket.git
cd fpocket
make ARCH=MACOSXX86_64
sudo make install
```



End with an example of getting some data out of the system or using it for a little demo

## Running the tests

The source code of fpocket is shipped with samples. They can be found in the data/sample folder. Try to run fpocket against the 1uyd sample to check if it's running OK. 

```
cd data/sample
fpocket -f 1UYD.pdb
```
fpocket should state when it's beginning to search pocket and also when it's ending the search. Upon completion the folder should now contain a folder called 1UYD_out. Check whether the folder exists and the pdb files contain data and the pocket info file contains results. 


## User Manual
For now the user manual (still the one from fpocket 2.0) can be found in the doc folder. When I have some time to kill (or if somebody else has) we could add that here somewhere.

## Frequent issues encountered
### netcdf issues
```
cannot find -lnetcdf
```
mdpocket supports reading and writing NETCDF formatted files. In order to use this you need to install the netcdf development libraries on your system. 
In centos this can be achieved like this : 
```
yum install -y epel-release #if the epel repo is not yet activated on your system
yum install -y netcdf-devel

```

Run make again after installing this library. Mdpocket should build just fine now. 

### stdc++ issues
```
cannot find -lstdc++
```
You need to install the stc++ static libraries to build fpocket & mdpocket. On centos 7.4 this can be done like this : 
```
yum install -y libstc++-static
```

### linking to molfile plugin issues
If you observe an error similar to this one
```
ld: warning: ignoring file plugins/MACOSXX86/molfile/libmolfile_plugin.a, file was built for archive which is not the architecture being linked (x86_64): plugins/MACOSXX86/molfile/libmolfile_plugin.a
Undefined symbols for architecture x86_64:
  "_molfile_parm7plugin_init", referenced from:
      _read_topology in topology.o
  "_molfile_parm7plugin_register", referenced from:
      _read_topology in topology.o
ld: symbol(s) not found for architecture x86_64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
make[1]: *** [bin/fpocket] Error 1
make: *** [all] Error 2
```
then statically built libmolfile_plugin is not compatible with your machine. First check out that the ARCH variable set in the first line of the Makefile of fpocket actually reflects the architecture you want. For now I'm trying to support linux 64 bit systems and OSX 64 (LINUXAMD64) bit systems built with clang (MACOSXX86). So both should work out of the box. If they do not, you might need to build the molfile plugin for your architecture. All available system architectures for the molfile plugin can be found in the plugins folder tree : [plugins directory](https://github.com/Discngine/fpocket/tree/master/plugins). 
Here you can find more information on how to build the molfile plugin on CentOS 7.4: 
[compile molfile plugin on centos 7.4 - Discngine blog post](https://www.discngine.com/blog/2019/5/25/building-the-vmd-molfile-plugin-from-source-code)
Once built, copy the architecture folder into the fpocket/plugins directory and make sure to declare this architecture in the ARCH variable in the Makefile. Finally run make again.
If you manage to build for other architectures and it works, I'd be happy to accept PR's with the relevant plugin architectures as I cannot build all of them on my own ;).

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.


## Authors

* **Peter Schmidtke** - *Initial work* - [pschmidtke](https://github.com/pschmidtke)
* **Vincent Le Guilloux** - *Initial work* - [leguilv](https://github.com/leguilv)


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details

## Acknowledgments

* to be filled
