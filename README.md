#   monte-moos      

<img src="docs/monte-moos-image.png" width="800"/>   

This is a toolbox that can be used to run monte-carlo simulations, including head-to-head competitions using [moos-ivp](http://moos-ivp.org).

## Why should I use these tools?
- Run multiple repos in one moos simulation on one computer
    - Useful when different implementations of the same app/behavior without renaming them (ex: in the 2.680 course)
- Configurable launch and post-processing scripts
- Automated publishing to oceanai, visible from the world wide web
- Utilizes several client computers for running lots of jobs at once
- May also be used locally. No host server is needed to run batches of moos simulations.

# How to use this toolbox

## Getting started:
Take a look at the [terminology](docs/Terminology.md).  
Skim through the [pipeline overview](docs/script_documentation/pipeline.pdf) to get a high-level overview of how this toolbox works.  
Complete the [tutorials](docs/tutorials/readme.md).  

### Setup:
To learn how to set up a new client, take a look at the [client setup overview](docs/Client_Setup.md).    

### Running the job queue:
1. Run `./host_loop.sh` on the host  
2. Run `./client_loop.sh` on each client (if not already running)   
    - If you want either loop to run perpetually, use the `-p` flag
    - To check a particular client, go to the host and look through `/home/yodacora/monte-moos/clients/status/`

To stop monte-moos on the host or a client, make an empty file `force_quit` in the monte-moos directory.
    

## Downloading the results
Use wget to download the reusults from the host to your local machine:
`wget -r -nH -np --progress=bar --cut-dirs=2 -R "index*" -X /results https://oceanai.mit.edu/monte/results/results_subdir/`
- Be sure to replace --cut-dirs=2 with however many directories deep you are downloading  
    - ie: 1 if you're doing all results/\* 2 if you're doing results/results_subdir/\*, etc  

## Code Documentation: 
To learn more about the *host scripts*, see the [host script documentation](docs/script_documentation/Host_Script_Documentation.md).  
To learn more about the *client scripts*, see the [client script documentation](docs/script_documentation/Client_Script_Documentation.md).  
To learn more about the *other scripts*, see the [script documentation](docs/script_documentation/Other_Script_Documentation.md).  


# Other Notes:

### Running a queue without a host:
To run a client without a host use the `-nh` flag on the `client_loop.sh` script. Note that you will be unable to run any other moos-ivp processes on the client while the client_loop is running.

### Permissions:
To use this toolbox, you must have an account on the host with the following permissions on oceanai:
1. **Read** access to `/home/yodacora/monte-moos/*` (for viewing the results)
2. **Read/Write** access to `/home/web/monte` directory (for publishing results)
3. **Read/Write/Execute** access to the `/home/something/monte-moos` directory (to run the host-side scripts)


## TODO:
- [ ] Enable the client to run jobs even if it looses internet temporarialy. (Not tested)
- [ ] Add a way for each client to set a **max** TIME_WARP locally
- [ ] Push the bad_jobs.txt files to the host (with error messages)
- [ ] Instead of sleep(time), make it a chron or something else
- [ ] Add a timestamp to the bad_jobs.txt files (remove if the job was updated recenlty (may not be possible with current setup))
