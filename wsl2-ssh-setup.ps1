#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

# Thanks to references:
# https://www.hanselman.com/blog/HowToSSHIntoWSL2OnWindows10FromAnExternalMachine.aspx
# https://gist.github.com/daehahn/497fa04c0156b1a762c70ff3f9f7edae#file-wsl2-network-ps1
# https://github.com/microsoft/WSL/issues/4150#issuecomment-504209723
# https://gist.github.com/xmeng1/aae4b223e9ccc089911ee764928f5486

<#
.SYNOPSIS
Enable remote SSH access into Windows Subsystem for Linux 2 (WSL2) VM instance.

NOTE: To relax policy for script execution, run this in PowerShell:
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

Edit script if you need to open more ports for other processes/servers running in WSL2.

.DESCRIPTION
WSL1 was accessible by LAN by default, but this is not the case for WSL2:
https://docs.microsoft.com/en-us/windows/wsl/compare-versions#accessing-a-wsl-2-distribution-from-your-local-area-network-lan

WSL2 receives a random virtualized IP address each time it starts, so we need to add a port
proxy that listens on a custom ssh port on the windows host (2222 here so it's different
from 22 for host ssh port), and connects it to port 2222 on the WSL2 VM with its virtual
IP. Firewall ports are opened for SSH (and other services if more ports are added in script)
to reach WSL2. SSH services does not run by default in WSL2, so we need to turn it on.

If called with '-add' flag, this powershell script will call a companion bash script (LF
line endings required) that requests for a github account from which an associated public key
will be added to `~/.ssh/authorized_keys` to enable remote ssh access for the given user.

.PARAMETER addkey
add public key through an associated github account. This will prompt for a github username.

.PARAMETER list
calls   netsh interface portproxy show v4tov4
convenient for checking portproxy information.

.PARAMETER kill
calls   netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=2222
deletes port proxy for WSL2 and closes firewall ports too.

.PARAMETER help
shows this detailed help.
#>

param([switch]$addkey, [switch]$list, [switch]$kill, [switch]$help)

if ($args) {
    Write-Error "Unknown arguments: $args" -ErrorAction Stop
}

if ($help) {
    Get-Help -Name $PSCommandPath -Detailed | Out-String
    exit
}

if ($list) {
    netsh interface portproxy show v4tov4
    exit
}

#-------------------------------------------------------------------------------
### Configuration settings

# wsl2 ssh port
$ssh_port = 2222

# Add more ports if you run other services from wsl2
$ports = ($ssh_port)

# listen to any adapter
$address = "0.0.0.0"

#-------------------------------------------------------------------------------

# Error if companion bash script has LF ending
if (wsl bash -c "file ./wsl2-ssh-setup | grep CRLF") {
    Write-Error "ERROR ** Convert bash script wsl2-ssh-setup to LF line ending (with vscode)." -ErrorAction Stop
}

# Get ip address of WSL2 instance
wsl hostname -I | Set-Variable -Name "ip_wsl"
$found = $ip_wsl -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
if ($found) {
    $ip_wsl = $Matches[0] # match will trim trailing spaces too.
}
else {
    Write-Error "ERROR ** Cannot find ip address for wsl2 instance." -ErrorAction Stop
}

# Get ip address of windows host
Get-NetIPAddress -AddressFamily ipv4 -InterfaceAlias Ethernet0 | Select-Object -expand "IPAddress" | Set-Variable -Name "ip_host"
$found = $ip_host -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
if ($found) {
    $ip_host = $Matches[0]
}
else {
    Write-Error "ERROR ** Cannot find ip address for windows host." -ErrorAction Stop
}

# Set up portproxy rules
foreach ($p in $ports) {
    if ($kill) {
        netsh interface portproxy delete v4tov4 listenaddress=$address listenport=$p
    }
    else {
        netsh interface portproxy set v4tov4 listenaddress=$address listenport=$p connectaddress=$ip_wsl connectport=$p
    }
}

# Display portproxy rules
netsh interface portproxy show v4tov4
# To reset all portproxy rules (may affect other processes if you have any)
# netsh interface portproxy reset all

# Set up firewall rules
$rulename = "WSL2 Firewall Unlock"

$inbound = @{
    DisplayName = $rulename
    LocalPort   = $ports
    Direction   = "Inbound"
    Protocol    = "TCP"
    Action      = "Allow"
}

$outbound = @{
    DisplayName = $rulename
    LocalPort   = $ports
    Direction   = "Outbound"
    Protocol    = "TCP"
    Action      = "Allow"
}

# NOTE: only open inbound ssh port is needed for minimum config
# Remove and re-create firewall rules if necessary
Remove-NetFirewallRule -DisplayName $rulename -ErrorAction SilentlyContinue
if (-not $kill) {
    # New-NetFirewallRule @inbound | Out-Null
    # New-NetFirewallRule @outbound | Out-Null
    New-NetFirewallRule @inbound > $null
    New-NetFirewallRule @outbound > $null
}

# Add publickey if -k flag is passed to bash script, and set up ssh service in ubuntu wsl2
# else skip. This allows us to run the same script as a scheduled task without having to
# save the user's password.

# -u root allows script to run without asking for password, but now it doesn't save
# ~/.ssh/authorized_keys in the correct user account (uses root instead)!
# So use `-u root` only to start services e.g. wsl -u root service ssh start

if (-not $kill) {
    if ($addkey) {
        # wsl -u root bash -c "./wsl2-ssh-setup -k" || Write-Error "ERROR ** Check bash script wsl2-ssh-setup" -ErrorAction Stop
        wsl bash -c "./wsl2-ssh-setup -k" || Write-Error "ERROR ** Check bash script wsl2-ssh-setup" -ErrorAction Stop
    }
    # else {
    #     # wsl -u root bash -c "./wsl2-ssh-setup" || Write-Error "ERROR ** Check bash script wsl2-ssh-setup" -ErrorAction Stop
    #     wsl bash -c "./wsl2-ssh-setup" || Write-Error "ERROR ** Check bash script wsl2-ssh-setup" -ErrorAction Stop
    # }

    # start ssh on wsl2
    wsl -u root service ssh start

    echo "OK ** Try SSH into WSL2 from remote host:     'ssh {user}@$ip_host -p $ssh_port'"
    echo "For WSL2 config, see https://docs.microsoft.com/en-us/windows/wsl/wsl-config"
}
