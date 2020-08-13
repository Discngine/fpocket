from multiprocessing import Pool
import subprocess
import os
import time


def run_command(mr):
    max_rads = [6.2,7.0,7.8,8.6,9.4,10.2]
    clust_methods = ['s','m','a']
    #max_rad = 6.2
    #clust_method = 's'
    distance = 2.4

    for max_rad in max_rads:
        for clust_method in clust_methods:
            command = "bin/tpocket -L data/bird_test.txt -m {} -M {} -C {} -D {} -o result_stats/m{}_M{}_C{}_D{}_stats_p -g result_stats/m{}_M{}_C{}_D{}_stats_g".format(mr,max_rad,clust_method,distance,mr,max_rad,clust_method,distance,mr,max_rad,clust_method,distance)
            subprocess.Popen(command, shell=True)



def main():
    min_rad = [3.4,3.6,3.8,4.0,4.2,4.4,4.6]
    pool = Pool()
    pool.map(run_command,min_rad)

main()