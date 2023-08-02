# Client Setup
1. git clone this toolbox
2. Install [moos-ivp](http://moos-ivp.org)
3. Add an ssh key (yodacora) it can publish the results
4. Copy the password file (`monte-moos/.password`) from the host
5. Run `./client_loop.sh` on the client
   - Note: if you want the client to run perpetually, use the `-p` flag
   - **IMPORTANT: the first time the client runs, it will not know the oceanai ssh host or some of the git hosts, so you WILL be asked if you trust this host. Be there to click "yes"*

## Running an ubuntu laptop in the background (credit: BingBot)
Change the power management settings so that closing the laptop lid does nothing. You can do this by `editing the /etc/systemd/logind.conf file as root` and changing the `HandleLidSwitchExternalPower setting to ignore`. Make sure that the line is not commented out (it is commented out if it is preceded by the symbol #) or add it if it is missing. Then, restart the systemd daemon with the command sudo systemctl restart systemd-logind1. 

