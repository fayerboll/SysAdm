<#
.SYNOPSIS
    Update AD user properties. AD attributes are dynamically read from input file.
.DESCRIPTION
    This script update AD user properties based on the input file.
    The input file should be in CSV format with first column as user SAMAccountName and the rest of the column are AD attributes.
    The script will also create a template input file if the input file is not found.
.NOTES
    File Name      : UserDynamicUpdate.ps1
    Author         : fayerboll
    Change History : 21/10/2023 - Initial creation
                   : 05/08/2024 - Added WriteLog function
.EXAMPLE
    .\UserDynamicUpdate.ps1 -Ticket 12345
    This command will update AD user properties based on the input file TemplateInputData.csv
    The script will also create a template input file if the input file is not found.
#>


[CmdletBinding()]
param (
    [string]
    $File = "$PSScriptRoot\TemplateInputData.csv",
    [Parameter(Mandatory)]
    [string]
    $Ticket
)
function RecreateInputTemplate {
    $template = "$PSScriptRoot\TemplateInputData.csv"
    if (Test-Path -Path $template) {
        if ((Get-Content $template).Count -ne 8) {
            Rename-Item $template "$template.$(Get-Date -Format 'ddMMyyyyhhmmss').bak"
        }
    }
    $content = 
    @"
## This line will be ignored during import.
## To update AD user information you can add column name based on AD user properties.
## First column is identifier which in most scenario is user SAMAccountName.
## Second column and so on the column you want to update.
## refer https://learn.microsoft.com/en-us/powershell/module/activedirectory/set-aduser?view=windowsserver2022-ps for list of commonly used
## property.
SAMAccountName,Description,EmailAddress,Company
YourLogonID,This is a sample description,useremail@address.com,SomeCompanyHeWorksAt Berhad
"@
    Add-Content $template -Value $content
}

function WriteLog {
    param (
        [string]
        $Message,
        [switch]
        $Success,
        [switch]
        $Err
    )
    if ($Success) {
        Write-Host $Message
        Add-Content -Value "[$(Get-Date -Format 'ddMMyyyy_hhmmsstt')] [$Ticket] $Message" -Path $SuccessLogFile
    }
    if ($Err) {
        Write-Host $Message -ForegroundColor Red
        Add-Content -Value "[$(Get-Date -Format 'ddMMyyyy_hhmmsstt')] $Message" -Path $ErrorLogFile
    }
}

$ErrorActionPreference = 'Stop'

$SuccessLogFile = "$PSScriptRoot\SuccessLog.txt"
$ErrorLogFile = "$PSScriptRoot\$(Get-Date -Format 'ddMMyyyy_hhmmsstt')_ErrorLog.txt"
if (!(Test-Path $File)) {
    Write-Output "Please save input file $File in the same script folder"
    exit
}

$inputdata = Get-Content $File
$myheader = $inputdata | Select-String -Pattern '^#' -NotMatch
$users = $myheader | ConvertFrom-Csv

$index = 0
#grabbing headers for AD attributes
$variables = $myheader[0] -split ','

foreach ($user in $users) {     
    $PercentComplete = [System.Math]::Round((($index / $users.count) * 100), 1)
    $CurrentOperation = "Processing item $index of $($users.Count)"
    $ProgressSplat = @{
        Activity         = "Examining account $($user.$Identity)"
        Status           = "$PercentComplete % complete"
        PercentComplete  = $PercentComplete
        CurrentOperation = $CurrentOperation
    }
    Write-Progress @ProgressSplat
    $index++
               
    for ($i = 1; $i -lt $variables.Count; $i++) {
        $Identity = $variables[0]
        $ToUpdateField = $variables[$i]

        if (!([string]::IsNullOrWhiteSpace($user.$Identity))) {
            try {
                [void](Get-ADUser -Identity $user.$Identity)
                if (!([string]::IsNullOrWhiteSpace($user.$ToUpdateField))) {
                    $Command = "Set-ADUser -Identity $($user.$Identity) -$ToUpdateField `"$($user.$ToUpdateField)`" -WhatIf"
                    Invoke-Expression $Command
                    WriteLog -Message "[SUCCESS] [User] $($user.$Identity) - [Attribute $ToUpdateField] $($user.$ToUpdateField)" -Success
                }
            }
            catch {
                WriteLog -Message "Error message :  $($error[0].Exception.Message)" -Err
                WriteLog -Message "Triggered at : $($error[0].InvocationInfo.PositionMessage)" -Err
            }
        }
    }
}
RecreateInputTemplate