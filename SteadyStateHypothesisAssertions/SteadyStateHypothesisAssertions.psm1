enum SteadyStateHypothesisPassType {
    First = 0
    Second = 1
}

# Track the state in a small array, one value for each of the two runs
$script:SteadyStatePasses = @($true, $true)
# When the module is loaded set the current pass to 'First'
[SteadyStateHypothesisPassType]$script:CurrentPass = [SteadyStateHypothesisPassType]::First

function Should-BeSteadyStateHypothesisValue ($ActualValue, $ExpectedValue, [switch] $Negate, [string] $Because) {
    <#
    .SYNOPSIS
        Checks whether the provided value matches the expected value.
    .EXAMPLE
        $greeting = "Hello world"
        $greeting | Should -BeSteadyStateHypothesisValue "Hello world"

        Checks if the greeting variable matches "Hello world" . This should pass.
    .EXAMPLE
        $greeting = "Hello world"
        $greeting | Should -Not -BeSteadyStateHypothesisValue "Hello world"

        Checks if the greeting variable does not match "Hello world". This should not pass.
    #>

    # 👇 Good enough for now
    [bool] $succeeded = $ActualValue -eq $ExpectedValue

    if ($Negate) {
        $succeeded = -not $succeeded
    }

    $failureMessage = ''

    if (-not $succeeded) {
        if ($Negate) {
            $failureMessage = "Steady-state hypothesis failed: Expected $ExpectedValue to be different from the actual value,$(if ($null -ne $Because) { $Because }) but got the same value."
        }
        else {
            $failureMessage = "Steady-state hypothesis failed: Expected $ExpectedValue,$(if ($null -ne $Because) { $Because }) but got $(if ($null -eq $ActualValue){'$null'} else {$ActualValue})."
        }

        # 👇 If it fails once, toggle the variable
        $script:SteadyStatePasses[$script:CurrentPass] = $false
    }

    return [PSCustomObject] @{
        Succeeded      = $succeeded
        FailureMessage = $failureMessage
    }
}

function Get-SteadyStateHypothesisStatus {
    <#
    .SYNOPSIS
        Get the current steady state hypothesis pass's status.

    .DESCRIPTION
        Get the current steady state hypothesis pass's status.
        $true when succesful.
        $false when failed.

    .PARAMETER Pass
        'First' or 'Second'

    .EXAMPLE
        Get-SteadyStateHypothesisStatus -Pass First

    .EXAMPLE
        Get-SteadyStateHypothesisStatus -Pass Second

    .OUTPUTS
        [bool]result
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [SteadyStateHypothesisPassType]
        $Pass
    )
    if ($null -eq $script:SteadyStatePasses[$Pass]) {
        throw "No steady state hypothesis value was found."
    }
    else {
        return $script:SteadyStatePasses[$Pass];
    }
}

function Skip-SteadyStateHypothesisWhenFirstPassFailed {
    <#
    .SYNOPSIS
        Set an It block's result to 'skipped'.

    .DESCRIPTION
        Set an It block's result to 'skipped'.

    .EXAMPLE
        Skip-SteadyStateHypothesisWhenFirstPassFailed

    #>
    [CmdletBinding()]
    param ()
    if (!(Test-SteadyStateHypothesisFirstPass)) {
        Set-ItResult -Skipped -Because "the first pass of the steady-state hypothesis did not complete succesfully."
    }
}

function Test-SteadyStateHypothesisFirstPass {
    <#
    .SYNOPSIS
        Return true or false to indicate whether the first pass has succeeded.

    .DESCRIPTION
        Return true or false to indicate whether the first pass has succeeded.
        $true when succesful.
        $false when failed.

    .EXAMPLE
        Test-SteadyStateHypothesisFirstPass

    .OUTPUTS
        [bool]result
    #>

    [CmdletBinding()]
    param ()
    return (Get-SteadyStateHypothesisStatus -Pass First)
}

function Test-SteadyStateHypothesisSecondPass {
    <#
    .SYNOPSIS
        Return true or false to indicate whether the second pass has succeeded.

    .DESCRIPTION
        Return true or false to indicate whether the second pass has succeeded.
        $true when succesful.
        $false when failed.

    .EXAMPLE
        Test-SteadyStateHypothesisSecondPass

    .OUTPUTS
        [bool]result
    #>
    [CmdletBinding()]
    param ()
    return (Get-SteadyStateHypothesisStatus -Pass Second)
}

function Get-SteadyStateHypothesisCurrentPass {
    <#
    .SYNOPSIS
    Returns the current pass number.

    .DESCRIPTION
    Returns the current pass number.

    .EXAMPLE
    Get-SteadyStateHypothesisCurrentPass

    .OUTPUTS
    [SteadyStateHypothesisPassType]
    #>
    [CmdletBinding()]
    param ()
    $script:CurrentPass
}

function Set-SteadyStateHypothesisCurrentPass {
    <#
    .SYNOPSIS
    Sets the current pass number.

    .DESCRIPTION
    Sets the current pass number.

    .EXAMPLE
    Set-SteadyStateHypothesisCurrentPass -Pass First

    .EXAMPLE
    Set-SteadyStateHypothesisCurrentPass -Pass Second
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [SteadyStateHypothesisPassType]
        $Pass
    )
    $script:CurrentPass = $Pass
}

function Complete-SteadyStateHypothesisPass {
    <#
    .SYNOPSIS
    Sets the current pass number to the next available pass.

    .DESCRIPTION
    Sets the current pass number to the next available pass.

    .EXAMPLE
    Complete-SteadyStateHypothesisPass
    #>
    [CmdletBinding()]
    param ()
    switch ($script:CurrentPass) {
        ([SteadyStateHypothesisPassType]::First) {
            Set-SteadyStateHypothesisCurrentPass -Pass Second;
            break;
        }
        ([SteadyStateHypothesisPassType]::Second) {
            break; <# Don't do anything 🤷‍♂️ #>
        }
        Default {
            throw "Uhm"
        }
    }
}


function Reset-SteadyStateHypothesis {
    <#
    .SYNOPSIS
    Sets both passes to their default value ($true) and sets the current pass to first.

    .DESCRIPTION
    Sets both passes to their default value ($true) and sets the current pass to first.

    .EXAMPLE
    Reset-SteadyStateHypothesis
    #>
    [CmdletBinding()]
    param ()
    $script:SteadyStatePasses = @($true, $true)
    $script:CurrentPass = [SteadyStateHypothesisPassType]::First
}


# Add all ShouldOperators
@(
    @{Name = "BeSteadyStateHypothesisValue" ; InternalName = 'Should-BeSteadyStateHypothesisValue'; Test = ${function:Should-BeSteadyStateHypothesisValue} ; Alias = 'BSSHV' }
) | ForEach-Object {
    try { $existingShouldOp = Get-ShouldOperator -Name $_.Name } catch { $_ | Write-Verbose }
    if (!$existingShouldOp) {
        Add-ShouldOperator -Name $_.Name -InternalName $_.InternalName -Test $_.Test -Alias $_.Alias
    }
}