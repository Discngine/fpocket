# fpocket
Fpocket is a very fast open source protein pocket detection algorithm based on Voronoi tessellation. The platform is suited for the scientific community willing to develop new scoring functions and extract pocket descriptors on a large scale level.

## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

The most recent versions (starting with fpocket 3.0) make use of the molfile plugin from VMD. This plugin is shipped with fpocket. However, now you need to install the netcdf library on your system. This is typically called netcdf-devel or so, depending on you linux distribution.
fpocket needs to be compiled to run on your machine. For this you'll need the gnu c compiler (or another one, but didn't test with others than GCC).
install netcdf-devel on ubuntu type : 
```
sudo apt-get install libnetcdf-dev
```

### Installing

Download the sources from github via the website or using git clone and then build and deploy fpocket using the following commands.


```
git clone https://github.com/Discngine/fpocket.git .
cd fpocket
make 
sudo make install
```


End with an example of getting some data out of the system or using it for a little demo

## Running the tests

The source code of fpocket is shipped with samples. They can be found in the data/sample folder. Try to run fpocket against the 1uyd sample to check if it's running OK. 

```
cd data/sample
fpocket 1UYD.pdb
```
fpocket should state when it's beginning to search pocket and also when it's ending the search. Upon completion the folder should now contain a folder called 1UYD_out. Check whether the folder exists and the pdb files contain data and the pocket info file contains results. 


## User Manual
For now the user manual (still the one from fpocket 2.0) can be found in the doc folder.

## Contributing

Please read [CONTRIBUTING.md](https://gist.github.com/PurpleBooth/b24679402957c63ec426) for details on our code of conduct, and the process for submitting pull requests to us.


## Authors

* **Peter Schmidtke** - *Initial work* - [pschmidtke](https://github.com/pschmidtke)
* **Vincent Le Guilloux** - *Initial work* - [pschmidtke](https://github.com/pschmidtke)


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* to be filled
