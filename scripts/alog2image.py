#!/usr/bin/env python3
import csv
import os
import sys
import subprocess
import matplotlib.pyplot as plt

# Takes in a csv file and returns a list of x values, y values, and timestamps
def populate_xy(input_file):
    x = []
    y = []
    t = []
    with open(input_file, 'r') as file:
        reader = csv.reader(file, delimiter=' ')
        # next(reader) # skip header row
        for row in reader:
            timestamp, x_value, y_value = row
            x.append(float(x_value))
            y.append(float(y_value))
            t.append(float(timestamp))
    return x, y, t

# Removes the .alog or .csv extension from a file name
def remove_extension(fname):
    last_dot_index = fname.rfind(".")
    if last_dot_index != -1:
        fname = fname[:last_dot_index]
    return fname

# Runs aloggrep to process an alog file into a csv file
def prepare_alog(input_file):
    # Determines if a file is an alog file or a csv file (checks the header)
    def is_alog(fname):
        return open(fname, 'r').readline().startswith('%')

    # If the file is an alog file, run aloggrep to process it into a csv file
    if is_alog(input_file):
        output_file = remove_extension(input_file) + "_data.alog"
        output_file_real = remove_extension(input_file) + "_data.csv"
        # Remove the output file if it already exists to prevent aloggrep from asking to overwrite
        # subprocess.run(f"rm {output_file}", shell=True)
        script = f"aloggrep {input_file} NODE_REPORT_LOCAL {output_file} -sd --format=time:val --csw --subpat=x:y "   
        subprocess.run(script, shell=True)
        subprocess.run(f"mv {output_file} {output_file_real}", shell=True)
        return output_file_real
    # If the file is a csv file, just return it
    return input_file

# Finds all alog files in the current directory
def find_alogs():
    alog_files = []
    path = os.getcwd()
    for root, dirs, files in os.walk(path):
        # ignore subdirectories that begin with a period
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        # ignore these subdirectories as well
        dirs[:] = [d for d in dirs if not d == 'src']
        dirs[:] = [d for d in dirs if not d == 'bin']
        dirs[:] = [d for d in dirs if not d == 'build']
        dirs[:] = [d for d in dirs if not d == 'lib']
        dirs[:] = [d for d in dirs if not d == 'scripts']
        
        for file in files:
            if(file.endswith(".alog") and not file.__contains__("SHORESIDE")):
                alog_files.append(os.path.join(root,file))
    return alog_files

# Returns the vehicle name from an alog file
def alog_vname(alog_file):
    script = f"aloggrep {alog_file} NODE_REPORT_LOCAL --v --final --format=val --subpat=name"
    vname = subprocess.run(script, shell=True, capture_output=True).stdout.decode('utf-8')
    assert type(vname) == str, "Error: subprocess.run returns non-string type"
    assert not(vname.__contains__(" exiting")), f"Error: {script} exitied with error: {vname}"
    return vname

# Returns the mission hash
def alog_mhash(alog_file):
    script = f"aloggrep {alog_file} MISSION_HASH --v --final --format=val --subpat=mhash"
    hash = subprocess.run(script, shell=True, capture_output=True).stdout.decode('utf-8').strip()
    assert not(hash.__contains__(" exiting")), f"Error: {script} exitied with error: {hash}"
    assert type(hash) == str, "Error: subprocess.run returns non-string type"
    return hash

# Finds all alog files or uses the ones provided
def extract_files(args):
    files = []
    figname="figure.png"
    for (i, arg) in enumerate(sys.argv):
        # skip over the name of this script
        if (i == 0):    
            continue
        # save the figure output name
        if (arg.__contains__("figname=")):
            figname = arg[len("figname="):]
            continue
        files.append(arg)
    if (len(files) == 0):
        files = find_alogs()
    return files, figname


def handle_no_alogs(to_find_alogs):
    # attempts to find alogs if the user specified it
    alog_files = []
    if (to_find_alogs):
        alog_files = find_alogs()
        print("Found alogs: ")
        for alog in alog_files:
            print("\t"+alog)

    # no alogs specified or found
    if (len(alog_files) == 0):
        if (find_alogs):
            print("Error: no alog files found. Use -h or --help for usage.")
        else:
            print("Error: no alog files specified. Use -h or --help for usage.")
        exit(1)
    return alog_files


def plot_alogs(alogs, figname, ignore_hash, file_type):
    hash = ""

    if (file_type == ""):
        file_type="png"
    
    legends = set()
    for arg in alogs:
        # converts to csv if necessary
        alog_file = prepare_alog(arg)
        legend_name=alog_vname(arg)
        x,y,t = populate_xy(alog_file)
        subprocess.run(f"rm {alog_file}", shell=True)

        if (len(x) == 0) or (len(y) == 0):
            continue

        # Handles the case where the vehicle name is empty
        # Will attempt to assign incrementing numbers to each vehicle
        if (len(legend_name) == 0):
            legend_name = "0"

        if (legend_name in legends):
            # if it ends in a number, increment it. Otherwise, add a 2 to the end
            if (legend_name[-1].isdigit()):
                legend_name = legend_name[:-1] + str(int(legend_name[-1])+1)
            else:
                legend_name += "2"
        legends.add(legend_name)

        plt.plot(x, y, label=legend_name)
        if (hash == ""):
            hash = alog_mhash(arg)
        else:
            if (not(ignore_hash or hash == alog_mhash(arg))):
                print("Error: alog files have different mission hashes: \n\t"+hash+"\t"+alog_mhash(arg))
                print(" Use -i or --ignore-hash to ignore this error")
                exit(1)
            # if there is no figure name, use the mission hash
            if (figname == ""):
                figname = hash+"."+file_type
                print ("Using hash as figure name: "+figname)
    
    # ensure some figure name is set (no hash and no argument for figurename)
    if (figname == ""):
        figname = "figure."+file_type
    plt.legend()
    plt.savefig(figname)

    

def display_help():
    print("Usage: alog2png.py --fname=figure [OPTIONS] [file1] [file2] ... [fileN] ")
    print("     This python script will input several alog files, read the local   ")
    print("     node reports of each alog file, and plot the x and y values of each")
    print("     alog file on a graph. If no files are specified, it will pull all  ")
    print("     alog files in the current directory and all subdirectories.        ")
    print("                                                                        ")
    print("     --ignorehash -i         Ignores if the mission hash is different   ") 
    print("                             between alog files.                        ") 
    print("     --auto -a               Finds all alogs in the current directory   ") 
    print("                             and all subdirectories.                    ") 
    print("     --fname=<figure.png>    The name of the output figure. If not      ") 
    print("                             specified, it will attempt to find the last")
    print("                             mission hash. If no hash is given, the     ")
    print("                             default is figure.                         ")
    print("                             Note: the file extension must be supported ")
    print("                             by matplotlib.pyplot.savefig()             ") 
    print("                              (png, jpg, jpeg, tiff, pdf, eps, svg)     ")
    print("     --ftype=<png>           If the figure name is not specified, this  ")
    print("                             will force a specific file type. Useful    ") 
    print("                             when using the mission hash as the filename")



def main():
    arg = []
    alog_files=[]

    figname = ""
    file_type = ""
    ignore_hash = False
    to_find_alogs = False
    for (i, arg) in enumerate(sys.argv):
        # skip over the name of this script
        if (i == 0):    
            continue
        if (arg.startswith("-h") or arg.startswith("--help")):
            display_help()
            exit(0)
        if (arg.startswith("--fname=")):
            figname = arg[len("--fname="):]
            continue
        if (arg.startswith("--ftype")):
            file_type = arg[len("--ftype="):]
            continue
        if (arg.startswith("--ignorehash") or arg.startswith("-i")):
            ignore_hash = True
            continue
        if (arg.startswith("--auto") or arg.startswith("-a")):
            to_find_alogs = True
            continue
        if (arg.endswith(".alog") or arg.endswith(".csv")):
            alog_files.append(arg)
            continue
        assert False, f"Error: {arg} is not a valid argument. Use -h or --help for usage."
    
    
    if len(alog_files) == 0:
        alog_files = handle_no_alogs(to_find_alogs)
    plot_alogs(alog_files, figname, ignore_hash, file_type)

if __name__ == '__main__':
    main()
        
