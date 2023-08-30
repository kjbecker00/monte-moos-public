# Client Setup
1. git clone the **public version** of this toolbox: https://github.com/kjbecker00/monte-moos-public  
   - The public version is just a mirror without any documentation  
2. Install [moos-ivp](http://moos-ivp.org)
3. Add the ssh key (yodacora) so it can publish the results
   - If you are just preparing or running jobs on your local computer, this is not necessary.
4. Copy the password file from the host to the client's monte-moos directory
```bash
$ scp oceanai:/home/monte/monte-moos/.password ~/monte-moos/.password
``````
5. If not already installed, install python 3
6. Install the following python packages:
```bash
$ pip3 install matplotlib
$ pip3 install numpy
```
7. To start running jobs from the host's queue, run the follwoing on the client:
```bash
$ pwd
~/monte-moos
$ ./client_loop.sh -p
```
   - Note: if you don't want the client to run perpetually, remove the `-p` flag
   - Watch the first iteration to make sure there are no ssh prompts, asking if you trust this host
   <!-- - **IMPORTANT: the first time the client runs, you may be asked if you trust this host. Be there to click "yes"* -->
   <!-- - **IMPORTANT: the first time the client runs, it will not know the oceanai ssh host or some of the git hosts, so you WILL be asked if you trust this host. Be there to click "yes"* -->

## Running an ubuntu laptop in the background (credit: BingBot)
Change the power management settings so that closing the laptop lid does nothing. You can do this by `editing the /etc/systemd/logind.conf file as root` and changing the `HandleLidSwitchExternalPower setting to ignore`. Make sure that the line is not commented out (it is commented out if it is preceded by the symbol #) or add it if it is missing. Then, restart the systemd daemon with the command sudo systemctl restart systemd-logind1. 

