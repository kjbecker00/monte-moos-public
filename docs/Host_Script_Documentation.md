#   Host Scripts
Documentation for each script used by the host.  

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
<!--     - Does by counting subdirectories in `yodacora/monte-moos/results/job_dir/job_name/` -->
- Update `host_job_queue.txt` to reflect the number of completed runs for that job
- Run `update_results.sh` for the results of each job `yodacora/monte-moos/results/job_dir/job_name` (if they have at least one completed run)  

Encrypt the `host_job_queue.txt` file, copy to the web  
<!-- Exits with 0 if the queue is complete, 1 otherwise -->

## update_results.sh 
Loops through each results directory produced by the given job
- For each subdirectory (ex: `job_name_oily-hash`) in `yodacora/monte-moos/results/job_dir/job_name/*`
  - Appends the 2nd line of `job_name_oily-hash/results.csv` to `oceanai.mit.edu/monte/results/job_dir/job_name/results.csv`
  - Copies `job_name_oily-hash/web` to `oceanai.mit.edu/monte/results/job_dir/job_name/job_name_oily-hash`  
  - Everything else in `job_name_oily-hash` is kept private, and may be accessed under `yodacora/monte-moos/results/job_dir/job_name/*`
  - Tip: You can use `encrypt.sh` to encrypt a file before placing it in `job_name_oily-hash/web` for security and ease of access

Creates `plot.png` from the **compiled** `results.csv` file

## update_job_dirs.sh 
Loops through every job_dir in `monte-moos/job_dirs/`
- Zips each job directory
- Encrypts each zipped file using the password in `monte-moos/.password`
- Moves each encrypted file to the web under `oceanai.mit.edu/monte/clients/`

## update_repo_links.sh 
- Encrypts a copy of the base `repo_links.txt`
- Copies the encrypted version to the web under `oceanai.mit.edu/monte/clients/`


