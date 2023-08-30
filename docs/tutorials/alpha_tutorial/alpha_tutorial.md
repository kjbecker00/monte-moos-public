# Alpha tutorial 

***CAUTION***- when preparing your jobs (ex: throughout this tutorial), DO NOT start the `client_loop.sh` script. It WILL override progress that was not pushed to the host. As a backup, the two most recent backups of this directory are stored in `.deleted_job_dirs/` and `.deleted_job_dirs2/` (but please don't rely on this...)

## 1. Writing a Job file
### a) Directory Structure
To begin, make a subdirectory for **all** of your personal jobs. Replace **kerbs** with your oceanai username.  
```bash
$ pwd
~/monte-moos
$ mkdir -p job_dirs/kerbs
```

Now, make another subdirectory for this specific job.  
```bash
$ cd ~/monte-moos/job_dirs/kerbs  
$ mkdir -p tutorials/alpha_tutorial
```

### b) Creating the Job File

Create a new file called *alpha_job* in your new directory, and make it executable.  
```bash
$ touch alpha_job  
$ chmod +x alpha_job
```

Open the file in your favorite text editor and paste the following:
```bash
#!/bin/bash 
# Kevin Becker, Aug 27 2023
# alpha_job

SHORE_REPO="moos-ivp"
SHORE_MISSION="ivp/missions/s1_alpha"
SHORE_FLAGS=" --nogui 5"  
JOB_TIMEOUT=30 # (timewarp is not accounted)
SHORE_TARG="alpha.moos"  # Targ file for the shore mission

PLOT_X="WPT_EFF_DIST_ALL"
PLOT_Y="WPT_EFF_TIME_ALL"
```
### What these variables mean:

- **SHORE_REPO**: The name of the repository that contains the mission
- **SHORE_MISSION**: The path to the mission file within the repository
- **SHORE_FLAGS**: Any flags you want to pass to the launch script
- **JOB_TIMEOUT**: The maximum time (in non-warped seconds) that the job can run before it is killed
    - Seperate from your mission, this timeout prevents never-ending missions from hogging the clients
- **SHORE_TARG**: The name of the targ file for the mission. Used to poke and query the mission
- **PLOT_X**: The variable you want to plot on the x-axis of the results plot 
    - See part 2 section C for more info
- **PLOT_Y**: The variable you want to plot on the y-axis of the results plot 
    - See part 2 section C for more info


## 2. Writing a post-processing script
### a) About post-processing scripts
This script is run on the client after the job completes. It generates a directory of information about the run, as well as a single line in a **results.csv** file. Multiple of these **results.csv** files get automatically combined into a single file for easy analysis and automated plotting.  

### b) Copy the template
Copy the template *post_process_results* file to the same directory as your job file:  
`$ cp ~/monte-moos/docs/template_files/post_process_results_alpha.sh ~/monte-moos/job_dirs/KERBS/tutorials/alpha_tutorial/post_process_results.sh`
 - This is a slightly stripped-down version of the template script I typically use. Just a bit cleaner and less daunting for new users!  
 - Note that the file should now be called `post_process_results.sh`
 
### c) Modify the script
Go to **Part 3** and edit which variables you want to save to the **results.csv** file. Included are examples using **aloggrep** to pull the final value of a given variable. Feel free to add variables as you see fit!  

Then, make the sure the file is executable:  
`$ chmod +x post_process_results.sh`

**NOte**- When modifying the script, make sure **WPT_EFF_DIST_ALL** and **WPT_EFF_TIME_ALL** are included as headers in the **results.csv** file. These are needed to plot the results. Currently, the auto-plotter only generates scatterplots. If you want to plot something else, you'll have to download the csv and plot it yourself.


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
$ rsync -zaPr job_dirs/kerbs/tutorials/alpha_tutorial/alpha_job oceanai.mit.edu:/home/monte/monte-moos/job_dirs/kerbs/tutorials/alpha_tutorial/alpha_job
```  

### c) Add to the queue
ssh onto the host, and open the file:  
```bash
$ vim /home/monte/monte-moos/host_job_queue.txt
```

Add 5 runs of your job to the job queue:  
`kerbs/tutorials/alpha_tutorial/alpha_job 5`

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
https://oceanai.mit.edu/monte/results/kerbs/tutorials/alpha_tutorial/alpha_job/
- The host only updates once every 5 minutes. So, if you added the job to the queue at 12:01, clients might only start running it at 12:05, and you won't see the results until 12:10. 



# Post-Tutorial Questions  
Notice how you can't see `machine_info.txt` online? 
- This is because ONLY files in the web subdirectory get copied to the internet. The rest stay in **yodacora/monte-moos/results/** on oceanai. This feature is helpful for preventing sensitive information from being leaked online, but still enabling real-time updates

It is possible to launch multiple MOOSDBs using this method if your launch script launches the vehicles as well as the shoreside. However, the method shown in the berta tutorial will open the door to using multiple moos-ivp-extend repositories.


