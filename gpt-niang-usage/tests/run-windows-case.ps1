param([Parameter(Mandatory=$true)][string]$TestFile,[string]$PreviewDirectory)
$ErrorActionPreference='Stop'
$file=[IO.Path]::GetFullPath($TestFile)
$tokens=$null;$errors=$null
# Preserve the filename/PSScriptRoot while loading UTF-8 explicitly on both hosts.
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file,[Text.Encoding]::UTF8),$file,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$arguments=@{}
if($PreviewDirectory-and [IO.Path]::GetFileName($file)-eq 'widget.test.ps1'){$arguments.PreviewDirectory=$PreviewDirectory}
# Each case already owns a separate process. Dot-source so top-level fixture
# variables and function $script: references share the same script scope.
. $ast.GetScriptBlock() @arguments
