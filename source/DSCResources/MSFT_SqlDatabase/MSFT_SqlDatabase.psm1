$script:resourceModulePath = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:modulesFolderPath = Join-Path -Path $script:resourceModulePath -ChildPath 'Modules'

$script:resourceHelperModulePath = Join-Path -Path $script:modulesFolderPath -ChildPath 'SqlServerDsc.Common'
Import-Module -Name (Join-Path -Path $script:resourceHelperModulePath -ChildPath 'SqlServerDsc.Common.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_SqlDatabase'

$script:supportedCompatibilityLevels = @{
    8 = @('Version80')
    9 = @('Version80', 'Version90')
    10 = @('Version80', 'Version90', 'Version100')
    11 = @('Version90', 'Version100', 'Version110')
    12 = @('Version100', 'Version110', 'Version120')
    13 = @('Version100', 'Version110', 'Version120', 'Version130')
    14 = @('Version100', 'Version110', 'Version120', 'Version130', 'Version140')
    15 = @('Version100', 'Version110', 'Version120', 'Version130', 'Version140', 'Version150')
}

<#
    .SYNOPSIS
    This function gets the sql database.

    .PARAMETER Ensure
    When set to 'Present', the database will be created.
    When set to 'Absent', the database will be dropped.

    .PARAMETER Name
    The name of database to be created or dropped.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER Collation
    The name of the SQL collation to use for the new database.
    Defaults to server collation.

    .PARAMETER CompatibilityLevel
    The version of the SQL compatibility level to use for the new database.
    Defaults to server version.

    .PARAMETER RecoveryModel
    The recovery model to be used for the new database.
    Defaults to Full.
#>

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Collation,

        [Parameter()]
        [ValidateSet('Version80', 'Version90', 'Version100', 'Version110', 'Version120', 'Version130', 'Version140', 'Version150')]
        [System.String]
        $CompatibilityLevel,

        [Parameter()]
        [ValidateSet('Simple', 'Full', 'BulkLogged')]
        [System.String]
        $RecoveryModel
    )

    Write-Verbose -Message (
        $script:localizedData.GetDatabase -f $Name, $InstanceName
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        # Check database exists
        $sqlDatabaseObject = $sqlServerObject.Databases[$Name]

        if ($sqlDatabaseObject)
        {
            $Ensure = 'Present'
            $sqlDatabaseCollation = $sqlDatabaseObject.Collation
            $sqlDatabaseCompatibilityLevel = $sqlDatabaseObject.CompatibilityLevel
            $sqlDatabaseRecoveryModel = $sqlDatabaseObject.RecoveryModel

            Write-Verbose -Message (
                $script:localizedData.DatabasePresent -f $Name, $sqlDatabaseCollation, $sqlDatabaseCompatibilityLevel, $sqlDatabaseRecoveryModel
            )
        }
        else
        {
            $Ensure = 'Absent'

            Write-Verbose -Message (
                $script:localizedData.DatabaseAbsent -f $Name
            )
        }
    }

    $returnValue = @{
        Name               = $Name
        Ensure             = $Ensure
        ServerName         = $ServerName
        InstanceName       = $InstanceName
        Collation          = $sqlDatabaseCollation
        CompatibilityLevel = $sqlDatabaseCompatibilityLevel
        RecoveryModel      = $sqlDatabaseRecoveryModel
    }

    $returnValue
}

<#
    .SYNOPSIS
    This function create or delete a database in the SQL Server instance provided.

    .PARAMETER Ensure
    When set to 'Present', the database will be created.
    When set to 'Absent', the database will be dropped.

    .PARAMETER Name
    The name of database to be created or dropped.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER Collation
    The name of the SQL collation to use for the new database.
    Defaults to server collation.

    .PARAMETER CompatibilityLevel
    The version of the SQL compatibility level to use for the new database.
    Defaults to server version.

    .PARAMETER RecoveryModel
    The recovery model to be used for the new database.
    Defaults to Full.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Collation,

        [Parameter()]
        [ValidateSet('Version80', 'Version90', 'Version100', 'Version110', 'Version120', 'Version130', 'Version140', 'Version150')]
        [System.String]
        $CompatibilityLevel,

        [Parameter()]
        [ValidateSet('Simple', 'Full', 'BulkLogged')]
        [System.String]
        $RecoveryModel
    )

    $sqlServerObject = Connect-SQL -ServerName $ServerName -InstanceName $InstanceName
    if ($sqlServerObject)
    {
        if ($Ensure -eq 'Present')
        {
            if (-not $PSBoundParameters.ContainsKey('Collation'))
            {
                $Collation = $sqlServerObject.Collation
            }
            elseif ($Collation -notin $sqlServerObject.EnumCollations().Name)
            {
                $errorMessage = $script:localizedData.InvalidCollation -f $Collation, $InstanceName
                New-ObjectNotFoundException -Message $errorMessage
            }

            if (-not $PSBoundParameters.ContainsKey('CompatibilityLevel'))
            {
                $CompatibilityLevel = $supportedCompatibilityLevels.$($sqlServerObject.VersionMajor) | Select-Object -Last 1
            }
            elseif ($CompatibilityLevel -notin $supportedCompatibilityLevels.$($sqlServerObject.VersionMajor))
            {
                $errorMessage = $script:localizedData.InvalidCompatibilityLevel -f $CompatibilityLevel, $InstanceName
                New-ObjectNotFoundException -Message $errorMessage
            }

            $sqlDatabaseObject = $sqlServerObject.Databases[$Name]
            if ($sqlDatabaseObject)
            {
                Write-Verbose -Message (
                    $script:localizedData.SetDatabase -f $Name, $InstanceName
                )

                try
                {
                    Write-Verbose -Message (
                        $script:localizedData.UpdatingDatabase -f $Collation, $CompatibilityLevel
                    )

                    $sqlDatabaseObject.Collation = $Collation
                    $sqlDatabaseObject.CompatibilityLevel = $CompatibilityLevel

                    if ($PSBoundParameters.ContainsKey('RecoveryModel'))
                    {
                        Write-Verbose -Message (
                            $script:localizedData.UpdatingRecoveryModel -f $RecoveryModel
                        )
                        $sqlDatabaseObject.RecoveryModel = $RecoveryModel
                    }

                    $sqlDatabaseObject.Alter()
                }
                catch
                {
                    $errorMessage = $script:localizedData.FailedToUpdateDatabase -f $Name
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }
            else
            {
                try
                {
                    $sqlDatabaseObjectToCreate = New-Object -TypeName 'Microsoft.SqlServer.Management.Smo.Database' -ArgumentList $sqlServerObject, $Name
                    if ($sqlDatabaseObjectToCreate)
                    {
                        Write-Verbose -Message (
                            $script:localizedData.CreateDatabase -f $Name
                        )

                        if ($PSBoundParameters.ContainsKey('RecoveryModel'))
                        {
                            $sqlDatabaseObjectToCreate.RecoveryModel = $RecoveryModel
                        }

                        $sqlDatabaseObjectToCreate.Collation = $Collation
                        $sqlDatabaseObjectToCreate.CompatibilityLevel = $CompatibilityLevel
                        $sqlDatabaseObjectToCreate.Create()
                    }
                }
                catch
                {
                    $errorMessage = $script:localizedData.FailedToCreateDatabase -f $Name
                    New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
                }
            }
        }
        else
        {
            try
            {
                $sqlDatabaseObjectToDrop = $sqlServerObject.Databases[$Name]
                if ($sqlDatabaseObjectToDrop)
                {
                    Write-Verbose -Message (
                        $script:localizedData.DropDatabase -f $Name
                    )

                    $sqlDatabaseObjectToDrop.Drop()
                }
            }
            catch
            {
                $errorMessage = $script:localizedData.FailedToDropDatabase -f $Name
                New-InvalidOperationException -Message $errorMessage -ErrorRecord $_
            }
        }
    }
}

<#
    .SYNOPSIS
    This function tests if the sql database is already created or dropped.

    .PARAMETER Ensure
    When set to 'Present', the database will be created.
    When set to 'Absent', the database will be dropped.

    .PARAMETER Name
    The name of database to be created or dropped.

    .PARAMETER ServerName
    The host name of the SQL Server to be configured.

    .PARAMETER InstanceName
    The name of the SQL instance to be configured.

    .PARAMETER Collation
    The name of the SQL collation to use for the new database.
    Defaults to server collation.

    .PARAMETER CompatibilityLevel
    The version of the SQL compatibility level to use for the new database.
    Defaults to server version.

    .PARAMETER RecoveryModel
    The recovery model to be used for the new database.
    Defaults to Full.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Ensure = 'Present',

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ServerName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $InstanceName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Collation,

        [Parameter()]
        [ValidateSet('Version80', 'Version90', 'Version100', 'Version110', 'Version120', 'Version130', 'Version140', 'Version150')]
        [System.String]
        $CompatibilityLevel,

        [Parameter()]
        [ValidateSet('Simple', 'Full', 'BulkLogged')]
        [System.String]
        $RecoveryModel
    )

    Write-Verbose -Message (
        $script:localizedData.TestingConfiguration -f $Name, $InstanceName
    )

    $getTargetResourceResult = Get-TargetResource @PSBoundParameters
    $isDatabaseInDesiredState = $true

    switch ($Ensure)
    {
        'Absent'
        {
            if ($getTargetResourceResult.Ensure -ne 'Absent')
            {
                Write-Verbose -Message (
                    $script:localizedData.NotInDesiredStateAbsent -f $Name
                )

                $isDatabaseInDesiredState = $false
            }
        }

        'Present'
        {
            if ($getTargetResourceResult.Ensure -ne 'Present')
            {
                Write-Verbose -Message (
                    $script:localizedData.NotInDesiredStatePresent -f $Name
                )

                $isDatabaseInDesiredState = $false
            }
            else
            {
                if ($PSBoundParameters.ContainsKey('Collation') -and $getTargetResourceResult.Collation -ne $Collation)
                {
                    Write-Verbose -Message (
                        $script:localizedData.CollationWrong -f $Name, $getTargetResourceResult.Collation, $Collation
                    )

                    $isDatabaseInDesiredState = $false
                }

                if ($PSBoundParameters.ContainsKey('CompatibilityLevel') -and $getTargetResourceResult.CompatibilityLevel -ne $CompatibilityLevel)
                {
                    Write-Verbose -Message (
                        $script:localizedData.CompatibilityLevelWrong -f $Name, $getTargetResourceResult.CompatibilityLevel, $CompatibilityLevel
                    )

                    $isDatabaseInDesiredState = $false
                }

                if ($PSBoundParameters.ContainsKey('RecoveryModel') -and $getTargetResourceResult.RecoveryModel -ne $RecoveryModel)
                {
                    Write-Verbose -Message (
                        $script:localizedData.RecoveryModelWrong -f $Name, $getTargetResourceResult.RecoveryModel, $RecoveryModel
                    )

                    $isDatabaseInDesiredState = $false
                }
            }
        }
    }

    return $isDatabaseInDesiredState
}

Export-ModuleMember -Function *-TargetResource
