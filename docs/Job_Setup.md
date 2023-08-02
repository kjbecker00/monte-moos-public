# Writing a Job
1. Go to the **job_dirs** directory on the client.
    1. make a new subdirectory for yourself (ex: `mkdir uname`)
    2. make new subdirectories as you see fit (ex: `mkdir uname/unit_tests/alpha_unit_tests`)
    3. See the example jobs in the [example_files](example_files) directory for a template
        - Include non-zero exit conditions in your launch script to catch errors.
    4. Write your desired `post_process_results.sh` script in same directory as your **job** file (see the [example](example_files/example_job_dir/post_process_results.sh))
        - If not provided in the same dir as the job_file, monte-moos will keep going back directories until it finds a post_process_results.sh script.

# Creating your repo_links file
1. Populate your new **job_dirs** directory with `repo_links.txt` files that contain links to each repo that is being used
    - Each line should look like:
        - `git@github.com:kjbecker00/moos-ivp-ktm.git` or
        - `https://github.com/username/moos-ivp-extend.git` or
        -  `~/path/to/local/repo/moos-ivp-extend`
            - Note: if given a path to a repo, monte-moos will try to pull updates for this particular repo
            - These repo(s) also need to exist on **all clients**, so this is probably a bad practice if you want to get a lot of runs done quickly
    - If you want to clone a private github repo, use a personal access token (see the [guide](private_github_repo.md))
    - A job will parse all of its parent's `repo_links.txt` files, starting from the same directory as the job file
        - Helps reduce clutter from one main `repo_links.txt` file
        - Useful if you want all of your jobs to use your personal moos-ivp repo, or if you have multiple jobs 
        - Example:
            - `job_dirs/uname/alpha_job` will parse:
                - `monte-moos/repo_links.txt`
                - `monte-moos/job_dirs/repo_links.txt`
                - `monte-moos/job_dirs/uname/repo_links.txt`

# Checking your Job
Don't be afraid to increase the verbosity using `-v` or `-v=<number>` flags in any of the following scripts.
1. `./check_job.sh job_dirs/path/to/job/job_name` to check your job for initial errors
2. `./client_scripts/run_job.sh job_dirs/path/to/job/job_name` to run your job on your local computer      
    - Make sure that it runs as expected. There should be error messages in the terminal if something goes wrong   
    - If the job doesn't run but the mission does, there may be missing binary/scripts.  
        - When `./run_job.sh` is run in test mode, it removes miscelaneous `moos-ivp-extend` repos from your $PATH and $IVP_BEHAVIOR_DIRS. This is to better simulate a client which does not have the same repos installed as you. However, these errors may be hard to track
3. `./client_scripts/extract_results.sh job_dirs/path/to/job/job_name` to test your *post_process_results.sh* script  
    - Track down any errors and fix them. Don't be afraid to increase the verbosity using `-v` or `-v=<number>` flags  

# Queueing your Job
1. Be sure that your job works, because once it gets queued, it is difficult to change and the clients will start running it.
2. **COPY your new job, post_processing_script.sh, AND repo_links.txt files to the host's monte-moos directory**
    - `rsync -zaPr job_dirs/path/to/directory uname@oceanai.mit.edu:/path/to/monte-moos_repo/monte-moos/job_dirs/path/to/directory`
    - When a client runs, **it will get overwritten** with the host's monte-moos directory. Be careful!
    - As a backup, you can still retrieve the last two `job_dirs/` from `.deleted_job_dirs/` and `.deleted_job_dirs2/`
2. Add the jobs you want to run to the `host_job_queue.txt` file
    - Each line should look like: `path/to/job/job_name` (don't include `job_dirs/` in the path)
    - There is only one queue file to maintain. Keeps track of all jobs that have been run, and will be run
    - Once complete, feel free to delete/comment out the jobs that have been run

