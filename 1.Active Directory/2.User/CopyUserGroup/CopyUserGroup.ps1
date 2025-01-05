<#
.SYNOPSIS
To add target user into the same groups as source user.

.DESCRIPTION
To add target user into the same groups as source user. This is particularly useful if target user is a team member of source user to ensure consistency.
It won't remove existing group that target user already a member of.
Log is generated and stored in the same script folder.

.PARAMETER SourceUser
Source username you want to get the group list from.

.PARAMETER ToUser
Target username you want to add group into.

.PARAMETER Ticket
SR ticket for this request. This is mandatory for audit purposes.

.EXAMPLE
PS> .\CopyUserGroup.ps1 -SourceUser MrLobaLoba -ToUser MrBombastic -Ticket SR12345
It will copy 'MrLobaLoba' group(s) to 'MrBombastic'.

.NOTES
File Name      : CopyUserGroup.ps1
Author         : fayerboll
Change History : 19/09/2023 - Initial version
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$SourceUser,
    [Parameter(Mandatory = $true)]
    [string]$ToUser,
    [Parameter(Mandatory = $true)]
    [string]$Ticket
)
function Write-MyLog {
    param (
        [string]$LogMessage
    )
    $date = Get-Date -Format "dd/MM/yyyy hh:mm:ss tt"
    Add-Content -Path "$PSScriptRoot\CopyUserGroup_Result.log" -Value "$date $LogMessage"
    Write-Output -InputObject $LogMessage
}

function Test-ADUser {
    param (
        [string]$Username
    )
    try {
        Get-ADUser -Filter { SamAccountName -eq $Username }
        return $true
    }
    catch {
        return $false
    }
}

if (!(Test-ADUser -Username $SourceUser) -or !(Test-ADUser -Username $ToUser)) {
    Write-Warning "Invalid source user or target user. Exiting script."
    exit
}

$SourceGroups = (Get-ADUser $SourceUser -Properties memberof).memberof
$TargetGroups = (Get-ADUser $ToUser -Properties memberof).memberof

if ([string]::IsNullOrEmpty($SourceGroups)) {
    Write-MyLog -LogMessage "[SKIP] [$Ticket] Source user $SourceUser not belongs to any group. No further action."
    exit
}

foreach ($TargetGroup in $TargetGroups) {
    if ($SourceGroups -contains $TargetGroup) {
        Write-Host "$ToUser is already a member of $(($TargetGroup -split ',')[0] -replace '^CN='). Skip."
        $UpdatedSourceGroups = $SourceGroups.Remove($TargetGroup)
    }
}

if ([string]::IsNullOrEmpty($UpdatedSourceGroups)) {
    Write-MyLog -LogMessage "[SKIP] [$Ticket] $ToUser is already a member in all groups that $SourceUser in. No further action."
}
else {
    foreach ($group in $UpdatedSourceGroups) {
        $group = ($group -split ",")[0] -replace "^CN="
        try {
            Add-ADGroupMember -Identity $group -Members $ToUser
            Write-MyLog -LogMessage "[SUCCESS] [$Ticket] Adding $ToUser into $group"
        }
        catch {
            Write-MyLog -LogMessage "[ERROR] [$Ticket] $error[0].exception"
        }

    }
}