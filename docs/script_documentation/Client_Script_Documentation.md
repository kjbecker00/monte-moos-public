# Client documentation  
Documentation for each script used by the client. For visual documentation host scripts, see [client_script_outlines.pdf](client_script_outlines.pdf)  

## client_loop.sh  
1. Runs one iteration of `run_next.sh` and checks its exit code  
    - Once a day (and on the first iteration), it will force an update on all repos (removes the `--noup` flag to update)
    - Checks the exit code of `run_next.sh` for bad jobs, empty queue, or script errors
    - Checks for a `force_quit` file in the monte-moos directory. Quits if it exists
    - Updates a `status.txt` file and pushes it to the host
        - Contains timestamped info about what the client is doing

## run_next.sh  
1. Removes cache `.built_dirs` text file to force all moos-ivp trees to update (unless `--noup` flag is set)
2. Updates `monte-moos/repo_links.txt` file from the host
3. Updates the job queue from the host
4. Determine which job to run
    - Finds the first job in `host_job_queue.txt` with runs remaining  
       - Skips the job if it's in the `bad_jobs.txt` file  
       - 25% chance it ignores this job and goes to the next one  
- If no jobs have runs remaining, exits with code 1
5. Updates the relavent job dir (`monte-moos/job_dirs/job_dir_name`)
    - wget, decrypt, unzip `job_dir_name.tar.gz.enc`
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
3. Add *$EXTRA_BIN_DIRS*, and *$EXTRA_LIB_DIRS* temporarily to the path
    - `moos-dirs/moos-ivp-extraBinDir/bin` gets added to $PATH for every MOOSDB
    - `moos-dirs/moos-ivp-extraLibDir/lib` gets added to $IVP_BEHAVIOR_DIRS for every MOOSDB
3. Launch shoreside and each vehicle with `source_launch.sh`
5. Poke the shoreside with the contents of *$START_POKE*
6. Keep checking the mission's exit conditions (from *$SHORE_TARG* in the job file)
    - uQueryDB or the job file's *$JOB_TIMER*, whichever comes first
7. Kill the mission

## source_launch.sh
1. Temporarially update *$IVP_BEHAVIOR_DIRS* and *$PATH* as a means of temporarially installing the given moos-ivp-extend tree.
   - Note: source_launch.sh ONLY adds one repo to the path
2. Runs the provided *$SCRIPTNAME* (ex: launch_shoreside.sh) with the given flags 


## update_dirs.sh
Updates the overlap between `repo_links.txt` and the provided job
    - Parses through all `repo_links.txt` files starting from the same dir that has the job file. 
        - Useful if you want all of your jobs to use your personal moos-ivp repo
1. Finds every repo_links.txt file in every parent directory of the job file...  
2. In each of those files, it loops through each repo...  
3. Each repo is then handled:
    - If the repo doesn't exist in `moos-dirs`:
        - Linked (if given a local path)
        - Git clone (if given a git repo)
        <!-- - SVN co (if given an svn repo) -->
    - else (the repo exists):
        - git pull (if it's a git repo)
        - svn up (if it's an svn repo)
    - Then it is built with `./build.sh` and added to the cache file (`.built_dirs`)
4. Then, it checks that all repos mentioned in the job file have been built
    - If there is repo which isn't in `.built_dirs`, an error code is returned

## extract_results.sh
1. Calls the job_dir's `post_process_results.sh` script
    - This user-written script (should) write files to `monte-moos/results/job_dir/job_name/job_name_hash/`
2. Copies the results to yodacora on oceanai (note: requires the ssh key)
3. Runs clean.sh to remove unnecessary logs




