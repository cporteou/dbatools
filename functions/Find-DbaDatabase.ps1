#ValidationTags#Messaging#
function Find-DbaDatabase {
    <#
    .SYNOPSIS
        Find database/s on multiple servers that match criteria you input

    .DESCRIPTION
        Allows you to search SQL Server instances for database that have either the same name, owner or service broker guid.

        There a several reasons for the service broker guid not matching on a restored database primarily using alter database new broker. or turn off broker to return a guid of 0000-0000-0000-0000.

    .PARAMETER SqlInstance
        The target SQL Server instance or instances.

    .PARAMETER SqlCredential
        Credential object used to connect to the SQL Server as a different user

    .PARAMETER Property
        What you would like to search on. Either Database Name, Owner, or Service Broker GUID. Database name is the default.

    .PARAMETER Pattern
        Value that is searched for. This is a regular expression match but you can just use a plain ol string like 'dbareports'

    .PARAMETER Exact
        Search for an exact match instead of a pattern

    .PARAMETER Detailed
        Output all properties, will be depreciated in 1.0.0 release.

    .PARAMETER EnableException
        By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
        This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
        Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

    .NOTES
        Tags: Database
        Author: Stephen Bennett, https://sqlnotesfromtheunderground.wordpress.com/

        Website: https://dbatools.io
        Copyright: (c) 2018 by dbatools, licensed under MIT
        License: MIT https://opensource.org/licenses/MIT

    .LINK
        https://dbatools.io/Find-DbaDatabase

    .EXAMPLE
        PS C:\> Find-DbaDatabase -SqlInstance "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Pattern Report

        Returns all database from the SqlInstances that have a database with Report in the name

    .EXAMPLE
        PS C:\> Find-DbaDatabase -SqlInstance "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Pattern TestDB -Exact | Select-Object *

        Returns all database from the SqlInstances that have a database named TestDB with a detailed output.

    .EXAMPLE
        PS C:\> Find-DbaDatabase -SqlInstance "DEV01", "DEV02", "UAT01", "UAT02", "PROD01", "PROD02" -Property ServiceBrokerGuid -Pattern '-faeb-495a-9898-f25a782835f5' | Select-Object *

        Returns all database from the SqlInstances that have the same Service Broker GUID with a detailed output

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias("ServerInstance", "SqlServer")]
        [DbaInstanceParameter[]]$SqlInstance,
        [Alias("Credential")]
        [PSCredential]$SqlCredential,
        [ValidateSet('Name', 'ServiceBrokerGuid', 'Owner')]
        [string]$Property = 'Name',
        [parameter(Mandatory)]
        [string]$Pattern,
        [switch]$Exact,
        [switch]$Detailed,
        [Alias('Silent')]
        [switch]$EnableException
    )
    begin {
        Test-DbaDeprecation -DeprecatedOn 1.0.0 -Parameter Detailed
    }
    process {
        foreach ($instance in $SqlInstance) {
            try {
                $server = Connect-SqlInstance -SqlInstance $instance -SqlCredential $SqlCredential
            } catch {
                Stop-Function -Message "Failure" -Category ConnectionError -ErrorRecord $_ -Target $instance -Continue
            }

            if ($exact -eq $true) {
                $dbs = $server.Databases | Where-Object IsAccessible | Where-Object { $_.$property -eq $pattern }
            } else {
                try {
                    $dbs = $server.Databases | Where-Object IsAccessible | Where-Object { $_.$property.ToString() -match $pattern }
                } catch {
                    # they probably put asterisks thinking it's a like
                    $Pattern = $Pattern -replace '\*', ''
                    $Pattern = $Pattern -replace '\%', ''
                    $dbs = $server.Databases | Where-Object { $_.$property.ToString() -match $pattern }
                }
            }

            foreach ($db in $dbs) {

                $extendedproperties = @()
                foreach ($xp in $db.ExtendedProperties) {
                    $extendedproperties += [PSCustomObject]@{
                        Name  = $db.ExtendedProperties[$xp.Name].Name
                        Value = $db.ExtendedProperties[$xp.Name].Value
                    }
                }

                if ($extendedproperties.count -eq 0) { $extendedproperties = 0 }

                [PSCustomObject]@{
                    ComputerName       = $server.ComputerName
                    InstanceName       = $server.ServiceName
                    SqlInstance        = $server.Name
                    Name               = $db.Name
                    Size               = [dbasize]($db.Size * 1024 * 1024)
                    Owner              = $db.Owner
                    CreateDate         = $db.CreateDate
                    ServiceBrokerGuid  = $db.ServiceBrokerGuid
                    Tables             = ($db.Tables | Where-Object { $_.IsSystemObject -eq $false }).Count
                    StoredProcedures   = ($db.StoredProcedures | Where-Object { $_.IsSystemObject -eq $false }).Count
                    Views              = ($db.Views | Where-Object { $_.IsSystemObject -eq $false }).Count
                    ExtendedProperties = $extendedproperties
                }
            }
        }
    }
}