#!/usr/bin/env python3
import csv
import os
import sys
import subprocess
import matplotlib.pyplot as plt

verbose = False


def vprint(string):
    """
    The vprint function is a wrapper for the print function that only prints if
    the verbose flag is set.

    :param string: Print a string if the verbose flag is set
    :return: None
    :doc-author: Trelent
    """
    if (verbose):
        print(string)


def populate_xy(input_file):
    """
    The populate_xy function takes in a csv file and returns a list of x values, y values, and timestamps.


    :param input_file: Specify the file that we want to read from
    :return: A list of x values, y values, and timestamps
    :doc-author: Trelent
    """
    x = []
    y = []
    t = []
    with open(input_file, 'r', encoding="utf-8") as file:
        reader = csv.reader(file, delimiter=' ')
        # next(reader) # skip header row
        for row in reader:
            timestamp, x_value, y_value = row
            x.append(float(x_value))
            y.append(float(y_value))
            t.append(float(timestamp))
    return x, y, t


def remove_extension(fname):
    """
    The remove_extension function takes a file name as an argument and returns the same file name with the extension removed.

    :param fname: Specify the file name that we want to remove the extension from
    :return: A string without the file extension
    :doc-author: Trelent
    """
    last_dot_index = fname.rfind(".")
    if last_dot_index != -1:
        fname = fname[:last_dot_index]
    return fname


def prepare_alog(input_file):
    """
    The prepare_alog function takes in an alog file and runs the aloggrep command on it to process it into a csv file.
    It then returns the name of this new csv file. If the input is already a csv, then prepare_alog just returns that same
    file.

    :param input_file: Specify the alog file to process
    :return: The input file if it is a csv file and returns the output of aloggrep if it is an alog file
    :doc-author: Trelent
    """

    # Determines if a file is an alog file or a csv file (checks the header)
    def is_alog(fname):
        """Determines if a file is an alog file (checks the header for a %)

        Args:
            fname (string): file name

        Returns:
            bool: if the file is an alog, return true
        """
        return open(fname, 'r', encoding="utf-8").readline().startswith('%')

    # If the file is an alog file, run aloggrep to process it into a csv file
    if is_alog(input_file):
        output_file = remove_extension(input_file) + "_data.alog"
        output_file_real = remove_extension(input_file) + "_data.csv"
        # Remove the output file if it already exists to prevent aloggrep from asking to overwrite
        # subprocess.run(f"rm {output_file}", shell=True)
        script = "aloggrep "+input_file+" NODE_REPORT_LOCAL " \
            output_file + " -sd --format=time:val --csw --subpat=x:y "
        subprocess.run(script, shell=True, check=True)
        subprocess.run(
            f"mv {output_file} {output_file_real}", shell=True, check=True)
        return output_file_real
    # If the file is a csv file, just return it
    return input_file


def find_alogs():
    """
    The find_alogs function searches the current directory for all alog files.
    It then returns a list of strings containing the full path to each alog file.

    :return: A list of alog files in the current directory
    :doc-author: Trelent
    """
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
            if (file.endswith(".alog") and not file.__contains__("SHORESIDE")):
                alog_files.append(os.path.join(root, file))
    return alog_files


def alog_vname(alog_file):
    """
    The alog_vname function returns the vehicle name from an alog file.

    :param alog_file: Specify the alog file to be used
    :return: The vehicle name from an alog file
    :doc-author: Trelent
    """
    script = "aloggrep "+alog_file + \
        " NODE_REPORT_LOCAL --v --final --format=val --subpat=name"
    vname = subprocess.run(
        script, shell=True, capture_output=True, check=True).stdout.decode('utf-8')
    assert type(vname) == str, "Error: subprocess.run returns non-string type"
    assert not (vname.__contains__(" exiting")
                ), f"Error: {script} exitied with error: {vname}"
    return vname


def alog_mhash(alog_file):
    """Returns mission hash from alog

    Args:
        alog_file (string): input file name

    Returns:
        string: mission hash
    """    """Returns the mission hash"""
    script = "aloggrep "+alog_file + \
        " MISSION_HASH --v --final --format=val --subpat=mhash"
    hash = subprocess.run(script, shell=True,
                          capture_output=True, check=True).stdout.decode('utf-8').strip()
    assert not (hash.__contains__(" exiting")
                ), f"Error: {script} exitied with error: {hash}"
    assert isinstance(
        hash, str), "Error: subprocess.run returns non-string type"
    return hash


def extract_files():
    """Finds all algo files (or uses the ones provided)

    Returns:
        list of strings, string: paths to each file, figure name
    """
    files = []
    figname = "figure.png"
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
    """
    The handle_no_alogs function is used to find alog files in the current directory.
    If no alogs are found, it will print an error message and exit with a status of 1.
    Otherwise, it will return a list of all the alog files found.

    :param to_find_alogs: Determine if the user wants to find alogs or not
    :return: A list of alog files
    :doc-author: Trelent
    """
    alog_files = []
    if (to_find_alogs):
        alog_files = find_alogs()
        print("Found alogs: ")
        for alog in alog_files:
            print("\t"+alog)

    # no alogs specified or found
    if (len(alog_files) == 0):
        if (to_find_alogs):
            print("Error: no alog files found. Use -h or --help for usage.")
        else:
            print("Error: no alog files specified. Use -h or --help for usage.")
        exit(1)
    return alog_files


def plot_alogs(alogs, figname, ignore_hash, file_type):
    """
    The plot_alogs function takes in a list of alog files and plots them.
    It will also save the plot as a file with the name specified by figname.
    If no figure name is given, it will use the mission hash (if all alogs have same hash) or &quot;figure&quot; if not.
    The function can take in multiple arguments for alogs, but they must be separated by spaces.

    :param alogs: Pass in the alog files to be plotted
    :param figname: Set the name of the figure
    :param ignore_hash: Ignore the hash of the alog files
    :param file_type: Determine the file type of the output figure
    :return: A tuple of the mission hash and figure name
    :doc-author: Trelent
    """
    mhash = ""

    if (file_type == ""):
        file_type = "png"

    legends = set()
    for arg in alogs:
        # converts to csv if necessary
        alog_file = prepare_alog(arg)
        legend_name = alog_vname(arg)
        x, y, t = populate_xy(alog_file)
        subprocess.run(f"rm {alog_file}", shell=True, check=True)

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
        if (mhash == ""):
            mhash = alog_mhash(arg)
        else:
            if not (ignore_hash or mhash == alog_mhash(arg)):
                print("Error: alog files have different mission hashes: \n\t" +
                      mhash+"\t"+alog_mhash(arg))
                print(" Use -i or --ignore-hash to ignore this error")
                exit(1)
            # if there is no figure name, use the mission hash
            if (figname == ""):
                figname = mhash+"."+file_type
                print("Using hash as figure name: "+figname)

    # ensure some figure name is set (no hash and no argument for figurename)
    if (figname == ""):
        figname = "figure."+file_type
    plt.legend()
    plt.savefig(figname)


def display_help():
    """Prints out all help info.
    """
    print(
        "Usage: alog2png.py --fname=figure [OPTIONS] [file1] [file2] ... [fileN] ")
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
    """
    The main function is the entry point of this program.
    It takes in command line arguments and plots the data from alog files.

    :return: Nothing
    :doc-author: Trelent
    """
    arg = []
    alog_files = []
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
            vprint("\tUsing figure name: "+figname)
            continue
        if (arg.startswith("--ftype")):
            file_type = arg[len("--ftype="):]
            vprint("\tUsing figure type: "+file_type)
            continue
        if (arg.startswith("--ignorehash") or arg.startswith("-i")):
            ignore_hash = True
            vprint("\tIgnoring mhash")
            continue
        if (arg.startswith("--auto") or arg.startswith("-a")):
            to_find_alogs = True
            vprint("\tFind alogs...")
            continue
        if (arg.endswith(".alog") or arg.endswith(".csv")):
            alog_files.append(arg)
            vprint("\tGiven alog file: "+arg)
            continue
        assert False, "alog2image.py error: " + arg + \
            " is not a valid argument. Use -h or --help for usage."

    if len(alog_files) == 0:
        alog_files = handle_no_alogs(to_find_alogs)
    plot_alogs(alog_files, figname, ignore_hash, file_type)


if __name__ == '__main__':
    """Main function
    """
    main()
