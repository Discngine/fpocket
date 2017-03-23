#include "../headers/calc.h"

/*

## GENERAL INFORMATION
##
## FILE 					calc.c
## AUTHORS					P. Schmidtke and V. Le Guilloux
## LAST MODIFIED			28-11-08
##
## SPECIFICATIONS
##
##	Several function for calculations. CUrrently, only euclidian
##	distances are available.
##
## MODIFICATIONS HISTORY
##
##	28-11-08	(v) Comments UTD
##	01-04-08	(v)  Added comments and creation of history
##	01-01-08	(vp) Created (random date...)
##	
## TODO or SUGGESTIONS
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

*/

/**
   ## FONCTION: 
	float dist(float x1, float y1, float z1, float x2, float y2, float z2) 
  
   ## SPECIFICATION: 
	Calculate euclidian distance between two points in space p1(x1, y1, z2) and 
	p2(x2, y2, z2)
  
   ## PARAMETRES:
	@ float x1, y1, z1: The first point's coordinates.
	@ float x2, y2, z2: The second point's coordinates.
  
   ## RETURN: 
	float: the distance between p1(x1, y1, z2) and p2(x2, y2, z2)
  
*/
float dist(float x1, float y1, float z1, float x2, float y2, float z2) 
{
	float xdif = x1 - x2 ;
	float ydif = y1 - y2 ;
	float zdif = z1 - z2 ;

	return sqrt((xdif*xdif) + (ydif*ydif) + (zdif*zdif)) ;
}

/**
   ## FONCTION: 
	float ddist(float x1, float y1, float z1, float x2, float y2, float z2) 
  
   ## SPECIFICATION: 
	Calculate the square of the euclidian distance between two points in space 
	p1(x1, y1, z2) and 	p2(x2, y2, z2)
  
   ## PARAMETRES:
	@ float x1, y1, z1: The first point's coordinates.
	@ float x2, y2, z2: The second point's coordinates.
  
   ## RETURN: 
	float: the squared euclidian distance between the two points.
  
*/
float ddist(float x1, float y1, float z1, float x2, float y2, float z2) 
{
	float xdif = x1 - x2 ;
	float ydif = y1 - y2 ;
	float zdif = z1 - z2 ;

	return (xdif*xdif) + (ydif*ydif) + (zdif*zdif) ;
}

