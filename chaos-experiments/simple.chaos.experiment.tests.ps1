
BeforeDiscovery {
    $global:IsSteadystateOk = $true
}

Describe "A chaos experiment 1" {
    Context "Steady-state hypothesis" {
        BeforeAll {
            $webResponse = Invoke-WebRequest -Uri "thomasvanlaere.com/fail" -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck
        }
        It "should return status code 200" {
            $result = $webResponse.StatusCode | Should -Be 200
            if ($result -eq "?") { # This won't ever work
                $global:IsSteadystateOk = $false
            }
        }
        AfterAll{
            Write-Host "`$global:IsSteadystateOk: $($global:IsSteadystateOk)"
        }
    }
}

Describe "A chaos experiment 2" {
    Context "Steady-state hypothesis" {
        BeforeAll {
            $webResponse = Invoke-WebRequest -Uri "thomasvanlaere.com/fail" -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck
        }
        It "should return status code 200" {
            try {
                $webResponse.StatusCode | Should -Be 200
            }
            catch {
                $global:IsSteadystateOk = $false
                throw $_
            }
        }
        AfterAll {
            Write-Host "`$global:IsSteadystateOk: $($global:IsSteadystateOk)"
        }
    }
}

Describe "A chaos experiment 3" {
    Context "Steady-state hypothesis" {
        BeforeAll {
            Write-Host "Pass 1"
            # 👇 Url has changed
            try { $webResponse = Invoke-WebRequest -Uri "thomasvanlaere.com" -MaximumRetryCount 1 -TimeoutSec 3 -SkipHttpErrorCheck }catch {}
        }

        It "should return status code 200" {
            try {
                $webResponse.StatusCode | Should -Be 200
            }
            catch {
                $global:IsSteadystateOk = $false
                throw $_
            }
        }

        It "should have content" {
            try {
                $webResponse.Content | Should -Not -BeNullOrEmpty
            }
            catch {
                $global:IsSteadystateOk = $false
                throw $_
            }
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
            if (!$global:IsSteadystateOk) { Set-ItResult -Skipped -Because "steady state failed" }
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
            if (!$global:IsSteadystateOk) { Set-ItResult -Skipped -Because "steady state failed" }
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