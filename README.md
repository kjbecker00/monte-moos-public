#   monte-moos      

<img src="docs/monte-moos-image.png" width="800"/>   

This is a toolbox that can be used to run monte-carlo simulations, including head-to-head competitions using [moos-ivp](http://moos-ivp.org).

## Why should I use these tools?
- Can run multiple repos in one moos simulation
    - Useful when different implementations of the same app/behavior without renaming them (ex: in the 2.680 course)
- Configurable launch and post-processing scripts
- Automated publishing to oceanai, visible from the world wide web
- Utilizes several client computers for running lots of jobs at once
- May also be used locally. No host server is needed to run batches of moos simulations

# How to use this toolbox

## Getting started:
Take a look at the [terminology](docs/Terminology.md).  
Skim through the [pipeline overview](docs/pipeline.pdf) to get a high-level overview of how this toolbox works.  

### Permissions:
To use this toolbox, you must have an account on the host with the following permissions on oceanai:
1. **Read** access to `/home/yodacora/monte-moos/*` (for viewing the results)
2. **Read/Write** access to `/home/web/monte` directory (for publishing results)
3. **Read/Write/Execute** access to the `/home/something/monte-moos` directory (to run the host-side scripts)

### Setup:
To learn how to write and prepare a job to be run, take a look at the [job setup overview](docs/Job_Setup.md).  
To learn how to set up a new client, take a look at the [client setup overview](docs/Client_Setup.md).    

### Running the job queue:
1. Run `./host_loop.sh` on the host
2. Run `./client_loop.sh` on each client (if not already running)
   - Note: if you want either loop to run perpetually, use the `-p` flag
If you want to stop either loop but you don't know the process id, make a file `force_quit` in the monte-moos directory. The host and client loops check for this file every iteration and quit if the file exists.
    - To run a client without a host use the `-nh` flag on the client loop

## Downloading the results
Use wget to download the reusults from the host to your local machine:
`wget -r -nH -np --progress=bar --cut-dirs=2 -R "index*" -X /results https://oceanai.mit.edu/monte/results/results_subdir/`
- Be sure to replace --cut-dirs=2 with however many directories deep you are downloading  
    - ie: 1 if you're doing all results/\* 2 if you're doing results/results_subdir/\*, etc  

# Code Documentation: 
To learn more about the *host scripts*, see the [host script documentation](docs/Host_Script_Documentation.md).  
To learn more about the *client scripts*, see the [client script documentation](docs/Client_Script_Documentation.md).  
To learn more about the *other scripts*, see the [script documentation](docs/Other_Script_Documentation.md).  

# TODO:
- [x] Add way to run entirely locally (ie: no host)
- [ ] Improve which cols in the csv get printed (prevent python from re-ordering it all)
- [ ] Enable the client to run jobs even if it looses internet temporarialy. Not fully implemented yet
- [ ] Add a way for each client to set a **max** TIME_WARP locally
- [ ] Add way to monitor clients from host (ie: scp .status to yco/monte-moos/clients/client_statuses/${hostname}.status)
<!-- - [ ] Update  -->
<!-- - [x] Add ability to move some repo_links.txt to job_dirs/${job_name}/repo_links.txt -->
<!-- ## Scripts: -->
<!-- - Update **alog2image.py** to filter alogs for a given hash, generate one for each hash -->
<!-- - Host: track what jobs are running, what worked, and what failed -->

