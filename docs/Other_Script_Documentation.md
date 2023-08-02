# Other Script Documentation  
Here is the documentation for scripts that may be used by both the client and the host.  

## clean.sh
1. Goes into moos-dirs and cleans each repo by removing log and binary files
2. Explicitly cleans moos-ivp/ivp/missions seperately using its `./clean.sh` script
3. Removes the `results/` directory, if desired
4. Removes cache files (like `.built_dirs`)
5. Removes all JOB_DIRS subdirectories, if desired (note: not recommended to run on host)

## encrypt.sh
1. Checks if the input is a directory or file. Zips if it is a directory
2. Checks if a file ends in .enc (auto-determines if it should encrypt/decrypt/zip/unzip)
3. Encrypts/Decrypts the file using the password in `.password`

## check_job.sh
Runs several checks, returns an exit code based on what failed
1. Checks he job exists
2. Checks the number of vehicles is consistent
3. Checks that the shoreside repo and mission exist, 
    - Warns the user if there are no shoreside flags
<!-- 4. Checks that the job_dir exists -->
4. Checks that the $JOB_TIMEOUT was set in the job file

