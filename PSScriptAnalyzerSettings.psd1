# See https://github.com/PowerShell/vscode-powershell/blob/7f626d90ca295e60f9905a23fabc38737e7b843d/examples/PSScriptAnalyzerSettings.psd1

# Stop Powershell extension from complaining about simple and well-understood aliases
# that map directly to linux command syntax (e.g. cd, mv, echo, cat)

@{
    ExcludeRules = @('PSAvoidUsingCmdletAliases')
}