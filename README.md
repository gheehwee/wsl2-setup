# Windows + Ubuntu WSL2 setup

## Quick summary

### Step 1. Install VSCode editor

Install [Visual Studio Code](https://code.visualstudio.com/) at https://go.microsoft.com/fwlink/?LinkID=534107

### Step 2. Install modern cross-platform [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows?view=powershell-7)

PowerShell 7 LTS (2020 September): https://github.com/PowerShell/PowerShell/releases/download/v7.0.3/PowerShell-7.0.3-win-x64.msi

### Step 3. Install Windows Terminal

Install [`wt` from Microsoft Store](https://aka.ms/terminal) for automatic updates.
PowerShell7 will open as default tab if it's installed before Windows Terminal (otherwise you need to edit `settings.json`).
Conveniently, `wt` allows a different shell in each tab (powershell 5.1, powershell 7 and ubuntu wsl2 etc).

_NOTE: for Microsoft Store, it is okay to skip sign-in; wait a bit and app will install._

### Step 4. Git-core and Github desktop

Install Github Desktop from https://desktop.github.com/

Install Git from https://git-scm.com/download/win

Clone gist/repo associated with this README.md (using Github desktop or commandline git).

### Step 5. Set up Windows Subsystem for Linux 2 (WSL2)

https://docs.microsoft.com/en-us/windows/wsl/install-win10

_NOTE: For all PowerShell7/Windows Terminal instructions, we need an open terminal running as administrator (shift + rightclick for admin option)._

#### 5.1 Check Windows 10 update and update fully.

#### 5.2 Open PowerShell7/`wt` with admin rights and run the following.

You will be prompted to restart Windows below(essential step).

```powershell
# Enable WSL
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine feature for WSL2
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# Press to confirm windows restart (but read below first)
Restart-computer -ComputerName localhost -Confirm
```

Before restarting, now's a good time to change your windows hostname (also requires restart), if necessary, for simpler remote access SSH commands.
Type into taskbar search: `Settings > About > Rename this PC`, then restart.

#### 5.3 After restart, install Linux kernel update package:

https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

#### 5.4 Set WLS2 as default in PowerShell/`wt`

```powershell
wsl --set-default-version 2
```

#### 5.5 Install Ubuntu 20.04 distro from Microsoft Store

Use https://www.microsoft.com/store/apps/9n6svws3rx71 for automatic updates.
**Click `Launch` for ubuntu to configure itself and prompt you for user account creation** (takes a while).
Close the terminal window and microsoft store when done.

To launch an linux shell, type `wsl`.
To launch a linux command from PowerShell, type `wsl {command}`.
For example, in your powershell7/windows terminal tab, try `wsl uname -rs`:

```powershell
PS> wsl uname -rs
Linux 4.19.128-microsoft-standard
```

If you can see this, ubuntu is running on your windows!

#### 5.6 Restart windows terminal `wt`

So that it can pick up `Ubuntu-20.04` as a shell option, and try open a new ubuntu 20.04 shell.

#### 5.7 Extras: CUDA/gpu-support on WSL2

https://docs.nvidia.com/cuda/wsl-user-guide/index.html#installing-wsl2

### Step 6. Set up SSH for Windows Host (on port 22)

A powershell script `win-ssh-setup.ps1` (tested on PowerShell7/`wt`) has been written to configure public key SSH authentication for the windows host.

Git clone this repository (click on the green `Code` button in the github repository page to copy the HTTPS or SSH link, for example):

```powershell
# `cd` to your desired directory (make one if needed), e.g.
# cd Documents/Github
# Then `git clone`:

git clone git@github.com:gheehwee/wsl2-setup.git

#or
git clone https://github.com/gheehwee/wsl2-setup.git
```

Alternatively, use Github desktop's GUI to clone the repository.

Some prerequisites:

#### 6.1 An ed25519 Public Key for SSH authentication

The script uses only ed25519 public key associated to a github account so that a script can easily query with a public address (no need to copy and paste keys).
If you need a new ed25519 public and private key pair, run `ssh-keygen` in ubuntu wsl2 shell:

```sh
# Works in powershell7, wsl2 or a macOS/linux terminal
ssh-keygen -t ed25519
```

and follow Github's instructions to add the key to your account.
https://docs.github.com/en/free-pro-team@latest/github/authenticating-to-github/adding-a-new-ssh-key-to-your-github-account

Now you can retrieve your public key at `https://github.com/{username}.keys`.

#### 6.2 Enable execution of PowerShell scripts

To execute the setup scripts, we need to run this in PowerShell:

```powershell
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

#### 6.3 Run `win-ssh-setup.ps1` (available flags: -help, -addkey, -kill)

_Only run the first two commands_ below. The rest are for different scenarios:

```powershell
# Run in powershell7/windows terminal
.\win-ssh-setup.ps1 -help

# Commence configuration and add a public key
.\win-ssh-setup.ps1 -addkey

# Stop sshd service
.\win-ssh-setup.ps1 -kill
# or run the actual service command to stop
Stop-Service sshd

# Restart sshd service
.\win-ssh-setup.ps1
# or run this if there are no changes
Restart-Service sshd
```

#### 6.4 Add ssh alias to `~/.ssh/config`

Add an alias into your `~/.ssh/config` or `$HOME/.ssh/config` on the machine you remote from (e.g. a macbook).
That machine should contain the same ed25519 public-private key pair associated with your github account:

```sh
# Compare this with your `https://github.com/{username}.keys`
cat ~/.ssh/id_ed25519.pub
```

Replace `{username}` with your github account name.
Next, we add the following into the top of `~/.ssh/config`:

```
# windows
Host win
    HostName 192.168.50.40
    Port 22
	User {user}
	IdentityFile ~/.ssh/id_ed25519
```

Replace `{user}` with your windows username, and change the ip address to your actual value.
Now, you can ssh into the windows host with just:

```
ssh win
```

VSCode's [remote development extension](https://code.visualstudio.com/docs/remote/remote-overview) also picks up these ssh aliases, so you can use VSCode to edit code on the remote windows host (very convenient).

To access your ubuntu WSL2 remotely, first SSH into the windows host, then run `wsl` to drop into ubuntu.
When you need direct SSH access to the actual WSL2 instance running on the windows host, follow the next step.

### Step 7. Enable remote SSH access to WSL2 (on port 2222)

**Troublesome**: the WSL2 virtual machine (VM) is assigned random virtualized IP address _each time it starts._
Also, Ubuntu 20.04 on WSL2 has openssh-server configured only for public key authentication (`PasswordAuthentication no` set in `/etc/ssh/sshd_config`).

For easier setup, a tandem of powershell `wsl2-ssh-setup.ps1` and bash `wsl2-ssh-setup` scripts are written to configure everything.
A powershell script `wsl2-ssh-taskscheduler.ps1` is also included to install a scheduled task that will enable SSH access to the WSL2 instance on startup.
If you shutdown the WSL2 instance, you will need to rerun `wsl2-ssh-setup.ps1`.

Some prerequisites:

#### 7.1 A Public Key for SSH authentication (see Step 6.1)

The same public key in [Step 6.1](#61-an-ed25519-public-key-for-ssh-authentication) is used here.
A different key is possible too.

#### 7.2 Ensure the scripts have correct LF line ending!

Windows uses CRLF whereas Linux and macOS use LF ending.
If you copy/download scripts on Windows and try to run them in ubuntu wsl2, they _will throw errors_.
Use VSCode to convert CRLF to LF (see vscode status bar, bottom right for CRLF/LF toggle).

Powershell7 seems to accept powershell scripts with LF ending, so we _default to LF ending for both powershell and bash scripts._

#### 7.3 Enable execution of PowerShell scripts in PowerShell terminal (skip if previously done)

```powershell
# Run in powershell7/windows terminal
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser
```

#### 7.4 Run `wsl2-ssh-setup.ps1` powershell script (which calls `wsh2-ssh-setup` bash script in wsl2 environment)

Run this two commands:

```powershell
# Run in powershell7/windows terminal
.\wsl2-ssh-setup.ps1 -help

# Commence configuration and add public key
.\wsl2-ssh-setup.ps1 -addkey
```

A successful configuration will show a helpful SSH command example to connect to your wsl2 instance.
For example, my windows host has the IP 192.168.50.40:

```
OK ** Try ssh into WSL2 from remote host: 'ssh {user}@192.168.50.40 -p 2222'
```

Replace `{user}` with the actual user created during the earlier ubuntu wsl2 launch ([Step 5.5](#55-install-ubuntu-2004-distro-from-microsoft-store)) and try to log on.

Optional flags for other uses:

```powershell
# Show port proxy rules set up for wsl2
.\wsl2-ssh-setup.ps1 -list

# Delete port proxy rules for wsl2 (disable SSH access for wsl2)
.\wsl2-ssh-setup.ps1 -kill
```

#### 7.5 Add ssh alias in `~/.ssh/config` to just sign in with `ssh wsl`

Similar to [Step 6.4](#64-add-ssh-alias-to-sshconfig), add another alias for wsl2 into `~/.ssh/config` on the machine (e.g. laptop) you remote from.
Replace `{user}` with the wsl2 user you created during ubuntu launch in [Step 5.5](#55-install-ubuntu-2004-distro-from-microsoft-store), and replace `192.168.50.40` with the correct ip address of your windows host:

```
# ubuntu wsl2
Host wsl
    HostName 192.168.50.40
    Port 2222
	User <user>
	IdentityFile ~/.ssh/id_ed25519
```

Now, try to remotely connect to your wsl2 instance by running:

```
ssh wsl
```

#### 7.6 Install task to enable wsl2 ssh/portproxying on windows startup

_(Painful: automating/scheduling tasks in windows fails silently in myriad ways! Hope this solution lasts...)_

Run `wsl2-ssh-taskscheduler.ps1` in a powershell with admin rights:

```powershell
.\wsl2-ssh-taskscheduler.ps1
```

A scheduled task called "wsl2_ssh" will be created (check `Task Manager`).
Restart windows, wait a while and do not log into windows first.
Try to SSH into WSL2 with the previous alias `ssh wsl`, or with `ssl {user}@{host_ip} -p 2222`

If everything works, you're done!

## Miscellaneous details

### Step 2A PowerShell

By default, Windows 10 comes with windows-only PowerShell 5.1:

```powershell
# Run in powershell/windows terminal
$PSVersionTable

Name                           Value
----                           -----
PSVersion                      5.1.19041.1
PSEdition                      Desktop
PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0...}
BuildVersion                   10.0.19041.1
CLRVersion                     4.0.30319.42000
WSManStackVersion              3.0
PSRemotingProtocolVersion      2.3
SerializationVersion           1.1.0.1

$PSVersionTable.PSVersion

Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      19041  1
```

2020 September: Current cross-platform stable version is PowerShellCore 7 with long term support (LTS).

2020 September: PowerShellCore still depends on deprecated openssl 1.0 for macOS/Linux.
For Windows, it is ok to run PowerShell 7 alongside 5.1, and gives us some tooling/settings that linux users have come to expect.

- https://docs.microsoft.com/en-us/powershell/
- https://github.com/PowerShell/PowerShell
- https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-windows

Instead of clicking through GUI installer, you can run this in PowerShell/Windows Terminal with admin rights:

```powershell
msiexec.exe /package PowerShell-7.0.3-win-x64.msi /quiet ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1
```

### Step 3A Windows Terminal

This allows us to run different shells (PowerShell 5.1, PowerShell 7 and ubuntu WSL2) in different tabs.

Install Windows Terminal at microsoft store: https://www.microsoft.com/store/productId/9N0DX20HK701 (MS Store prompts you to log in, but you can opt to dismiss and the app will still download and install)

To run Windows Terminal, type wt in taskbar search and enter.
Pin Windows Terminal to your taskbar, and type SHIFT + rightclick if you need to run wt with administrator privileges.
https://superuser.com/questions/1560049/open-windows-terminal-as-admin-with-winr

More: https://docs.microsoft.com/en-us/windows/terminal/get-started

NOTE: If you installed PowerShell7 before installing Windows Terminal, wt will default to opening PowerShell 7.
Otherwise, wt will open with PowerShell 5.1.

#### 3A.1 Changing default shell in Windows Terminal

We can make PowerShell 7 (or ubuntu wsl2 when it's installed) the default opening tab.
Click the down arrow tab > Settings > `settings.json` will open in Notepad or VSCode, and look for the guid for PowerShellCore, for example:

```json
{
	...
	"defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
	...
	"profiles":
	{
		...
		"list":
		[
			...

			{
				"guid": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
				"hidden": false,
				"name": "PowerShell",
				"source": "Windows.Terminal.PowershellCore"
			}
		]
    ...
    }
}
```

Edit `defaultProfile` field to point at the PowerShellCore guid instead:

```json
"defaultProfile": "{574e775e-4f2a-5b96-ac1e-a2962a402336}",
```

Restart Windows Terminal and PowerShell 7 should start as the default tab.

More:

- Customizing wt: https://medium.com/@callback.insanity/windows-terminal-changing-the-default-shell-c4f5987c31

- PowerShell preference variables: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables

### Step 4A Git commandline and Github Desktop

https://desktop.github.com/ makes it easier to download the associated scripts for this wsl-setup writeup, when we need to run them to enable remote SSH access to the ubuntu WSL2 instance.

To download git commandline interface (cli), see:

- https://docs.github.com/en/free-pro-team@latest/github/getting-started-with-github/set-up-git#setting-up-git
- https://git-scm.com/downloads

Check git version:

```powershell
PS> git version
git version 2.28.0.windows.1
```

This repository has an `.gitattributes` file to prevent Windows from converting text files to CRLF line endings (default in windows).
The bash scripts require LF line endings to work in ubuntu WSL2.
Check with VSCode to see what line endings the scripts are.
In case the files keep getting converted to CLRF, run this to configure git to stop any conversion:

```powershell
git config --global core.autocrlf false
```

### Step 5A Windows Subsystem for Linux 2

- WSL faq https://docs.microsoft.com/en-us/windows/wsl/faq
- WSL Config https://docs.microsoft.com/en-us/windows/wsl/wsl-config
- WSL Interop https://docs.microsoft.com/en-us/windows/wsl/interop
- Ubuntu WSL wiki https://wiki.ubuntu.com/WSL
- WSL install guide https://docs.microsoft.com/en-us/windows/wsl/install-win10

The steps in this writeup were tested on a Windows 10 VM (2 cores, 4 GiB memory) running on VMware Fusion on macOS;
Enabled hypervisor applications in VM, and enable bridge networking to have a reserved LAN IP address for the windows host.

#### Step 5A.1 Check Windows Update and update fully

#### Step 5A.2 Enable WSL with some PowerShell commands

Copy and paste in PowerShell/Windows Terminal as administrator:

```powershell
# Run these as administrator

# Enable WSL
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

# Enable Virtual Machine feature for WSL2
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

#### Step 5A.3 Restart Windows

Unfortunately, we need to restart Win10 here, so it is difficult to automate everything in a single script. If you want to restart Windows via command line, run this:

```powershell
# If you want to restart win10 from PowerShell
Restart-computer -ComputerName localhost -Confirm
```

#### Step 5A.4 Download Linux kernel update package

Download and install https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

Alternative: Run this to download and install via command line:

```powershell
# works on PowerShell7 with administrator rights
cd $HOME/Downloads
curl -OL "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
msiexec.exe /package wsl_update_x64.msi /quiet
```

See https://www.advancedinstaller.com/user-guide/msiexec.html

#### Step 5A.5 Set WSL2 as default version

```powershell
wsl --set-default-version 2
```

#### Step 5A.6 Install ubuntu 20.04 distribution from Microsoft Store

Get and Launch ubuntu 20.04 from Microsoft Store: https://www.microsoft.com/store/apps/9n6svws3rx71 (skip login).
Remember to click Launch for ubuntu to install properly; the distro setup will prompt you to set up a user account and password.
You can close console after account creation.

Manual install alternative (no auto-update via Microsoft Store) at https://docs.microsoft.com/en-us/windows/wsl/install-manual

#### Step 5A.7 Test Windows-WSL2 interop

We check windows-ubuntu interop using the wsl command. Run this on a PowerShell7 tab in windows terminal:

```powershell
# Running this in PowerShell

PS> wsl uname -rs
Linux 4.19.128-microsoft-standard

PS> wsl hostname -I
172.31.237.240

PS> netsh interface ip show address "Ethernet0"
Configuration for interface "Ethernet0"
    DHCP enabled:                         Yes
    IP Address:                           192.168.50.40
    Subnet Prefix:                        192.168.50.0/24 (mask 255.255.255.0)
    Default Gateway:                      192.168.50.1
    Gateway Metric:                       0
    InterfaceMetric:                      25
```

**NOTICE** that the ip address for the windows host (192.168.50.40) does not match the ip address of the ubuntu wsl2 instance (172.31.237.240).
We tackle this in the WSL2 SSH configuration section [Step 7](#step-7-enable-remote-ssh-access-to-wsl2-on-port-2222).

Restart windows terminal wt if it has not picked up ubuntu wsl as a possible launch option (click on the down arrow tab).
You should see an 'Ubuntu-20.04' shell option to enter ubuntu directly.

```sh
# Running this in ubuntu wsl2 shell
$ uname -rs
Linux 4.19.128-microsoft-standard
```

Change your windows hostname (if necessary) for easier SSH access.
Type into taskbar search: About > Rename this PC, then restart.

#### Step 5A.8 Managing WSL and distros

- https://docs.microsoft.com/en-us/windows/wsl/wsl-config
- https://docs.microsoft.com/en-us/windows/wsl/wsl-config#managing-multiple-linux-distributions

Type wsl --help for options.

To list distros, run wsl -l -v in powershell:

```powershell
PS> wsl --list --verbose
  NAME            STATE           VERSION
* Ubuntu-20.04    Running         2
```

To see ubuntu 20.04 distro-specific commands for configuration, run `ubuntu2004.exe /?`:

```powershell
PS> ubuntu2004.exe /?
Launches or configures a Linux distribution.

Usage:
    <no args>
        Launches the user's default shell in the user's home directory.

    install [--root]
        Install the distribution and do not launch the shell when complete.
          --root
              Do not create a user account and leave the default user set to root.

    run <command line>
        Run the provided command line in the current working directory. If no
        command line is provided, the default shell is launched.

    config [setting [value]]
        Configure settings for this distribution.
        Settings:
          --default-user <username>
              Sets the default user to <username>. This must be an existing user.

    help
        Print usage information.
```

To delete(unregister) a linux distro:

```powershell
# Find name of distribution to delete
wsl -l

wsl --unregister <distribution>
```

To reinstall a clean copy, unregister first, then find the distribution on microsft store, 'Get' and 'Launch' again.

To run wsl2 as specific user, `wsl -u <username>` or `wsl --user <username>`.

To check cpu/mem settings in WSL2 instance, from ubuntu WSL shell, run:

```sh
$ nproc --all
2

$ free -h
              total        used        free      shared  buff/cache   available
Mem:          3.1Gi        43Mi       3.0Gi       0.0Ki        24Mi       3.0Gi
Swap:         1.0Gi          0B       1.0Gi
```

- https://www.cyberciti.biz/faq/check-how-many-cpus-are-there-in-linux-system/
- https://linuxhint.com/check-ram-ubuntu/

You are all set here with a working ubuntu environment in Windows 10 👍.
However, to do useful stuff, we often need to be able to access the ubuntu wsl2 instance remotely via SSH.

Check IP addresses for windows host vs ubuntu WSL2 VM -- notice they are very different (different subnets):

```powershell
# Run this in PowerShell

# For Windows Host
netsh interface ip show addresses "Ethernet0"

# For WSL2 VM
netsh interface ip show addresses "vEthernet (WSL)"
```

The WSL2 virtual machine (VM) will have a new random virtualized IP address when it restarts...
Thus, to enable remote SSH access to the ubuntu WSL2 vm, we currently need to open some firewall ports and portproxy SSH requests from the windows host to the ubuntu WSL2 vm at its current virtualized IP address.

### Step 6A Set up SSH for Windows Host

- https://www.hanselman.com/blog/HowToSSHIntoAWindows10MachineFromLinuxORWindowsORAnywhere.aspx
- https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
- https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_server_configuration

To edit windows' sshd configuration with vscode:

```powershell
code %programdata%\ssh\sshd_config
```

Regarding authorized_keys, see https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_server_configuration#authorizedkeysfile

For some reason, windows add two lines at the end of `C:\ProgramData\ssh\sshd_config` for users belonging to the administrator group:

```powershell
Match Group administrators
       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys
```

The nonstandard setting may make it easier to add/remove admin keys from a centralized location.
However, security benefits are uncertain (?) and admin users have to share/impersonate one another with a single nonstandard authorized_keys file.
Meanwhile normal users follow the standard ~/.ssh/authorized_keys location.
The complexity for the extra treatment seems dubious (?), so I commented out the last two lines to make sshd behave like standard unix configurations and read from the user's `~/.ssh/authorized_keys`.

See https://superuser.com/questions/1445976/windows-ssh-server-refuses-key-based-authentication-from-client
