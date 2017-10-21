#!powershell

# Copyright: (c) 2017, Noah Sparks <nsparks@outlook.com>
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy.psm1

import-module c:\ansible\lib\ansible\module_utils\powershell\Ansible.ModuleUtils.Legacy.psm1

$complex_args = @{
    path = 'c:\tools\test'
    #audit_rule = $true
    state = 'absent'
    #reorganize = $true
    audit_rule = $true
}

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false

$result = @{
    changed = $false
}

$path = Get-AnsibleParam -obj $params "path" -type "path" -failifempty $true
$state = Get-AnsibleParam -obj $params "state" -type "str" -default "absent" -validateSet "present","absent"
$reorganize = Get-AnsibleParam -obj $params "reorganize" -type "bool" -default $false
$audit_rule = Get-AnsibleParam -obj $params "audit_rule" -type "bool" -default $false

Try {
    $objACL = Get-ACL -Path $path -Audit
}
Catch {
    Fail-Json -obj $result -message "Failed to retrieve ACL on $Path. Make sure Ansible user has rights. Error returned: $($_.Exception.Message)"
}

# Check if path is inheriting.
# $false if inheritance is set (rules ARE NOT protected from inheritance)
# $true if inheritance is not set (rules ARE protected from inheritance)
If ($audit_rule)
{
    $inheritanceDisabled= $objACL.AreAuditRulesProtected
    $AccessType = 'AuditFlags'
    $RemoveType = 'RemoveAuditRule'
    $SetProtectionType = 'SetAuditRuleProtection'
}
Else
{
    $inheritanceDisabled = $objACL.AreAccessRulesProtected
    $AccessType = 'AccessControlType'
    $RemoveType = 'RemoveAccessRule'
    $SetProtectionType = 'SetAccessRuleProtection'
}

If ($state -eq "present" -And $inheritanceDisabled)
{

    # Change object to allow inheritance again.
    # first $false = isProtected
    # true to protect the access rules associated with this ObjectSecurity object from inheritance; false to allow inheritance.
    # second $false = preserveInheritance
    # true to preserve inherited access rules; false to remove inherited access rules. This parameter is ignored if isProtected is false.
    $objACL.$SetProtectionType($False, $False)

    # Enable inheritance. It needs to be done before $reorganize, otherwise all rules will show as
    # IsInherited: False
    Try {
        Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
        $result.changed = $true
    }
    Catch {
        Fail-Json -obj $result -message "Failed to enable inheritance. $($_.Exception.Message)"
    }

    # Once it is enabled, we can then compare the explicit to inherited rules and deduplicate.
    If ($reorganize)
    {
        Try {
            $objACL = Get-ACL -Path $path -Audit
        }
        Catch {
            $msg = "Inheritance was enabled, but an error occurred when re-reading the ACL for the reorganize operation. Error returned: $($_.Exception.Message)"
            Fail-Json -obj $result -message $msg
        }

        # Remove explicit rules that are the same as inherited rules
        If ($audit_rule)
        {
            $ExplicitRules = $objACL.Audit | Where-Object {$_.IsInherited -eq $false}
            $InheritedRules = $objACL.Audit | Where-Object {$_.IsInherited}

        }
        Else
        {
            $ExplicitRules = $objACL.Access | Where-Object {$_.IsInherited -eq $false}
            $InheritedRules = $objACL.Access | Where-Object {$_.IsInherited}

        }

        ForEach($inheritedRule in $InheritedRules)
        {
            ForEach($explicitRule in $ExplicitRules)
            {
                If
                (
                    ($inheritedRule.FileSystemRights -eq $explicitRule.FileSystemRights) -And
                    ($inheritedRule.$AccessType -eq $explicitRule.$AccessType) -And
                    ($inheritedRule.IdentityReference -eq $explicitRule.IdentityReference) -And
                    ($inheritedRule.InheritanceFlags -eq $explicitRule.InheritanceFlags) -And
                    ($inheritedRule.PropagationFlags -eq $explicitRule.PropagationFlags)
                )
                {
                    $Null = $objACL.$RemoveType($explicitRule)
                }
            }
        }

        #set deduplicated permissions.
        Try {
            Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
            $result.changed = $true
        }
        Catch {
            Fail-Json -obj $result -message "Failed to perform reorganize. $($_.Exception.Message)"
        }
    }
}

Elseif ($state -eq "absent" -and $inheritanceDisabled -eq $false)
{
    $objACL.$SetProtectionType($True, $reorganize)

    Try {
        Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
        $result.changed = $true
    }
    Catch {
        Fail-Json -obj $result -message "Failed to remove inheritance. $(_.Exception.Message)"
    }
}

Exit-Json $result
