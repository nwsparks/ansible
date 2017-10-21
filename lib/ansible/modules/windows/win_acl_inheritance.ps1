#!powershell

# Copyright: (c) 2017, Noah Sparks <nsparks@outlook.com>
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy.psm1

import-module c:\ansible\lib\ansible\module_utils\powershell\Ansible.ModuleUtils.Legacy.psm1

$complex_args = @{
    path = 'c:\tools\test'
    #audit_rule = $true
    state = 'present'
    reorganize = $false
}

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false

$result = @{
    changed = $false
}

$path = Get-AnsibleParam -obj $params "path" -type "path" -failifempty $true
$state = Get-AnsibleParam -obj $params "state" -type "str" -default "absent" -validateSet "present","absent"
$retain_acl = Get-AnsibleParam -obj $params "retain_acl" -type "bool" -aliases "reorganize" -default $false
$audit_rule = Get-AnsibleParam -obj $params "audit_rule" -type "bool" -default $false

Try {
    $objACL = Get-ACL -Path $path -Audit
}
Catch {
    Fail-Json -obj $result -message "Failed to retrieve ACL on $Path. Make sure Ansible user has rights. Error returned: $($_.Exception.Message)"
}

#Check if path is inheriting.
#$false if inheritance is set (rules ARE NOT protected from inheritance)
#$true if inheritance is not set (rules ARE protected from inheritance)
Switch ($audit_rule)
{
    $true {$inheritanceDisabled= $objACL.AreAuditRulesProtected}
    $false {$inheritanceDisabled = $objACL.AreAccessRulesProtected}
}

If ($state -eq 'present' -and $inheritanceDisabled -eq $false)
{
    Exit-Json -obj $result
}

If (($state -eq "present") -And $inheritanceDisabled)
{
    # second parameter is ignored if first=$False
    $objACL.SetAccessRuleProtection($False, $False)

    If ($reorganize)
    {
        # it wont work without intermediate save, state would be the same
        Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
        $result.changed = $true
        $objACL = Get-ACL -Path $path

        # convert explicit ACE to inherited ACE
        ForEach($inheritedRule in $objACL.Access)
        {
            If (-not $inheritedRule.IsInherited) {
                Continue
            }

            ForEach($explicitRrule in $objACL.Access)
            {
                If ($explicitRrule.IsInherited) {
                    Continue
                }

                If (($inheritedRule.FileSystemRights -eq $explicitRrule.FileSystemRights) -And ($inheritedRule.AccessControlType -eq $explicitRrule.AccessControlType) -And ($inheritedRule.IdentityReference -eq $explicitRrule.IdentityReference) -And ($inheritedRule.InheritanceFlags -eq $explicitRrule.InheritanceFlags) -And ($inheritedRule.PropagationFlags -eq $explicitRrule.PropagationFlags)) {
                    $objACL.RemoveAccessRule($explicitRrule)
                }
            }
        }
    }

    Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
    $result.changed = $true
}

Elseif (($state -eq "absent") -And (-not $inheritanceDisabled))
{
    $objACL.SetAccessRuleProtection($True, $reorganize)
    Set-ACL -Path $path -AclObject $objACL -WhatIf:$check_mode
    $result.changed = $true
}


    Fail-Json $result "an error occurred when attempting to disable inheritance: $($_.Exception.Message)"

Exit-Json $result
