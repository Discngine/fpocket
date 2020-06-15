import pytest
import os
import filecmp

def compare_all_but_volume(fname1, fname2,equal=True):
    n=0
    nEqual=0
    with open(fname1) as f1:
        with open(fname2) as f2: 
            for line1, line2 in zip(f1, f2):
                if("olume" not in line1):
                    if line1==line2:
                        nEqual+=1
                    n+=1
    if equal:
        assert(n==nEqual)
    else:
        assert(n!=nEqual)

def fpocket_out_test_default_different(pdb_code,params=""):
    os.system("bin/fpocket -f data/sample/"+pdb_code+".pdb"+" "+params)
    file_list=os.listdir("tests/reference_output/"+pdb_code+"_out/")
    for filename in file_list:
        test_out='data/sample/'+pdb_code+'_out/'+filename
        reference_out='tests/reference_output/'+pdb_code+'_out/'+filename
        if filename != pdb_code+'_PYMOL.sh' and filename != pdb_code+'_VMD.sh' and filename != pdb_code+'.tcl' and filename != pdb_code+'.pml':
            if os.path.isfile(test_out):
                assert(not filecmp.cmp(test_out,reference_out))
            else: 
                if os.path.isfile(test_out):
                    compare_all_but_volume(test_out,reference_out)
                else: #that the pockets folder
                    pocket_file_list=os.listdir("tests/reference_output/"+pdb_code+"_out/"+filename)
                    for pocket_file_name in pocket_file_list:
                        test_out='data/sample/'+pdb_code+'_out/'+filename+'/'+pocket_file_name
                        reference_out='tests/reference_output/'+pdb_code+'_out/'+filename+'/'+pocket_file_name
                        compare_all_but_volume(test_out,reference_out,equal=False)
    os.system("rm -rf data/sample/"+pdb_code+"_out")



def fpocket_out_test_default_equal(pdb_code,params="",explicit=False):
    reference_folder="tests/reference_output/"
    if explicit:
        reference_folder="tests/reference_output/explicit/"
    os.system("bin/fpocket -f data/sample/"+pdb_code+".pdb"+" "+params)
    file_list=os.listdir(reference_folder+pdb_code+"_out/")
    for filename in file_list:
        test_out='data/sample/'+pdb_code+'_out/'+filename
        reference_out=reference_folder+pdb_code+'_out/'+filename
        if filename != pdb_code+'_info.txt' and os.path.isfile(test_out):
            assert(filecmp.cmp(test_out,reference_out))
        else: 
            if os.path.isfile(test_out):
                compare_all_but_volume(test_out,reference_out)
            else: #that the pockets folder
                pocket_file_list=os.listdir(reference_folder+pdb_code+"_out/"+filename)
                for pocket_file_name in pocket_file_list:
                    test_out='data/sample/'+pdb_code+'_out/'+filename+'/'+pocket_file_name
                    reference_out=reference_folder+pdb_code+'_out/'+filename+'/'+pocket_file_name
                    compare_all_but_volume(test_out,reference_out)
    os.system("rm -rf data/sample/"+pdb_code+"_out")

def test_pdb_list_equal():
    """
    Test a list of PDB codes with fpocket default parameters and compare all result files to reference files
    """
    pdb_list=['1UYD','3LKF','1ATP','4URL','5WA6','7TAA']
    for pdb_code in pdb_list:
        fpocket_out_test_default_equal(pdb_code)

def test_pdb_list_different():
    """
    Test a list of PDB codes with fpocket and different alpha sphere sizes
    to see that results are different to reference results obtained with default
    parameters
    """
    pdb_list=['1UYD','3LKF','1ATP','4URL','5WA6','7TAA']
    for pdb_code in pdb_list:
        fpocket_out_test_default_different(pdb_code,params="-m 2.8 -M 7.4")
    
def test_pdb_list_different_clustering():
    """
    Test a list of PDB codes with fpocket and different clustering parameters
    to see that results are different to reference results obtained with default
    parameters
    """
    pdb_list=['1UYD','3LKF','1ATP','4URL','5WA6','7TAA']
    for pdb_code in pdb_list:
        fpocket_out_test_default_different(pdb_code,params="-e b -C c")
    
def test_pdb_list_different_clustering_threshold():
    """
    Test a list of PDB codes with fpocket and different clustering distances
    to see that results are different to reference results obtained with default
    parameters
    """
    pdb_list=['1UYD','3LKF','1ATP','4URL','5WA6','7TAA']
    for pdb_code in pdb_list:
        fpocket_out_test_default_different(pdb_code,params="-D 3.6")



def test_drop_chain():
    """
    Test a list of chains to drop from a pdb file
    """
    pdb_list=['2P0R']
    for pdb_code in pdb_list:
        fpocket_out_test_default_equal(pdb_code,params="-c D")
        fpocket_out_test_default_equal(pdb_code,params="--drop_chains D")

    
    
def test_explicit_pocket_detection():
    """
    Test fpocket explicit pocket detection of the PU8 binding site.
    """
    pdb_list=['1UYD']
    for pdb_code in pdb_list:
        fpocket_out_test_default_equal(pdb_code,params="-r 1224:PU8:A",explicit=True)
    

