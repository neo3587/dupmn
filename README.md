# Duplicate MasterNode (dupmn)

A script to easily create and manage multiple masternodes of the same coin in the same VPS, initially made for BCARD, needs to be tested with more cryptocurrencies.

# How to install

On your VPS type:
```
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh
bash dupmn_install.sh
```
Then you can remove the installer script if you want: `rm -rf dupmn_install.sh`

# Commands

- `dupmn profadd <profile_file> <profile_name>` : Adds a profile with the given name that will be used to create duplicates of the masternode.
- `dupmn profdel <profile_name>` : Deletes the saved profile with the given name and uninstalls the duplicated instances that uses that profile.
- `dupmn install <profile_name>` : Install a new instance based on the parameters of the given profile name.
- `dupmn list` : Shows the amount of duplicated instances of every masternode.
- `dupmn uninstall <profile_name> <number>` : Uninstall the specified instance of the given profile name.
- `dupmn uninstall <profile_name> all` : Uninstall all the duplicated instances of the given profile name (but not the main instance).
- `dupmn rpcchange <profile_name> <number> <port>` : Changes the rpc port of the given instance number, this is only in case that by chance it causes a conflict with another application that uses the same port.
- `dupmn swapfile <size_in_mbytes>` : Creates/changes or deletes (if value is 0) a swapfile to increase the virtual memory, allowing to fit more masternodes in the same VPS, recommended size is 150 MB for each masternode (example: 3 masternodes => `dupmn swapfile 450`), note that some masternodes might be more 'RAM hungry'.

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
The new masternode instances will use the same IP and port, so the `masternode.conf` will look like this:
```
MN01   123.45.67.89:48451 MASTERNODE_PRIVATE_KEY_OF_MAIN_MN TX_OF_MAIN_MN TX_ID_OF_MAIN_MN
MN01_1 123.45.67.89:48451 MASTERNODE_PRIVATE_KEY_OF_DUPMN_1 TX_OF_DUPMN_1 TX_ID_OF_DUPMN_1
MN01_2 123.45.67.89:48451 MASTERNODE_PRIVATE_KEY_OF_DUPMN_2 TX_OF_DUPMN_2 TX_ID_OF_DUPMN_2
MN01_3 123.45.67.89:48451 MASTERNODE_PRIVATE_KEY_OF_DUPMN_3 TX_OF_DUPMN_3 TX_ID_OF_DUPMN_3
```

# Considerations

A VPS doesn't have unlimited resources, creating too many instances may cause Out-Of-Memory error since MNs are a bit "RAM hungry" (can be partially fixed with `dupmn swapfile` command), there's also a limited hard-disk space and the blockchain increases in size everyday (so be sure to have a lot of free hard disk space, can be checked with `df -h`), and VPS providers usually puts a limit on monthly network bandwith (so running too many instances may get you to that limit).

# Additional

```
BTC Donations:   3HE1kwgHEWvxBa38NHuQbQQrhNZ9wxjhe7
BCARD Donations: BQmTwK685ajop8CFY6bWVeM59rXgqZCTJb
```
