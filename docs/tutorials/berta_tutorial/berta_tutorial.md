# Berta tutorial - UNTESTED FILES!!!!
**Learn how to run a multiple MOOSDB mission on monte-moos**

***CAUTION***- when preparing your jobs (ex: throughout this tutorial), DO NOT start the `client_loop.sh` script. It WILL override progress that was not pushed to the host. As a backup, the two most recent backups of this directory are stored in `.deleted_job_dirs/` and `.deleted_job_dirs2/` (but please don't rely on this...)
**Requirements**: this tutorial assumes you have completed the [alpha tutorial](../alpha_tutorial/alpha_tutorial.md) and have moos-ivp-pavlab installed in the home directory of your computer.

## 1. Writing a Job file
### a) Directory Structure
To begin, go into the subdirectory for all of your personal jobs.  
```bash
$ pwd
~/monte-moos
$ cd job_dirs/kerbs
```

Now, make another subdirectory for this specific job.   
```bash
$ mkdir -p tutorials/berta_tutorial
```

### b) Creating the Job File

Create a new file called *berta_job* in your new directory.  
```bash
$ touch berta_job  
$ chmod +x berta_job
```

Open the file in your favorite text editor and paste the following:
```bash
#!/bin/bash 
# Kevin Becker, Aug 27 2023
# berta_job

######################################
# Launching shoreside                #
######################################
SHORE_REPO="moos-ivp-pavlab"
SHORE_MISSION="missions/alpha_heron"
SHORE_FLAGS=" 10 --noconfirm"  
JOB_TIMEOUT=40 # (timewarp is not accounted)
# SHORE_TARG is not required- will default to targ_shoreside.moos

######################################
# Launching vehicles                 #
######################################
VEHICLES=2
VEHICLE_REPOS=("moos-ivp-pavlab" "moos-ivp-pavlab")
VEHICLE_MISSIONS=("missions/alpha_heron" "missions/alpha_heron")
SHARED_VEHICLE_FLAGS=" 10 --sim --noconfirm"
VEHICLE_FLAGS=( " -w --vname=abe --index=1 --start=0,-10,170" 
                " -e --vname=ben --index=2 --start=0,-20,180"  
            )

# PLOT_X="SOME_MOOS_VAR"
# PLOT_Y="OTHER_MOOS_VAR"
```
You'll notice some differences from the alpha job:
- **VEHICLES**: The number of vehicles to be run
- **VEHICLE_REPOS**: The name of the repository that contains the mission for each vehicle
- **VEHICLE_MISSIONS**: The path to the mission file within the repository for each vehicle
- **VEHICLE_FLAGS**: Any flags you want to pass to the launch script for all vehicles
- **SHARED_VEHICLE_FLAGS**: Any flags you want to pass to the launch script for the given vehicle
- **SHORE_TARG**: Is now unnecessary for most multi-MOOSDB missions, since it defaults to **targ_shoreside.moos**
- **PLOT_X**: TODO: find good variables from this mission
    - See part 2 section C for more info
- **PLOT_Y**: TODO: find good variables from this mission
    - See part 2 section C for more info
Also be sure to note the inclusion of the **--noconfirm** flag. This is because monte-moos cannot handle launch scripts that require additional user input after they are launched.

## 2. Writing a post-processing script

### a) Copy the template
Copy the template *post_process_results* file to the same directory as your job file.    
`$ cp ~/monte-moos/docs/template_files/post_process_results.sh ~/monte-moos/job_dirs/KERBS/tutorials/berta_tutorial/post_process_results.sh`
 - This script is a bit daunting, but it's got a lot of useful features!

### c) Modify the script
Go to **Part 3** and edit which variables you want to save to the **results.csv** file. Included are examples using **aloggrep** to pull the final value of two variables, **SOME_VARIABLE** and **OTHER_VARIABLE**. 

For this tutorial, we will replace **SOME_VARIABLE** with **DB_UPTIME** and **OTHER_VARIABLE** with **PROC_WATCH_ALL_OK**. Then, we will also pull the last instance of add a 3rd variable, **PROC_WATCH_TIME_WARP** using aloggrep, and add it to the **results.csv** file. It should look something like this:
```bash
MOOS_KEY="DB_UPTIME"
MOOS_KEY2="PROC_WATCH_ALL_OK"
MOOS_KEY3="PROC_WATCH_TIME_WARP"

MOOS_VALUE=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY} --final -q --v)
MOOS_VALUE2=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY2} --final -q --v)
MOOS_VALUE3=$(aloggrep ${SHORE_ALOG} ${MOOS_KEY3} --final -q --v)

if [[ -z "$MOOS_VALUE" || -z "$MOOS_VALUE2" || -z "$MOOS_VALUE3" ]]; then
   echo "Error, unable to find all variables. Exiting..."
   exit 2
fi

KEYS="${MOOS_KEY},${MOOS_KEY2},${MOOS_KEY3}"
VALUES="$MOOS_VALUE,$MOOS_VALUE2,$MOOS_VALUE3"
```

Feel free to add more variables to the csv!  

**Part 4** does a few things. First, it copies all alog files to the web directory, it generates a plot showing where each vehicle went, and a few metafiles about the client who ran the job. If you have lots of runs, I'd recommend adding an if statement to only copy the alog files/generate tracks for interesting runs (ex: runs that had collisions, if PROC_WATCH_ALL_OK=false, etc). 


## 3. Checking your Job
From your monte-moos directory
```bash
$ pwd
~/monte-moos
```
1. Check your job for simple errors:    
```bash
$ ./check_job.sh job_dirs/kerbs/tutorials/alpha_tutorial/alpha_job
```   
This will guide you through the remaining steps! But here they are anyways:
2. Run your job on your local computer:  
```bash
$ ./client_scripts/run_job.sh job_dirs/kerbs/tutorials/alpha_tutorial/alpha_job
```
Make sure that it runs as expected. See the [job troubleshoting guide](../../job_troubleshooting.md).
3. Test your post_process_results.sh script:
```bash
$ ./client_scripts/extract_results.sh job_dirs/kerbs/tutorials/alpha_tutorial/alpha_job
```  
The *post_process_results.sh* script is written by you, but remember it may be run on any computer, so keep the dependencies minimal!  

4. Review the **results** directory to make sure the data you want is there. The directory will be printed by the extract_results.sh script

## 4. Queueing your Job

### a) Check your job- *again*
Be sure that the mission runs on linux computers. **Any errors in a queue'd job will blacklist the job** on each client for the day or until the client reboots.  

### b) Copying to the host
```bash
$ pwd
~/monte-moos
$ rsync -zaPr job_dirs/kerbs/tutorials/berta_tutorial/berta_job oceanai.mit.edu:/home/monte/monte-moos/job_dirs/kerbs/tutorials/berta_tutorial/berta_job
```  

### c) Add to the queue
ssh onto the host, and open the file:  
```bash
$ vim /home/monte/monte-moos/host_job_queue.txt
```

Add 5 runs of your job to the job queue:  
`kerbs/tutorials/berta_tutorial/berta_job 5`

## 5) Waiting for your job

### a) Check the status of the clients
When you're waiting, you can check the status of the clients in:  
`/home/monte/monte-moos/clients/status/*`

Here's a script to add to your oceanai **.bashrc** to make this easier:
```bash
catstat () {
  for file in /home/yodacora/monte-moos/clients/status/*
    do
      if [[ -f "$file" ]]
        then
          if [[ "$file" == *.txt ]]
            then
              echo -n "$(tput bold)$(tput setaf 2)$(basename $file)$(tput sgr0)"
              echo "  $(head -n 1 $file)"
          fi
        fi
    done
}
```

You can also view the last time the host updated the clients by checking the timestamp in the status file:  
`$ cat /home/monte/monte-moos/status.txt`

### b) Checking the results
https://oceanai.mit.edu/monte/results/kerbs/tutorials/berta_tutorial/berta_job/
- The host only updates once every 5 minutes. So, if you added the job to the queue at 12:01, clients might only start running it at 12:05, and you won't see the results until 12:10. 


# Post-Tutorial Questions  
Notice a difference when you ran the job compared to the alpha tutorial?  
- monte-moos updated and built moos-ivp-pavlab for you! monte-moos can also download repositories from github, and build them for you. Go on to the next tutorial to see how this works


