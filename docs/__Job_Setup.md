# Writing a Job
1. Go to the **monte-moos/job_dirs** directory on the client.
    1. make a new subdirectory for yourself (recommended ex: `mkdir kerbs`)
        - make new subdirectories as you see fit (ex: `mkdir kerbs/unit_tests/alpha_unit_tests`)
    2. See [example_files](example_files) for a template of how to structure your directory
        - Include non-zero exit conditions in your launch script to catch errors.
    3. Write your desired `post_process_results.sh` script in same directory as your **job** file (see the [example](example_files/example_job_dir/post_process_results.sh))
        - If not provided in the same dir as the job_file, monte-moos will keep checking parent directories until it finds a post_process_results.sh script.

# Creating your repo_links file(s)
1. Populate your new **job_dirs** directory with `repo_links.txt` files that contain links to each repo used by the jobs
    - Each line should look like:
        - `git@github.com:kjbecker00/moos-ivp-ktm.git` or
        - `https://github.com/username/moos-ivp-extend.git`
    - If you want to clone a private github/gitlab repo, use a personal access token (see the [guide for github PATs](private_github_repo.md)).
    - When a job is run, the `repo_links.txt` files in the **job_file**'s parent directories are parsed
        - This is useful if you have multiple jobs using one repo
        - Example: `job_dirs/kerbs/alpha_job` will use these files to find all required repositories to be run:
            - `monte-moos/repo_links.txt`
            - `monte-moos/job_dirs/repo_links.txt`
            - `monte-moos/job_dirs/kerbs/repo_links.txt`

# Checking your Job
<!-- Don't be afraid to increase the verbosity using `-v` or `-v=<number>` flags in any of the following scripts. -->
1. `./check_job.sh job_dirs/path/to/job/job_name` to check your job for initial errors. Each script will guide you through the remaining steps.
2. `./client_scripts/run_job.sh job_dirs/path/to/job/job_name` to run your job on your local computer      
    - Make sure that it runs as expected. See the [job troubleshoting guide](job_troubleshooting.md).
3. `./client_scripts/extract_results.sh job_dirs/path/to/job/job_name` to test your *post_process_results.sh* script  
    - The *post_process_results.sh* script is written by you, but remember it may be run on any computer - so keep the dependencies minimal!

# Queueing your Job
1. Be sure that your job works (on your computer AND a PABLO).
    - Once it gets queued, the clients will start running it. **Any errors will blacklist your job** for the day or until the client reboots.  
2. **COPY your new job, post_processing_script.sh, AND repo_links.txt files to the host's monte-moos directory**
    - `rsync -zaPr job_dirs/path/to/directory uname@oceanai.mit.edu:/path/to/monte-moos_repo/monte-moos/job_dirs/path/to/directory`
    - When a client runs, **it will overwrite its job_dirs** with the host's job_dirs. Be careful!
    - As a backup, you can still retrieve the last two `job_dirs/` from `.deleted_job_dirs/` and `.deleted_job_dirs2/`
2. Add the jobs you want to run to the `host_job_queue.txt` file
    - Each line should look like: `path/to/job/job_name` (don't include `job_dirs/` in the path)
    - Comment out/delete jobs that have been completed from the queue


