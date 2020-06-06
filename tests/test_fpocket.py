import pytest
import os
import filecmp


def test_fpocket_basic():
    os.system("bin/fpocket -f data/sample/1UYD.pdb")
    file_list=os.listdir("tests/reference_output/1UYD_out/")
    for filename in file_list:
        if filename != '1UYD_info.txt' and filename != "pockets":
            print(filename)
            assert(filecmp.cmp('data/sample/1UYD_out/'+filename,'tests/reference_output/1UYD_out/'+filename))
    
    
    
    os.system("rm -rf data/sample/1UYD_out")

if __name__ == "__main__":
    test_fpocket_basic()