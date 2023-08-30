#   Host Scripts
Documentation for each script used by the host. For visual documentation host scripts, see [host_script_outlines.pdf](host_script_outlines.pdf)  

## host_loop.sh  
1. Updates the queue, pushes results to the web (see `update_queue.sh`)  
2. Updates the job_dirs (see `update_job_dirs.sh`)  
3. Copies the repo_links.txt file to the web (see `update_repo_links.sh`)  
Loops until the queue is empty, or until it finds a `force_quit` file in the monte-moos directory.  
This script also updates `status.txt` along the way.  

## update_queue.sh 
Loops over each line in `host_job_queue.txt`  
For each job in the queue...  
- Determine the number of runs completed
  - It does by counting the number of directories in `yodacora/monte-moos/results/job_dir/job_name/`
- Update `host_job_queue.txt` to reflect the number of completed runs for that job
- Check if there are any new results.
  - count processed results: `yodacora/monte-moos/results/job_dir/job_name/`  
    compare with all results: `home/web/monte/results/job_dir/job_name/`  
  - If the count doesn't match for a given job:
    - Run `update_results.sh` on that job
Encrypt the `host_job_queue.txt` file, copy to the web  

## update_results.sh 
Loops through each results directory produced by the given job
- For each subdirectory (ex: `job_name_oily-hash`) in `yodacora/monte-moos/results/job_dir/job_name/*`
  - Appends the 2nd line of `job_name_oily-hash/results.csv` to the main results file (oceanai.mit.edu/monte/results/job_dir/job_name/results.csv)
  - Copies `job_name_oily-hash/web` to `oceanai.mit.edu/monte/results/job_dir/job_name/job_name_oily-hash`  
  - Everything else in `job_name_oily-hash` is kept private, and may be accessed under `yodacora/monte-moos/results/job_dir/job_name/*`
  - Tip: You can use `encrypt.sh` to encrypt a file before placing it in `job_name_oily-hash/web` for security while still maintaining ease of access

Creates `plot.png` from the **compiled** `results.csv` file

## update_job_dirs.sh 
Loops through every job_dir in `monte-moos/job_dirs/`
- Zips each job directory
- Encrypts each zipped file using the password in `monte-moos/.password`
- Moves each encrypted file to the web under `oceanai.mit.edu/monte/clients/`

## update_repo_links.sh 
- Encrypts a copy of `repo_links.txt`
- Copies the encrypted version to the web under `oceanai.mit.edu/monte/clients/`

