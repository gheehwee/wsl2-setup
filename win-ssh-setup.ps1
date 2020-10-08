#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

<#
.SYNOPSIS
Enable remote SSH access into Windows Host.

NOTE: To relax policy for script execution, run this in PowerShell:
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser

.DESCRIPTION
Configures public key authentication to SSH into Windows Host.

- https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
- https://github.com/PowerShell/Win32-OpenSSH/wiki/Install-Win32-OpenSSH

This powershell script will retrieve an ed25519 public key associated with given github
account (user prompt), which is added to `~/.ssh/authorized_keys` to enable SSH access for
the windows username (which can be different from the wsl2 username).

Any existing sshd_config will be backed up with date.

.PARAMETER addkey
add public key through an associated github account. This will prompt for a github username.

.PARAMETER kill
Stop sshd service on windows host.

.PARAMETER help
shows this detailed help.

#>

param([switch]$help, [switch]$kill, [switch]$addkey)

if ($kill) {
    Stop-Service sshd
    exit
}

if ($help) {
    Get-Help -Name $PSCommandPath -Detailed | Out-String
    exit
}

if ($args) {
    Write-Error "Unknown arguments: $args" -ErrorAction Stop
}

# Set up sshd if not present
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
    # Check for openssh server
    Get-WindowsCapability -Online | ? Name -like 'OpenSSH*'

    # Install the OpenSSH Client
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

    # Install the OpenSSH Server
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

    # Configure the SSH server
    Start-Service sshd

    # OPTIONAL but recommended:
    Set-Service -Name sshd -StartupType 'Automatic'

    # Confirm the Firewall rule is configured. It should be created automatically by setup.
    # Get-NetFirewallRule -Name *ssh*
    New-NetFirewallRule -Name sshd -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22

    # Configure sshd_config (old config backed up with date appended to filename)
    $filename = Get-Content "$Env:programdata/ssh/sshd_config"
    $filename = $filename -replace "^#PasswordAuthentication yes", "PasswordAuthentication no"
    $filename = $filename -replace "^#PubkeyAuthentication yes", "PubkeyAuthentication yes"
    $filename = $filename -replace "^Match Group administrators", "#Match Group administrators"
    $filename = $filename -replace "^       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys", "#       AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
    $filename >> "$Env:programdata/ssh/sshd_config.changed"
    cd "$Env:programdata/ssh"
    mv sshd_config sshd_config.$(date -UFormat %Y-%m-%dT%H%M%Z)
    mv sshd_config.changed sshd_config
    cd -

    # Create ~/.ssh/authorized_keys if absent
    New-item -type directory -force -path $home/.ssh
    if (-not (Test-path $home/.ssh/authorized_keys)) {
        New-item -type file -path $home/.ssh/authorized_keys
    }
}

if ($addkey) {
    # Add public key to ~/.ssh/authorized_keys if absent
    $authorizedkeys = Get-Content "$home/.ssh/authorized_keys"
    $username = Read-Host "Please enter github username to retrieve public key for SSH authentication:"
    if ($username) {
        curl -sS https://github.com/${username}.keys | Set-Variable -Name "publickey"
        $found = $authorizedkeys -match "$publickey"
        if ($found) {
            echo "NOCHANGE ** Public key from ${username} already exists."
        }
        else {
            echo "CHANGE ** Adding new key."
            "$publickey" >> $home/.ssh/authorized_keys
        }
    }
    cat "$home/.ssh/authorized_keys"
}

# Restart sshd
Restart-Service sshd

# Get Windows Host IP Address
Get-NetIPAddress -AddressFamily ipv4 -InterfaceAlias Ethernet0 | Select-Object -expand "IPAddress" | Set-Variable -Name "winhost"
$found = $winhost -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
if (-not $found) {
    echo "ERROR ** Windows host IP address cannot be found."
    exit
}
echo "OK ** $(hostname) is ready to accept SSH remote connections with public key authentication."
echo "Try ssh into Windows from remote host: 'ssh {user}@$winhost'"