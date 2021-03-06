CLS
. PSUnit.ps1
import-module Agent

#function Test.Get-AgentJobServer([switch] $Skip)
function Test.Get-AgentJobServer([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = Get-AgentJobServer "$env:computername\sql2K8"
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'JobServer'}
}

#function Test.Get-AgentAlertCategory([switch] $Skip)
function Test.Get-AgentAlertCategory([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentAlertCategory "$env:computername\sql2K8")[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'AlertCategory'}
}

#function Test.Get-AgentAlert([switch] $Skip)
function Test.Get-AgentAlert([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentAlert "$env:computername\sql2K8")[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'Alert'}
}

#function Test.Get-AgentJob([switch] $Skip)
function Test.Get-AgentJob([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentJob "$env:computername\sql2K8")[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'Job'}
}

#function Test.Get-AgentJobSchedule([switch] $Skip)
function Test.Get-AgentJobSchedule([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentJob "$env:computername\sql2K8" | Get-AgentJObSchedule)[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'JobSchedule'}
}

#function Test.Get-AgentJobStep([switch] $Skip)
function Test.Get-AgentJobStep([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentJob "$env:computername\sql2K8" | Get-AgentJobStep)[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'JobStep'}
}

#function Test.Get-AgentOperator([switch] $Skip)
function Test.Get-AgentOperator([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = Get-AgentOperator "$env:computername\sql2K8"
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'Operator'}
}

#function Test.Get-AgentOperatorCategory([switch] $Skip)
function Test.Get-AgentOperatorCategory([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = Get-AgentOperatorCategory "$env:computername\sql2K8"
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'OperatorCategory'}
}

#function Test.Get-AgentSchedule([switch] $Skip)
function Test.Get-AgentSchedule([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentSchedule "$env:computername\sql2K8")[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'JobSchedule'}
}

#function Test.Get-AgentJobHistory([switch] $Skip)
function Test.Get-AgentJobHistory([switch] $Category_GetAgent)
{
    #Arrange
    #Act
    $Actual = (Get-AgentJobHistory "$env:computername\sql2k8" $(Set-AgentJobHistoryFilter -outcome 'Failed'))[0]
    Write-Debug $Actual
    #Assert
    Assert-That -ActualValue $Actual -Constraint {$ActualValue.GetType().Name -eq 'DataRow'}
}

