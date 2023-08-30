# Job Troubleshooting  
How to troubleshoot a job you wrote  

## Errors with updating a repo
If a repo is unable to update, check the following:
1. See what happens when you run `git clone <repo_link>` 
    - Make sure you can clone the repo from any computer without any special permissions (i.e. no ssh keys). Or, better yet, try cloning the repo from a PABLO.

## Errors with building a repo
2. If the failing repo (moos-ivp-child) references another repo (ex: moos-ivp-parent), ensure that the parent repo is included in $EXTRA_BIN_REPOS
    - If the problem persists, ensure the parent is built first
        - Rearrange `repo_links.txt`, which parsed top-to-bottom
        - Or, reorder the `repo_links.txt` files so the parent is in a higher directory than the failing repo's `repo_links.txt`

## Runtime errors  

### Missing Apps  
Check the **NEW** PATH and IVP_BEHAVIOR_DIRS (as printed) for missing binaries/scripts.    
    - `./run_job.sh` removes miscelaneous `moos-ivp-extend` repos from your $PATH and $IVP_BEHAVIOR_DIRS. This is to better simulate a client which will not have the same repos installed as you.   
    - If there are missing repos, add them to your EXTRA_BIN_REPOS and EXTRA_LIB_REPOS as desired. Or use EXTRA_REPOS for both, as a shorthand.
1. Missing pHelmIvP    
    - Make sure you have all the libraries for the behaviors that are running  
    - Make sure there are no conflicting behavior names in all repos being used  
2. Other missing apps (tip: use uProcessWatch)  
    - Make sure all apps are able to build  
    - Make sure all apps are in the **NEW** PATH  

### Missing MOOSDBs
Ensure that the vehicle and shoreside launch scripts do NOT require confirmaiton. If they do, simply add a flag that bypasses the confirmation in the job file.


This will be expanded as more questions are asked.
    