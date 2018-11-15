# Duplicate MasterNode (dupmn)

A script to easily create and manage multiple masternodes of the same coin in the same VPS, initially made for BCARD, needs to be tested with more cryptocurrencies.

# How to install

On your VPS type:
```
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn.sh
bash dupmn_install.sh
```
Then you can remove the installer script if you want: `rm -rf dupmn_install.sh`

# Commands

- `dupmn profadd <profile_file> <profile_name>` : Adds a profile with the given name that will be used to create duplicates of the masternode.
- `dupmn install <profile_name>` : Install a new instance based on the parameters of the given profile name.
- `dupmn list` : Shows the amount of duplicated instances of every masternode.
- `dupmn uninstall <profile_name> <number>` : Uninstall the specified instance of the given profile name.
- `dupmn uninstall <prof_name> all` : Uninstall all the duplicated instances of the given profile name (but not the main instance)

# Usage example

Usage example based on the CARDbuyers profile.
```
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/CARDbuyers.dmn
dupmn profadd CARDbuyers.dmn CARDbuyers
```
Now the CARDbuyers profile is saved and can be removed if you want: `rm -rf CARDbuyers.dmn`

Let's create 3 extra instances:
```
dupmn install CARDbuyers 
dupmn install CARDbuyers 
dupmn install CARDbuyers 
```
Every instance has it own private key (it will be shown after installing the new instance).

Now you can manage every instance like this:
```
CARDbuyers-cli-1 masternode status
CARDbuyers-cli-2 getblockcount
CARDbuyers-cli-3 getinfo
CARDbuyers-cli-all masternode status
```
There's also a `CARDbuyers-cli-0`, but is just a reference to the 'main instance', not a created one with dupmn.

When you're get tired of one masternode, per example the 3rd instance, then just uninstall it with:
```
dupmn uninstall CARDbuyers 3
```
Or you can even uninstall them all (except the 'main instance') with:
```
dupmn uninstall CARDbuyers all
```

# Additional

```
BTC Donations:   3HE1kwgHEWvxBa38NHuQbQQrhNZ9wxjhe7
BCARD Donations: BQmTwK685ajop8CFY6bWVeM59rXgqZCTJb
```
