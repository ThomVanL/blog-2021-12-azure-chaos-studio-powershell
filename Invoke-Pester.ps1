#Requires -Version 7
<#
.SYNOPSIS
    Runs Pester tests.
.DESCRIPTION
    Runs Pester test that perform chaos experiments.
.PARAMETER ChaosExperimentsPath
    Provide the path to the directory containing the .Tests.ps1 files.
.INPUTS
    None. You cannot pipe objects to Invoke-Pester.
.OUTPUTS
    None.
.EXAMPLE
    PS C:\> .\Invoke-Pester.ps1 -ChaosExperimentsPath "/workspaces/blog-2021-12-azure-chaos-studio-pester/chaos-experiments"
#>
#Requires -Version 7
[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $ChaosExperimentsPath = (Join-Path -Path $(if ([string]::IsNullOrEmpty($PSScriptRoot)) { "." } else { $PSScriptRoot }) -ChildPath "chaos-experiments")
)
Import-Module -Name "Pester" -RequiredVersion "5.3.1" -Force
Import-Module -Name (Join-Path -Path $(if ([string]::IsNullOrEmpty($PSScriptRoot)) { "." } else { $PSScriptRoot }) -ChildPath "SteadyStateHypothesisAssertions" -AdditionalChildPath "SteadyStateHypothesisAssertions.psm1") -DisableNameChecking -Force

if (!(Test-Path $chaosExperimentsPath)) {
    Write-Error -Message "Path to experiments not found." -ErrorAction Stop
}

if (!(Get-AzContext)) {
    Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop
}

if ((Get-AzContext)) {
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
    $container = New-PesterContainer -Path 'website.chaos.experiment.tests.ps1' -Data @{ ResourceGroupName = "<replace-with-your-resource-group-name>"; WebsiteUrl = "http://<replace-with-your-vm-ip>"; ExperimentName = "tvl-azcs-blog-experiment" }
    $PesterConfig = New-PesterConfiguration -HashTable @{
        Run    = @{
            Path      = $ChaosExperimentsPath
            Container = $container
            # SkipRemainingOnFailure = 'Container' # 👈  Only skips tests, but will still execute Before* and After* blocks.
        }
        Output = @{
            Verbosity = "Detailed" # Verbosity: The verbosity of output, options are None, Normal, Detailed and Diagnostic.
        }
        Should = @{
            ErrorAction = 'Continue'
        }
    }
    Invoke-Pester  -Configuration $PesterConfig
}