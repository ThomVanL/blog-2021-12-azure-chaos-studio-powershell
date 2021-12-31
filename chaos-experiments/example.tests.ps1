BeforeAll {
    function Get-Hello {
        return "Hello world"
    }
}
Describe -Name "Get-Hello" -Fixture {
    It -Name "return 'Hello world'" -Test {
        $result = Get-Hello
        $result | Should -Be "Hello world"
    }
}