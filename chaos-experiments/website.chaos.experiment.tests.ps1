#Requires -Version 7
[CmdletBinding()]
<#
.SYNOPSIS
    Starts an chaos experiment and performs tests.
.DESCRIPTION
    Tests the steady state hypothesis of a web resource during the first pass of the steady-state hypothesis.
    If the first pass of the steady state hypothesis is valid:
    - The experiment method runs and an Azure Chaos Studio experiment is started.
    - The steady state hypothesis is validated in a second pass.
    - The rollback section kicks off, canceling the Azure Chaos Studio experiment.
.PARAMETER ExperimentName
    Provide the Azure Chaos Studio experiment name.
.PARAMETER ResourceGroupName
    Provide the resource group name which holds the Azure Chaos Studio experiment.
.PARAMETER WebsiteUrl
    Provide the address of a the chaos target resource.
.INPUTS
    None.
.OUTPUTS
    System.Management.Automation.PSObject
.EXAMPLE
    PS C:\> .\website.chaos.experiment.tests.ps1 -ExperimentName "" -ResourceGroupName "tvl-azcs-rg" -WebsiteUrl "https://thomasvanlaere.com""
#>
param (
    [Parameter(Mandatory = $true)]
    [string]
    $ExperimentName,
    [Parameter(Mandatory = $true)]
    [string]
    $ResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]
    $WebsiteUrl
)


BeforeDiscovery {
    # Get the chaos experiment resource
    $ChaosExperimentResource = Get-AzResource -ResourceType "Microsoft.Chaos/experiments" -Name $ExperimentName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    $isExperimentAvailableForStart = $false
    if ($null -ne $ChaosExperimentResource) {
        # Running Invoke-AzRestMethod with a relative URL will *sometimes* result in:
        # "This operation is not supported for a relative URI".
        # So we will prefix the url with "https://management.azure.com",
        # turning it into an absolute URL, for now. 🤷‍♂️
        $experimentStatusesUrl = '{0}{1}/statuses?api-version=2021-09-15-preview' -f "https://management.azure.com", $ChaosExperimentResource.Id
        $experimentStatusesResponse = Invoke-AzRestMethod -Uri $experimentStatusesUrl -Method Get
        if ($null -ne $experimentStatusesResponse) {
            $experimentStatusesResult = $experimentStatusesResponse.Content | ConvertFrom-Json
            $isExperimentAvailableForStart = ($experimentStatusesResult.Value | Where-Object { $_.properties.status -iin "preprocessingqueued", "running", "cancelling" }) -eq $null
            # Going to assume that the frequencies of the runs is low enough so
            # I do not need to worry about the "nextLink" property, fingers crossed.
            # 👆 I want to skip this set of tests when a Chaos Studio experiment has already been queued,
            # started its run or is in the process of cancelling.
        }
    }

    # A function which contains the steady-state hypothesis test.
    function Invoke-SteadyStateHypothesis {
        Context "steady-state hypothesis" {
            BeforeAll {
                # Since this block is called twice we must check whether
                # the first pass has failed, so we can skip the second pass.
                if (!(Test-SteadyStateHypothesisFirstPass)) { return; }

                $webResponse = try { Invoke-WebRequest -Uri $WebsiteUrl -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck } catch { $_ | Write-Verbose }
            }

            BeforeEach {
                Skip-SteadyStateHypothesisWhenFirstPassFailed
            }

            It "should return status code 200" {
                # Remember, the both passes are initially marked as OK (true)
                # and will switch to NOT OK (false), when the custom should assertion operator
                # detects a mistake.
                $webResponse.StatusCode | Should -BeSteadyStateHypothesisValue 200
            }

            AfterAll {
                # Once everything has been completed in this context block,
                # tell our module to get ready for pass two.
                Complete-SteadyStateHypothesisPass
            }
        }
    }

    # A function which contains the chaos experiment methods
    function Invoke-ExperimentMethods {
        Context "experiment activities" {
            Context "Azure Chaos Studio" {
                BeforeAll {
                    # If the first pass failed, skip the experiment setup phase.
                    if (!(Test-SteadyStateHypothesisFirstPass)) { return; }

                    # Request a start of the Azure Chaos Experiment
                    $startExperimentUrl = '{0}/start?api-version=2021-09-15-preview' -f $ChaosExperimentResource.Id
                    $startExperimentReponse = Invoke-AzRestMethod -Path $startExperimentUrl -Method POST
                    $experimentStartOperationResult = $startExperimentReponse.Content | ConvertFrom-Json

                    # Track the status of the start request
                    $experimentStatusResponse = Invoke-AzRestMethod -Uri $experimentStartOperationResult.statusUrl -Method Get
                    $experimentStatusResult = $experimentStatusResponse.Content | ConvertFrom-Json
                    # 👇 If we're fortunate enough, we can get the status we are looking for immediately.
                    while ($experimentStatusResponse.StatusCode -ne 404 -AND $experimentStatusResult.properties.Status -inotin "Running", "Failed", "Cancelled" ) {
                        Start-Sleep -Seconds 5
                        $experimentStatusResult = $null
                        $experimentStatusResponse = Invoke-AzRestMethod -Uri $experimentStartOperationResult.statusUrl -Method Get
                        $experimentStatusResult = $experimentStatusResponse.Content | ConvertFrom-Json
                    }

                    # Get the experiment's execution details, allowing us to track the status of individual "steps" in the experiment.
                    $executionDetailsUrl = '{0}{1}/executionDetails/{2}?api-version=2021-09-15-preview' -f "https://management.azure.com", $ChaosExperimentResource.Id, $experimentStatusResult.name
                    $executionDetailsResponse = Invoke-AzRestMethod -Uri $executionDetailsUrl -Method Get
                    $executionDetailsResult = $executionDetailsResponse.Content | ConvertFrom-Json
                    # And again if we're fortunate enough we might just get the result straight away.
                    $executionAction = $executionDetailsResult.properties.runInformation.steps | Where-Object { $_.branches.actions.actionName -ieq "urn:csci:microsoft:networkSecurityGroup:securityRule/1.0" }
                    # If not, we'll wait for it.
                    while ($executionDetailsResponse.StatusCode -ne 404 -AND $executionAction.Status -inotin "Running", "Failed", "Cancelled", "Completed" ) {
                        Start-Sleep -Seconds 5
                        $executionDetailsResult = $null
                        $executionDetailsResponse = Invoke-AzRestMethod -Uri $executionDetailsUrl.statusUrl -Method Get
                        $executionDetailsResult = $executionDetailsResponse.Content | ConvertFrom-Json
                        # Since my complete ARM template only has one step with this action name I'm going to assume the Where-Object will return one result.
                        $executionAction = $executionDetailsResult.properties.runInformation.steps | Where-Object { $_.branches.actions.actionName -ieq "urn:csci:microsoft:networkSecurityGroup:securityRule/1.0" }
                    }
                }

                BeforeEach {
                    # If the first pass has failed, set each it block as skipped.
                    Skip-SteadyStateHypothesisWhenFirstPassFailed
                }

                It "should have accepted the start the Azure Chaos Studio experiment" {
                    $startExperimentReponse.StatusCode | Should -Be 202
                }

                It "should have the Azure Chaos Studio experiment in running state" {
                    $experimentStatusResult.properties.Status | Should -Be "Running"
                }

                It "should have a NSG security rule fault action in running state, in the running Azure Chaos Studio experiment" {
                    if ($experimentStatusResult.properties.Status -ine "Running") {
                        Set-ItResult -Skipped "experiment is not in running state."
                    }

                    $executionDetailsResult.properties | Should -Not -BeNullOrEmpty
                    $executionDetailsResult.properties.runInformation | Should -Not -BeNullOrEmpty
                    $executionAction | Should -Not -BeNullOrEmpty
                    $executionAction | Should -HaveCount 1
                    $executionAction.Status | Should -Be "Running"
                }

                It "should pause <_> seconds for changes to take effect." -ForEach(60) {
                    Start-Sleep -Seconds $_
                }
            }

        }
    }

    # A function which contains the rollback actions
    function Invoke-RollbackActions {
        Context "rollback actions" {
            Context "Azure Chaos Studio" {
                BeforeAll {
                    # If the first pass failed, skip the rollback setup phase.
                    if (!(Test-SteadyStateHypothesisFirstPass)) { return; }

                    # Request cancellation of the Azure Chaos Studio experiment
                    $cancelExperimentPath = '{0}/cancel?api-version=2021-09-15-preview' -f $ChaosExperimentResource.Id
                    $cancelExperimentReponse = Invoke-AzRestMethod -Path $cancelExperimentPath -Method POST
                    $experimentStartOperationResult = $cancelExperimentReponse.Content | ConvertFrom-Json

                    # Track the status of the cancellation request
                    $experimentStatusResponse = Invoke-AzRestMethod -Uri $experimentStartOperationResult.statusUrl -Method Get
                    $experimentStatusResult = $experimentStatusResponse.Content | ConvertFrom-Json
                    while ($experimentStatusResponse.StatusCode -ne 404 -AND $experimentStatusResult.properties.Status -inotin "Success", "Failed", "Cancelled" ) {
                        Start-Sleep -Seconds 5
                        $experimentStatusResult = $null
                        $experimentStatusResponse = Invoke-AzRestMethod -Uri $experimentStartOperationResult.statusUrl -Method Get
                        $experimentStatusResult = $experimentStatusResponse.Content | ConvertFrom-Json
                    }
                }
                BeforeEach {
                    # If the first pass has failed, set each it block as skipped.
                    Skip-SteadyStateHypothesisWhenFirstPassFailed
                }

                It "should accept the cancelation request of the Azure Chaos Studio experiment" {
                    $cancelExperimentReponse.StatusCode | Should -Be 202
                }

                It "should have rolled back the Azure Chaos Studio experiment" {
                    $experimentStatusResult.properties.Status | Should -BeIn "Success", "Cancelled"
                }
            }
        }
    }
}

BeforeAll {
    # Ensure any previous state is cleaned up
    # before any of these test start
    Reset-SteadyStateHypothesis
}

# Only run the pester chaos experiment only if the Azure Chaos Studio Experiment
# exists and it is not performing anything else.
#
# By using the -ForEach param we can pass the ChaosExperimentResource variable
# from the discovery phase into the run phase.
Describe    -Name "Chaos Experiment: $resourceGroupName\$ExperimentName - Testing endpoint $WebsiteUrl" `
    -Tag "Chaos" `
    -ForEach @( @{ChaosExperimentResource = $ChaosExperimentResource }) `
    -Skip:($null -eq $ChaosExperimentResource -OR $isExperimentAvailableForStart -eq $false) `
    -Fixture {
    Invoke-SteadyStateHypothesis
    Invoke-ExperimentMethods
    Invoke-SteadyStateHypothesis
    Invoke-RollbackActions
}

AfterAll {
    # Ensure any previous state is cleaned up
    # after all tests are done.
    Reset-SteadyStateHypothesis
}