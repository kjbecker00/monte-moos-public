#!/usr/bin/env python3
import csv
import os
import sys


def merge_csv_files(main_dir, output_file, job_name):
    """Function merging all results.csv files for a given job_name to an output_file."""
    skip_dirs = set()
    skip_dirs.add(job_name)
    all_headers = set()
    data = {}

    # if os.path.exists(output_file):
    #     with open(output_file, 'r') as f:
    #         reader = csv.DictReader(f)
    #         headers = reader.fieldnames
    #         all_headers.update(headers[1:])
    #         for row in reader:
    #             skip_dirs.add(row[job_name])
    #             data[job_name] = row

    for subdir, _, files in os.walk(main_dir):
        subdir_name = os.path.basename(subdir)
        if subdir_name in skip_dirs:
            continue
        if not (job_name in subdir_name):
            continue
        for file in files:
            if file.endswith('.csv'):
                data[subdir_name] = {}
                try:
                    with open(os.path.join(subdir, file), 'r') as f:
                        reader = csv.DictReader(f)
                        headers = reader.fieldnames
                        all_headers.update(headers)
                        for row in reader:
                            data[subdir_name].update(row)
                except Exception as e:
                    print(f'Error reading file {file}: {e}')
    all_headers = sorted(list(all_headers))
    try:
        with open(output_file, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([job_name] + all_headers)
            for subdir_name, row_data in data.items():
                row = [subdir_name]
                for header in all_headers:
                    row.append(row_data.get(header, ''))
                writer.writerow(row)
    except Exception as e:
        print(f'Error writing to output file: {e}')


def display_help():
    """Function displaying all help info when run on command line."""
    print(
        "Usage: monte_merge_results.py --job=<job name> --output=<filename> -wd=[WORKING DIRECTORY]")
    print("     This python script will merge csv and plot the values                      ")
    print("     --output=<figure.png>   The name of the output file. Defaults to           ")
    print("                             results.csv                                        ")
    print("     --job=<basename(working_dir)>   The name of the job file. this is used to  ")
    print("                             add a column in the output file containing the     ")
    print("                             the job_file name. Defaults do basename(working_dir)")
    print("     -wd=<working_dir>       Working directory of this script. Defaults to \".\"  ")


def main():
    """Handles cmd line args."""
    arg = []
    working_dir = ""
    output_file = ""
    job_name = ""
    for (i, arg) in enumerate(sys.argv):
        # skip over the name of this script
        if i == 0:
            continue
        if arg.startswith("-h") or arg.startswith("--help"):
            display_help()
            exit(0)
        if arg.startswith("--output="):
            output_file = arg[len("--output="):]
            continue
        if arg.startswith("-wd="):
            working_dir = arg[len("-wd="):]
            continue
        if arg.startswith("--wd="):
            working_dir = arg[len("--wd="):]
            continue
        if arg.startswith("--job="):
            job_name = arg[len("--job="):]
            continue
        if working_dir == "":
            print("Setting working dir = "+arg)
            working_dir = arg
            continue
        assert False, "Error: " + arg + \
            " is not a valid argument. Use -h or --help for usage."

    if working_dir == "":
        working_dir = "."  # default to current dir
        # assert False, "Error: no working dir specified. Use -h or --help for usage."
    if job_name == "":
        job_name = os.path.basename(working_dir)
    if output_file == "":
        output_file = working_dir + "/results.csv"

    merge_csv_files(working_dir, output_file, job_name)


if __name__ == '__main__':
    main()
