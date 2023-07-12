#==========================================================================================
#
# SCRIPT NAME        :     check_user_in_ADgroup.ps1
#
# AUTHOR             :     Louis GAMBART
# CREATION DATE      :     2023.07.10
# RELEASE            :     v1.0.0
# USAGE SYNTAX       :     .\check_user_in_ADgroup.ps1
#
# SCRIPT DESCRIPTION :     This script is used to check if an AD group has reached a threshold of users in it.
#
#==========================================================================================

#                 - RELEASE NOTES -
# v1.0.0  2022.10.21 - Louis GAMBART - Initial version
#
#==========================================================================================


###################
#                 #
#  I - VARIABLES  #
#                 #
###################

# clear error variable
$error.clear()

# group name
[String] $ADGroupName = ""

# threshold
[Int] $warningThreshold = 40
[Int] $criticalThreshold = 50

# UAC value
[Int] $UAC = 66048

# centreon exit code
# 0 = OK
# 1 = WARNING
# 2 = CRITICAL
# 3 = UNKNOWN


####################
#                  #
#  II - FUNCTIONS  #
#                  #
####################

function Get-ADAllGroupAndMember {
    <#
    .SYNOPSIS
    Get all AD groups and members recursively
    .DESCRIPTION
    Get all AD groups and members recursively
    .INPUTS
    System.String: The AD group name
    .OUTPUTS
    User list
    .EXAMPLE
    Get-ADAllGroupAndMember -ADGroupName "GDL-TEST"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ADGroupName
    )
    begin {}
    process {
        foreach ($name in $ADGroupName) {
            Get-ADGroupMember $name
            Get-ADGroupMember $name | Where-Object {$_.objectClass -eq "group"} | Get-ADAllGroupAndMember
        }
    }
    end {}
}


#########################
#                       #
#  III - ERROR HANDLER  #
#                       #
#########################

# trap errors
trap {
    Write-Output "ERROR: An error has occured and the script can't run: $_"
    exit 2
}


###########################
#                         #
#  IV - SCRIPT EXECUTION  #
#                         #
###########################

try { Import-Module -Name 'ActiveDirectory' }
catch {
    $outLog = @("UNKNOWN: Unable to import the ActiveDirectory module: $_")
    Write-Output $outLog
    exit 3
}

$count = (Get-ADAllGroupAndMember -ADGroupName $ADGroupName | Where-Object {$_.objectClass -eq "user"} | Get-ADUser -Properties userAccountControl | Where-Object { $_.userAccountControl -eq $UAC }).Count
if ($count -lt $warningThreshold) {
    $outLog = @("OK: $ADGroupName group is not full", "There is $count users in the group")
    Write-Output $outLog
    exit 0
}
elseif ($count -ge $warningThreshold -and $count -lt $criticalThreshold)
{
    $outLog = @("WARNING: $ADGroupName group is almost full", "There is $count users in the group out of $criticalThreshold")
    Write-Output $outLog
    exit 1
} else
{
    $outLog = @("CRITICAL: $ADGroupName group is full", "There is $count users in the group out of $criticalThreshold")
    Write-Output $outLog
    exit 2
}