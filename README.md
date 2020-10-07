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

#### 6.2 Run `win-ssh-setup.ps1` (available flags: -help, -addkey, -kill)

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

#### 6.3 Add ssh alias to `~/.ssh/config`

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

#### 7.3 Enable execution of PowerShell scripts in PowerShell terminal

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

Similar to [Step 6.3](#63-add-ssh-alias-to-sshconfig), add another alias for wsl2 into `~/.ssh/config` on the machine (e.g. laptop) you remote from.
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
