#!/usr/bin/env pwsh
#Requires -RunAsAdministrator

### Create task in task scheduler to enable remote SSH access to WSL2 on startup

Resolve-Path .\wsl2-ssh-setup.ps1 | Set-Variable -Name "script"
$action = New-ScheduledTaskAction -Execute pwsh -Argument $script -WorkingDirectory "$PWD"
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserID "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -Runlevel Highest
Register-ScheduledTask -TaskName "wsl2_ssh" -Action $action -Trigger $trigger -Principal $principal -Force
Start-ScheduledTask -TaskName "wsl2_ssh"