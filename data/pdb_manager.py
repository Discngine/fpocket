import os
import shutil
import fnmatch
from os import path
import pandas as pd

def main():
	
    out_path = "bio_assembly/BIRD"

    doss = "bio_assembly/BIRD"
    write_path = "data/bio_assembly/NO_BIRD/"
	# rename the original file
    #result = find_files("*.pdb",doss)
    my_cols = [str(i) for i in range(45)]

    data = pd.read_csv('non_BIRD.csv',sep=';|,|\t',names= my_cols,engine='python')
    	


    write_txt(data,write_path)
    '''for files in result:
    	os.rename(files,out_path+files[len(doss):-1]) '''

    '''result = find_files("*.pdb*","RCSB_test1")
    for files in result:
    	os.remove(files)'''


def find_files(pattern, search_path):
	result = []
# Wlaking top-down from the root
	for root, dir, files in os.walk(search_path):
		for filename in files:
			if fnmatch.fnmatch(filename, pattern):
				result.append(os.path.join(root, filename))
	return result


def write_txt(data,write_path):
	file = open('non_bird_test.txt','w+')
	for i in range(len(data)):
		file.write(write_path+str(data['0'][i])+'.pdb'+'   '+write_path+str(data['0'][i])+'.pdb'+'   '+ str(data['1'][i])+'\n')
	file.close()

if __name__ == "__main__":
    main()