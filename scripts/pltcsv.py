#!/usr/bin/env python3
import csv
import sys
import matplotlib.pyplot as plt
from matplotlib import cm
import numpy as np


def getnum(x):
    """Returns a number from a string"""
    try:
        return float(x)
    except ValueError:
        return None


def plot_csv(input_file, figname, file_type, x_header, y_headers, plot_title):
    """Generates and saves the fiven plots"""
    # Read the data from the CSV file
    data = np.genfromtxt(input_file, delimiter=',', skip_header=1)

    # Get the header from the CSV file
    with open(input_file, 'r', encoding="utf-8") as csvfile:
        reader = csv.reader(csvfile)
        header = next(reader)

    try:
        header = [x.strip() for x in header]
        x_column = header.index(x_header)
    except ValueError:
        print(f"Error: {x_header} not found in header")
        x_column = None

    y_columns = [header.index(y_header)
                 for y_header in y_headers if y_header in header]

    # column 0 is just jobName_hash
    if x_column is None:
        x_column = 1
    if y_columns == []:
        y_columns = [i for i in range(1, len(header)) if i != x_column]

    # Get the x data
    x = data[:, x_column]

    # Get the y data and plot it
    norm = plt.Normalize(0, len(y_columns)-1)
    cmap = cm.ScalarMappable(norm=norm, cmap='rainbow')
    max_len = max(len(data[:, y_col]) for y_col in y_columns)
    if max_len > 1000:
        marker = ","
        size = 1
    elif max_len > 100:
        marker = "."
        size = 10
    else:
        marker = "o"
        size = 40
    for i, y_column in enumerate(y_columns):
        y = data[:, y_column]
        plt.scatter(x, y, color=cmap.to_rgba(
            i), label=header[y_column], marker=marker, s=size)

    # ensure some figure name is set (no hash and no argument for figurename)
    if figname == "":
        figname = "figure."+file_type
    plt.xlabel(header[x_column])
    plt.legend()
    plt.title(plot_title)
    plt.savefig(figname)
    plt.clf()


def display_help():
    """Prints help for use on command line"""
    print("Usage: pltcsv.py --fname=figure [OPTIONS] [file].csv                    ")
    print("     This python script will input a csv and plot the values            ")
    print("     --fname=<figure.png>    The name of the output figure. Defaults to ")
    print("                             figure.                                    ")
    print("                             Note: the file extension must be supported ")
    print("                             by matplotlib.pyplot.savefig()             ")
    print("                             (png, jpg, jpeg, tiff, pdf, eps, svg)      ")
    print("     --ftype=<png>           If the figure type is not specified, this  ")
    print("                             will force a specific file type.           ")
    print("     -x=a,b                  Which vairables to make plots for where    ")
    print("                             each var is the x axis.                    ")
    print("     -y=c,d,e;f,g            Which variabes to plot on the y axis given ")
    print("                             an x (this plots c,d,e vs a and f,g vs b)  ")
    print("     --title=<something>     Title printed on the graph                 ")
    print(" Example usage:                                                         ")
    print(" pltcsv.py --fname=figure.png -x=0 -y=1,3,2,4 --title=\"Title\" file.csv")


def main():
    """Handles args, run on cmd line"""
    arg = []
    input_file = ""
    figname = ""
    file_type = ""
    plot_title = ""
    y_plots = []
    x_cols = []
    for (i, arg) in enumerate(sys.argv):
        # skip over the name of this script
        if i == 0:
            continue
        if arg.startswith("-h") or arg.startswith("--help"):
            display_help()
            exit(0)
        if arg.startswith("--fname="):
            figname = arg[len("--fname="):]
            continue
        if arg.startswith("--ftype"):
            file_type = arg[len("--ftype="):]
            continue
        if arg.startswith("--title"):
            plot_title = arg[len("--title="):]
            continue
        if arg.startswith("-x"):
            x_cols = [x.strip() for x in arg[len("-x="):].split(";")]
            continue
        if arg.startswith("-y"):
            y_plots = [[y.strip() for y in ys.split(",")]
                       for ys in arg[len("-y="):].split(";")]
            continue
        if arg.endswith(".csv"):
            input_file = arg
            continue
        assert False, f"Error: {arg} is not a valid argument. Use -h or --help for usage."

    if input_file == "":
        assert False, "Error: no input file specified. Use -h or --help for usage."

    if len(y_plots) != 1:
        assert len(x_cols) == len(
            y_plots), "Error: Number of x variables must equal number of y plots (seperate x's with ',' and seperate y plots with ';')"
    if len(x_cols) == 1:
        plot_csv(input_file, figname, file_type,
                 x_cols[0], y_plots[0], plot_title)
    else:
        for i, x_col in enumerate(x_cols):
            if len(y_plots[i]) == 1:
               fname = figname+"_"+x_col+"_"+y_plots[i][0]+f"_{i}"
            else:
               fname = figname+"_"+x_col+"_"+f"{i}"
            plot_csv(input_file, fname, file_type,
                     x_col, y_plots[i], plot_title)


if __name__ == '__main__':
    main()
