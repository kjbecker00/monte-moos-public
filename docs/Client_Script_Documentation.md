# Client documentation  
Documentation for each script used by the client.  

## client_loop.sh  
1. Runs one iteration of `run_next.sh` and checks its exit code  
    - Once a day (and on the first iteration), it will force an update on all repos (removes the `--noup` flag to update)
    - Checks the exit code of `run_next.sh` for bad jobs, empty queue, or script errors
    - Checks for a `force_quit` file in the monte-moos directory. Quits if it exists
    - Updates a `status.txt` file which populates the status of the job being run with a timeestamp

## run_next.sh  
1. Removes cache `.built_dirs` text file to force all moos-ivp trees to update (unless `--noup` flag is set)
2. Updates the `repo_links.txt` file from the host
<!-- - wget's the `repo_links.txt.enc` file from the host
- Decrypts the `repo_links.txt.enc` file -->
3. Updates the job queue  
<!-- - wget's the `host_job_queue.txt.enc` file from the host
- Decrypts the `host_job_queue.txt.enc` file -->
4. Determine which job to run
    - Finds the first job in `host_job_queue.txt` with runs remaining
       - Skips the job if it's in the `bad_jobs.txt` file
       - 25% chance it ignores the first job and goes to the next
<!-- - If no jobs have runs remaining, exits with code 1 -->
5. Updates the local job dir
    - wget, decrypt, unzip `job_job_dir_name.tar.gz.enc`
<!-- 5. Updates the queue file (part of TODO: enables the client to run jobs even if it looses internet temporarialy. Not fully implemented yet) -->
6. Runs `run_job.sh` and checks the exit code


## run_job.sh
1. Checks the job file with `check_job.sh`
2. Updates the moos-dirs used in this job with `update_moos_dirs.sh`, adds them to the cache file (`.built_dirs`)
   - Skips over any directory already in `.built_dirs` file
3. Runs the job using `xlaunch_job.sh`
<!-- - Exit code 0: job ran successfully
- Exit code 2: job timed out. Notifies the user, but otherwise ignored -->
4. Runs `extract_results.sh` post-processing script
    - Calls the job_dir's `post_process_results.sh` script
    - Copies the results to oceanai yodacora (note: requires the ssh key)
    - Cleans monte-moos with `clean.sh`
This script also updates `status.txt` along the way.  
<!-- - If the copy to yodacor is sucessful, deletes the results -->

## xlaunch_job.sh
1. Sources the job file (to add its configuration variables to the namespace of `xlaunch_job.sh`)
2. Add monte-moos's version of moos-ivp to the path (temporarily)
    - `moos-dirs/moos-ivp/bin`
    - `moos-dirs/moos-ivp/scripts`
    - `moos-dirs/moos-ivp/ivp/scripts`
3. Launch shoreside and each vehicle with `source_launch.sh`
<!-- - Arguments:
    - *launch script name*
    - *repository name*
    - *mission directory*
    - *launch script flags* -->
5. Poke the mission with the contents of *$START_POKE* (or use default)
6. Keep checking the mission's exit conditions (from *$SHORE_TARG* in the job file)
    - uQueryDB or the job file's *$JOB_TIMER*, whichever comes first


## source_launch.sh
1. Temporarially update...
   - *$IVP_BEHAVIOR_DIRS*
   - *$PATH*  
     As a means of temporarially installing the given moos-ivp-extend tree
2. Run the provided *$SCRIPTNAME* (ex: launch_shoreside.sh) with the given flags 


## update_dirs.sh
Updates the overlap between `repo_links.txt` and the provided job
- Parses through all `repo_links.txt` files starting from the same dir that has the job file. 
    - Useful if you want all of your jobs to use your personal moos-ivp repo
<!-- 1. git pull `monte-moos`
2. svn up on `moos-ivp`
3. Loop through each line in `repo_links.txt`
    - Skip over each repo that is already in `.built_dirs`
    - Skip over each repo that is not in the given job
    - Handle a git repo
        - If it does not exist `moos-dirs`, git clone
        - If it does exist in `moos-dirs`, git pull
    - Handle a local repo (NOTE: Possible, but not recommended since every client will need that repo to run that job)
        - If `.git` exists, git pull
        - If `.svn` exists, svn up
    - run build.sh on the repo
    - Add the repo to `.built_dirs` -->


## extract_results.sh
1. Calls the job_dir's `post_process_results.sh` script
    - This user-written script (should) write files to `monte-moos/results/job_dir/job_name/job_name_hash/`
2. Copies the results to yodacora on oceanai (note: requires the ssh key)
3. Runs clean.sh to remove unnecessary logs




