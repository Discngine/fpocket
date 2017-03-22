import os

fh=open("components.cif","r")
data_count=0
curHetCode=""
for line in fh.readlines():
    line=line.strip()
    if (line[0:4]=="data"):
        het_code=line[5:]
    if (line[0:15]=="_chem_comp.type"):
        lastWord=line.split(" ")[-1]
        lastWord=lastWord.upper().strip("\"")
        if lastWord=="LINKING":
            data_count+=1
            print "\"%s\","%(het_code),

print ""
print data_count
fh.close
