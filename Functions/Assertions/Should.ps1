function Parse-ShouldArgs([object[]] $shouldArgs) {
    if ($null -eq $shouldArgs) { $shouldArgs = @() }

    $parsedArgs = @{
        PositiveAssertion = $true
        ExpectedValue = $null
    }

    $assertionMethodIndex = 0
    $expectedValueIndex   = 1

    if ($shouldArgs.Count -gt 0 -and $shouldArgs[0] -eq "not") {
        $parsedArgs.PositiveAssertion = $false
        $assertionMethodIndex += 1
        $expectedValueIndex   += 1
    }

    if ($assertionMethodIndex -lt $shouldArgs.Count)
    {
        $parsedArgs.AssertionMethod = "$($shouldArgs[$assertionMethodIndex])"
    }
    else
    {
        throw 'You cannot call Should without specifying an assertion method.'
    }

    if ($expectedValueIndex -lt $shouldArgs.Count)
    {
        $parsedArgs.ExpectedValue = $shouldArgs[$expectedValueIndex]
    }

    return $parsedArgs
}

function Get-TestResult($assertionEntry, $shouldArgs, $value) {
    $testResult = (& $assertionEntry.Test $value $shouldArgs.ExpectedValue)

    if (-not $shouldArgs.PositiveAssertion) {
        return -not $testResult
    }

    return $testResult
}

function Get-FailureMessage($assertionEntry, $shouldArgs, $value) {
    if ($shouldArgs.PositiveAssertion)
    {
        $failureMessageFunction = $assertionEntry.GetPositiveFailureMessage
    }
    else
    {
        $failureMessageFunction = $assertionEntry.GetNegativeFailureMessage
    }

    return (& $failureMessageFunction $value $shouldArgs.ExpectedValue)
}

function New-ShouldException ($Message,$Line) {
    $exception = New-Object Exception $Message
    $errorID = 'PesterAssertionFailed'
    $errorCategory = [Management.Automation.ErrorCategory]::InvalidResult
    $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $null
    $errorRecord.ErrorDetails = "$Message failed at line: $line"

    $errorRecord
}

function Should {
    begin {
        Assert-DescribeInProgress -CommandName Should
        $parsedArgs = Parse-ShouldArgs $args

        $entry = Get-AssertionOperatorEntry -Name $parsedArgs.AssertionMethod
        if ($null -eq $entry)
        {
            throw "'$($parsedArgs.AssertionMethod)' is not a valid Should operator."
        }
    }

    end
    {
        $inputArray = New-Object System.Collections.ArrayList
        foreach ($object in $input) { $null = $inputArray.Add($object) }

        if ($inputArray.Count -eq 0)
        {
            Invoke-Assertion $entry $parsedArgs $null $MyInvocation.ScriptLineNumber
        }
        if ($entry.SupportsArrayInput)
        {
            Invoke-Assertion $entry $parsedArgs $inputArray.ToArray() $MyInvocation.ScriptLineNumber
        }
        else
        {
            foreach ($object in $inputArray)
            {
                Invoke-Assertion $entry $parsedArgs $object $MyInvocation.ScriptLineNumber
            }
        }
    }
}

function Invoke-Assertion($assertionEntry, $shouldArgs, $valueToTest, $lineNumber)
{
    $testSucceeded = Get-TestResult $assertionEntry $shouldArgs $valueToTest
    if (-not $testSucceeded)
    {
        $failureMessage = Get-FailureMessage $assertionEntry $shouldArgs $valueToTest
        throw ( New-ShouldException -Message $failureMessage -Line $lineNumber )
    }
}
