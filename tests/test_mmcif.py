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
    os.system("bin/fpocket -f data/sample/"+pdb_code+".cif"+" "+params)
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
    os.system("bin/fpocket -f data/sample/"+pdb_code+".cif"+" "+params)
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


def fpocket_out_test_db_equal(pdb_code,params="",explicit=False):
    reference_folder="tests/reference_output/"
    os.system("bin/fpocket -f data/sample/"+pdb_code+".cif"+" "+params)
    file_list=os.listdir(reference_folder+pdb_code+"_out/")
    for filename in file_list:
        test_out='data/sample/'+pdb_code+'_out/'+filename
        reference_out=reference_folder+pdb_code+'_out/'+filename
        if filename != pdb_code+'_info.txt' and os.path.isfile(test_out):
            compare_all_but_volume(test_out,reference_out)
    os.system("rm -rf data/sample/"+pdb_code+"_out")


def test_pdb_list_mmcif_equal():
    mmcif_list = ['3VI4','5RGF','6TL9']
    for cif_code in mmcif_list:
        fpocket_out_test_default_equal(cif_code)

def test_pdb_list_mmcif_both():
    mmcif_list = ['6X3P']
    for cif_code in mmcif_list:
        fpocket_out_test_default_equal(cif_code, params="-w both")

def test_pdb_list_mmcif_plus_db():
    mmcif_list = ['123abc']
    for cif_code in mmcif_list:
        fpocket_out_test_db_equal(cif_code, params="-d")

def test_mmcif_ligand():
    mmcif_list = ['1QNH']
    for cif_code in mmcif_list:
        fpocket_out_test_default_equal(cif_code, params="-a C,D")