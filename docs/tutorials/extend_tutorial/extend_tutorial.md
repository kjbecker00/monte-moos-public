# Extend tutorial - UNTESTED FILES!!!!
**Learn how to run a multiple MOOSDB mission on monte-moos**


***CAUTION***- when preparing your jobs (ex: throughout this tutorial), DO NOT start the `client_loop.sh` script. It WILL override progress that was not pushed to the host. As a backup, the two most recent backups of this directory are stored in `.deleted_job_dirs/` and `.deleted_job_dirs2/` (but please don't rely on this...)

## 1. Writing a Job file
### a) Directory Structure
To begin, make a subdirectory for all of your personal jobs.  
`mkdir -p job_dirs/kerbs`

Now, make another subdirectory for this specific job.
`cd ~/monte-moos/job_dirs/kerbs`  
`mkdir -p tutorials/berta_tutorial`

### b) Creating the Job File

Create a new file called *extend_job* in your new directory.
`touch extend_job`

Open the file in your favorite text editor and paste the following:
TODO: finish this file, add dummy extend trees for people to test
<!-- ```bash
#!/bin/bash 
# Kevin Becker, June 9 2023
# extend_job

# ######################################
# # Launching shoreside                #
# ######################################
# SHORE_REPO="moos-ivp"
# SHORE_MISSION="ivp/missions/m2_berta"
# SHORE_FLAGS=" 5"  
# JOB_TIMEOUT=60 # (timewarp is not accounted)
# # SHORE_TARG is not required- will default to targ_shoreside.moos

# ######################################
# # Launching vehicles                 #
# ######################################
# VEHICLES=2
# VEHICLE_REPOS=("moos-ivp" "moos-ivp")
# VEHICLE_MISSIONS=("missions/s1_alpha" "missions/m2_berta_baseline")
# SHARED_VEHICLE_FLAGS=" --ip-localhost --shore_pshare=9200 -s -a 5"
# VEHICLE_FLAGS=( "--start=3,3 --vrole=rescue --vname=abe --tmate=ben --mport=9001 --pshare=9201" 
#                 "--start=3,2 --vrole=scout  --vname=ben --tmate=abe --mport=9002 --pshare=9202"  
#             )

# PLOT_X="SOME_MOOS_VAR"
# PLOT_Y="OTHER_MOOS_VAR"
```
You'll notice some differences from the alpha mission:
- **VEHILCES**: The number of vehicles to be run
- **VEHICLE_REPOS**: The name of the repository that contains the mission for each vehicle
- **VEHICLE_MISSIONS**: The path to the mission file within the repository for each vehicle
- **VEHICLE_FLAGS**: Any flags you want to pass to the launch script for all vehicles
- **SHARED_VEHICLE_FLAGS**: Any flags you want to pass to the launch script for the given vehicle
- **SHORE_TARG**: Unnecessary for most multi-MOOSDB missions, since it defaults to **targ_shoreside.moos**
- **PLOT_X**: TODO: find good variables from berta mission
    - See part 2 section C for more info
- **PLOT_Y**: TODO: find good variables from berta mission
    - See part 2 section C for more info


## 2. Writing a post-processing script

### a) Copy the template
Copy the template *post_process_results* file to the same directory as your job file.  
`cp docs/template_files/post_process_results_template.sh job_dirs/KERBS/tutorials/berta_tutorial/post_process_results.sh`
 - This is a bit daunting, but it's got a lot of useful features!

### c) Modify the script
Go to **Part 3** and edit which variables you want to save to the **results.csv** file. Included are examples using **aloggrep** to pull the final value of a given variable. Feel free to edit this as you see fit!  
- NOTE: Make sure **WPT_EFF_DIST_ALL** and **WPT_EFF_TIME_ALL** are included in the **results.csv** file. These are needed to plot the results.

**Part 4** copies all alog files to the web directory, generates a plot showing where each vehicle went, and a few metafiles about the client who ran the job. If you have lots of runs, I'd recommend adding an if statement to only copy the alog files for interesting runs (ex: runs that had collisions). 


## 3. Writing repo_links.txt

## 4. Checking your Job
Use the following scripts to test your job before queueing it:
1. `./check_job.sh job_dirs/kerbs/tutorials/berta_tutorial/berta_job` to check your job for initial errors. 
    - This will guide you through the remaining steps! But here they are anyways:
2. `./client_scripts/run_job.sh job_dirs/kerbs/tutorials/berta_tutorial/berta_job` to run your job on your local computer.  
    - Make sure that it runs as expected. See the [job troubleshoting guide](job_troubleshooting.md).
3. `./client_scripts/extract_results.sh job_dirs/kerbs/tutorials/berta_tutorial/berta_job` to test your *post_process_results.sh* script  
    - The *post_process_results.sh* script is written by you, but remember it may be run on any computer - so keep the dependencies minimal!
4. Review the **results** directory to make sure the data you want is there

## 5. Queueing your Job

### a) Check your job- *again*
Be sure that your job works on your computer AND a PABLO. **Any errors in a queue'd job will blacklist the job** for the day or until the client reboots.  

### b) Copying to the host
`rsync -zaPr job_dirs/kerbs/tutorials/berta_tutorial/berta_job uname@oceanai.mit.edu:/home/monte/monte-moos/job_dirs/kerbs/tutorials/berta_tutorial/berta_job`  

### c) Add to the queue
ssh onto the host, and open the file:  
`/home/monte/monte-moos/host_job_queue.txt`

Add 5 runs of your job to the job queue:  
`kerbs/tutorials/berta_tutorial/berta_job 5`

## 6) Waiting for your job

### a) Check the status of the clients
When you're waiting, you can check the status of the clients in:
`/home/monte/monte-moos/clients/status/*`

Here's a script to add to your oceanai **.bashrc** to make this easier:
```
catstat () {
  for file in /home/yodacora/monte-moos/clients/status/*
    do
      if [[ -f "$file" ]]
        then
          if [[ "$file" == *.txt ]]
            then
              echo -n "$(tput bold)$(tput setaf 2)$(basename $file)$(tput sgr0)"
              echo "  $(cat $file)"
          fi
        fi
    done
}
```

You can also view the last time the host updated the clients by checking the timestamp in the status file:  
`cat /home/monte/monte-moos/status.txt`

### b) Checking the results
https://oceanai.mit.edu/monte/results/kerbs/tutorials/berta_tutorial/berta_job/
- The host only updates once every 5 minutes. So, if you added the job to the queue at 12:01, clients might only start running it at 12:05, and you won't see the results until 12:10. 
 -->


