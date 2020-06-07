# Installation

## Prerequisites
Currently fpocket proposes two different ways for visualization of binding pockets. Both are based on commonly used molecular visualization tools : VMD and PyMol. In order to use visualization you need to install at least one of both softwares, or any other valid tool able to read standard PDB files (Chimera, MOE, Maestro etc). 

Currently, visualization using VMD has better rendering and performances and visualization using PyMol better handling of binding pockets. You can download VMD for free from http://www.ks.uiuc.edu/Research/vmd/. PyMol can be freely downloaded from https://pymol.org/2/.


## Dependencies

fpocket relies on Qhull. In the officially released version fpocket ships Qhull with it and Qhull compilation is automatically done when compiling and installing fpocket. Since the 3.0 release of fpocket 

- libnetcdf and 
- libstdc++ 

are required to compile fpocket.

## System Requirements

fpocket is available for Linux/Unix type OS's, and also MacOSX (so basically all OS's that don't completely suck).
In order to run fpocket, you should have at minimum a Pentium III 500 Mhz (does that still exist?) with 128Mb of RAM (lol). This program was co-developed and tested under the following Linux distributions : openSuse 10.3 (and newer), Centos 5.2, Fedora Core 7, Ubuntu 8.10 as well as Mac OS X (10.5, 10.6, 10.14.6). You need a valid C compiler like gcc or clang (for mac).

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

```bash
git clone https://github.com/Discngine/fpocket.git
cd fpocket
make 
sudo make install
```

#### Compiling on OSX
Install MacPorts https://www.macports.org/ for instance (needed for netcdf install)
```bash
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


## Frequent issues encountered
### netcdf issues
```
cannot find -lnetcdf
```
mdpocket supports reading and writing NETCDF formatted files. In order to use this you need to install the netcdf development libraries on your system. 

#### Centos: 
This can be achieved like this : 
```
yum install -y epel-release #if the epel repo is not yet activated on your system
yum install -y netcdf-devel
```

#### Ubuntu: 
```
sudo apt-get install libnetcdf-dev
```

#### OSX:

Install MacPorts https://www.macports.org/ for instance (needed for netcdf install)

```
sudo port install netcdf
export LIBRARY_PATH=/opt/local/lib
```

Run make again after installing this library. Mdpocket / fpocket should build just fine now. 

### stdc++ issues
```
cannot find -lstdc++
```
You need to install the stc++ static libraries to build fpocket & mdpocket. 

#### Centos:

On centos 7.4 this can be done like this : 
```
yum install -y libstc++-static
```

#### Ubuntu: 
```
sudo apt-get install libstdc++6
```


### Linking to molfile plugin issues
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
then statically built libmolfile_plugin is not compatible with your machine. First check out that the ARCH variable set in the first line of the Makefile of fpocket actually reflects the architecture you want. For now I'm trying to support linux 64 bit systems and OSX 64 (LINUXAMD64) bit systems built with clang 32 and 64 bit (MACOSXX86 MACOSXX86_64). So all should work out of the box. If they do not, you might need to build the molfile plugin for your architecture. All available system architectures for the molfile plugin can be found in the plugins folder tree : [plugins directory](https://github.com/Discngine/fpocket/tree/master/plugins). 
Here you can find more information on how to build the molfile plugin on CentOS 7.4: 
[compile molfile plugin on centos 7.4 - Discngine blog post](https://www.discngine.com/blog/2019/5/25/building-the-vmd-molfile-plugin-from-source-code)
Once built, copy the architecture folder into the fpocket/plugins directory and make sure to declare this architecture in the ARCH variable in the Makefile. Finally run make again.
If you manage to build for other architectures and it works, I'd be happy to accept PR's with the relevant plugin architectures as I cannot build all of them on my own ;).


## Read next

* [Getting Started](GETTINGSTARTED.md)

* [Advanced Features](ADVANCED.md)
