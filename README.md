# Duplicate MasterNode (dupmn)

A script to easily create and manage multiple masternodes of the same coin in the same VPS, initially made for BCARD, can be adapted for almost any other coin.

Note: For any technical question not resolved in this readme, check <a href="https://github.com/neo3587/dupmn/wiki/FAQs">the FAQ</a> (still work in progress).

# Index

- [How to install](#how-to-install)
- [Commands](#commands)
- [Usage example](#usage-example)
- [Profile creation](#profile-creation)
- [Considerations](#considerations)
- [Additional](#additional)

# <a name ="how-to-install"></a> How to install

On your VPS type:
```
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh
bash dupmn_install.sh
```
Then you can remove the installer script if you want: `rm -rf dupmn_install.sh`.

# <a name ="commands"></a> Commands

- [`dupmn profadd <profile_file> <new_profile_name>`](https://github.com/neo3587/dupmn/wiki/Commands#dupmn-profadd-profile_file-profile_name) : Adds a profile with the given name that will be used to create duplicates of the masternode.
- [`dupmn profdel <profile_name>`](https://github.com/neo3587/dupmn/wiki/Commands#dupmn-profdel-prof_name) : Deletes the saved profile with the given name and uninstalls the duplicated instances that uses that profile.
- [`dupmn install <profile_name> [optional_params]`](https://github.com/neo3587/dupmn/wiki/Commands#dupmn-install-prof_name-params) : Install a new instance based on the parameters of the given profile name.
`[optional_params]` list:  
`-ip=IP` : Use a specific IPv4 or IPv6 (BETA STATE).  
`-rpcport=PORT` : Use a specific port for RPC commands (must be valid and not in use).  
`-privkey=PRIVATEKEY` : Set a user-defined masternode private key.  
`-bootstrap` : Apply a bootstrap during the installation.  
- [`dupmn reinstall <profile_name> <number> [optional_params]`](https://github.com/neo3587/dupmn/wiki/Commands#dupmn-reinstall-prof_name--params) : Reinstalls the specified instance, this is just in case if the instance is giving problems.
`[optional_params]` list:  
`-ip=IP` : Use a specific IPv4 or IPv6 (BETA STATE).  
`-rpcport=PORT` : Use a specific port for RPC commands (must be valid and not in use).  
`-privkey=PRIVATEKEY` : Set a user-defined masternode private key.  
`-bootstrap` : Apply a bootstrap during the reinstallation.  
- [`dupmn uninstall <profile_name> <number>`](https://github.com/neo3587/dupmn/wiki/Commands#dupmn-uninstall-prof_name-) : Uninstall the specified instance of the given profile name, you can put `all` instead of a number to uninstall all the duplicated instances.
- `dupmn bootstrap <profile_name> <number> [number]` : Copies the main node stored chain to a dupe, optionally you can put a dupe number to copy from one dupe to another (if copying from main node, it must be stopped or the profile must have the COIN_SERVICE parameter).
- `dupmn iplist` : Shows your current IPv4 and IPv6 addresses.
- `dupmn rpcchange <profile_name> <number> [port]` : Changes the rpc port of the given instance number, this is only in case that by chance it causes a conflict with another application that uses the same port (if no port is provided, it will automatically find any free port).
- `dupmn systemctlall <profile_name> <command>` : Applies the systemctl command to all services created with the given profile (will only affect the main node too if the profile haves the COIN_SERVICE parameter).
- `dupmn list` : Shows the amount of duplicated instances of every masternode, if a profile name is provided, it lists an extended info of the profile instances.
- `dupmn swapfile <size_in_mbytes>` : Creates/changes or deletes (if value is 0) a swapfile to increase the virtual memory, allowing to fit more masternodes in the same VPS, recommended size is 150 MB for each masternode (example: 3 masternodes => `dupmn swapfile 450`), note that some masternodes might be more 'RAM hungry'.
- `dupmn help` : Just shows the available commands in the console.
- `dupmn update` : Checks the last version of the script and updates it if necessary.

Note: `<parameter>` means required, `[parameter]` means optional.

# <a name ="usage-example"></a> Usage example

Usage example based on the CARDbuyers profile:

First install the dupmn script:
``` 
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/dupmn_install.sh
bash dupmn_install.sh
``` 
Then add the coin profile (you don't need to run the commands above anymore in the current VPS):
```
wget -q https://raw.githubusercontent.com/neo3587/dupmn/master/profiles/CARDbuyers.dmn
dupmn profadd CARDbuyers.dmn CARDbuyers
```
Now the CARDbuyers profile is saved and the downloaded file can be removed if you want: `rm -rf CARDbuyers.dmn` (you won't need to run the `profadd` command anymore for this coin).

Let's create 3 extra instances (Note that you MUST already have installed the CARDbuyers node in the VPS, the script cannot obtain the binaries from nowhere):
```
dupmn install CARDbuyers 
dupmn install CARDbuyers 
dupmn install CARDbuyers 
```
Every instance has it own private key, it will be shown after installing the new instance, also can be seen with `dupmn list CARDbuyers`.

Now you can manage every instance like this:
```
CARDbuyers-cli-1 masternode status
CARDbuyers-cli-2 getblockcount
CARDbuyers-cli-3 getinfo
CARDbuyers-cli-all masternode status
```
There's also a `CARDbuyers-cli-0`, but is just a reference to the 'main node', not a created one with dupmn.

When you get tired of one masternode, per example the 3rd instance, then just uninstall it with:
```
dupmn uninstall CARDbuyers 3
```
Or you can even uninstall them all (except the 'main node') with:
```
dupmn uninstall CARDbuyers all
```
The new masternode instances will use the same IP and port, so the `masternode.conf` will look like this:
```
MN01 123.45.67.89:48451 713RMbHoMgTKewAmsUwqqJAFH9BwhgKixe96tYbZdtLmysFS6vz a4d79e50933ce430a3b2874738a156f3ecb866e598d7c9ecf3382902e2d29afd 0
MN02 123.45.67.89:48451 72aQd3U3qRFsc2KviX5iWF3BrK3CxHLi23BrToikFPCCpRr5kt9 26072b1000545db553c425c776cea9d29ef341512dd88b7522419db7dd952ebc 0
MN03 123.45.67.89:48451 71SuLvXHebyT4NtX96ygSJVMhwns9GaBuc2yfdJQjjCokDx5Cem 349acfcf2ea88ab0f9f165ebfd4b98273e260b813b757242e1f371d7075d3f94 1
MN04 123.45.67.89:48451 719FiV3S7m874FH1A5hmRYGFUwEzd8esES8k6TJoevgJBHnmQV9 6dbff523ae79c29c48bcd77231f15c0b8354daa2ea32cb46ed0dd0fe31ec7e82 0
```
Using `dupmn install CARDbuyers` will show you the masternode private key for that instance, the transaction must be obviosuly different for each masternode, you can't use the same transaction to run 2 masternodes, even if they're in the same VPS.

Note: `dupmn install CARDbuyers` will show you also a different rpc port, this is NOT the port that you have to add in the `masternode.conf` file, every masternode will use the same port (48451 in case of CARDbuyers).

Note 2: You can see some image examples at <a href="https://github.com/neo3587/dupmn/wiki/Image-Examples">Image Examples</a>

# <a name ="profile-creation"></a> Profile creation

Using the CARDbuyers.dmn profile as example, you can create your own profile to fit with any other coin:
```
COIN_NAME="CARDbuyers"             # Name of the coin
COIN_PATH="/usr/local/bin/"        # NOT required parameter, location of the daemon and cli (only required if they're not in /usr/local/bin/ or /usr/bin/)
COIN_DAEMON="CARDbuyersd"          # Name of the daemon
COIN_CLI="CARDbuyers-cli"          # Name of the cli
COIN_FOLDER="/root/.CARDbuyers"    # Folder where the conf file and blockchain is stored
COIN_CONFIG="CARDbuyers.conf"      # Name of the conf file
RPC_PORT=48451                     # NOT required parameter, on some coins it will start from 1024 if they don't have a rpcport parameter in the .conf file or if their port number is higher than 49151.
COIN_SERVICE="CARDbuyers.service"  # NOT required parameter, if you have a service for the main node, add this parameter for the systemctlall and bootstrap commands
```
As with the <b>Usage example</b>, you just need to type these commands to create a new duplicated masternode:
```
dupmn profadd othercoin.dmn othercoin
dupmn install othercoin
```

Note: The .dmn extension is completely optional, it is done in this way to differentiate the profile file from others.

# <a name ="considerations"></a> Considerations

A VPS doesn't have unlimited resources, creating too many instances may cause Out-Of-Memory error since MNs are a bit "RAM hungry" (can be partially fixed with `dupmn swapfile` command), there's also a limited hard-disk space and the blockchain increases in size everyday (so be sure to have a lot of free hard disk space, can be checked with `df -h`), and VPS providers usually puts a limit on monthly network bandwith (so running too many instances may get you to that limit).

# <a name ="additional"></a> Additional

```
BTC Donations:   3F6J19DmD5jowwwQbE9zxXoguGPVR716a7
BCARD Donations: BQmTwK685ajop8CFY6bWVeM59rXgqZCTJb
SNO Donations:   SZ4pQpuqq11EG7dw6qjgqSs5tGq3iTw2uZ
CFL Donations:   c4fuTdr7Z7wZy8WQULmuAdfPDReWfDcoE5
MCPC Donations:  MCwe8WxWNmcZL1CpdpG3yuudGYVphmTSLE
```
