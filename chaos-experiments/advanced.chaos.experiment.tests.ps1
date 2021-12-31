
BeforeDiscovery {
    $global:IsSteadystateOk = $true
}

BeforeAll {
    function Test-SteadyStateHasError ($errorVar) {
        if ($null -ne $errorVar -AND $errorVar.Count -gt 0) { $global:IsSteadystateOk = $false }
    }

    function Skip-IfSteadyStateInvalid {
        if (!$global:IsSteadystateOk) { Set-ItResult -Skipped -Because "steady state failed" }
    }
}

Describe "A chaos experiment 4" {
    Context "Steady-state hypothesis" {
        BeforeAll {
            Write-Host "Pass 1"
            try { $webResponse = Invoke-WebRequest -Uri "thomasvanlaere.com/fail" -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck }catch {}
        }

        It "should return status code 200" {
            $webResponse.StatusCode | Should -Be 200 -ErrorVariable hasError -ErrorAction SilentlyContinue
            Test-SteadyStateHasError $hasError
        }

        It "should have content" {
            $webResponse.StatusCode | Should -Be 200 -ErrorVariable hasError -ErrorAction SilentlyContinue
            Test-SteadyStateHasError $hasError

            $webResponse.Content | Should -Not -BeNullOrEmpty -ErrorVariable hasError -ErrorAction SilentlyContinue
            Test-SteadyStateHasError $hasError
        }

        AfterAll {
            Write-Host "`$global:IsSteadystateOk: $($global:IsSteadystateOk)"
        }
    }

    Context "Method" {
        BeforeAll {
            if (!$global:IsSteadystateOk) { return }
            Write-Host "Injecting some faults.."
            $someResult = @{Id = "hello there!" }
        }

        BeforeEach {
            Skip-IfSteadyStateInvalid
        }

        It "should have an id" {
            $someResult.Id | Should -Not -BeNullOrEmpty
        }
    }

    Context "Rollback" {
        BeforeAll {
            if (!$global:IsSteadystateOk) { return }
            Write-Host "Rolling back faults.."
            $someResult = @{StatusUrl = "https://some.url.com" }
        }

        BeforeEach {
            if (!$global:IsSteadystateOk) { Set-ItResult -Skipped -Because "steady state failed" }
        }

        It "should have a StatusUrl" {
            $someResult.StatusUrl | Should -Not -BeNullOrEmpty
        }
    }

    Context "Steady-state hypothesis" {
        BeforeAll {
            Write-Host "Pass 2"
            if (!$global:IsSteadystateOk) { return }
            try { $webResponse = Invoke-WebRequest -Uri "thomasvanlaere.com" -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck }catch {}
        }

        BeforeEach {
            Skip-IfSteadyStateInvalid
        }

        It "should return status code 200" {
            $webResponse.StatusCode | Should -Be 200
        }

        It "should have content" {
            $webResponse.Content | Should -Not -BeNullOrEmpty
        }
    }
}

AfterAll {
    $global:IsSteadystateOk = $true
}