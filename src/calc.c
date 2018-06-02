#include "../headers/calc.h"
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

