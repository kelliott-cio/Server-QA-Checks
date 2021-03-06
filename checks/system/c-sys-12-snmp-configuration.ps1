﻿<#
    DESCRIPTION: 
        Check if SNMP role is install on the server.  If so, ensure the SNMP community strings follow the secure password policy.

    REQUIRED-INPUTS:
        None

    DEFAULT-VALUES:
        None

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            SNMP Service installed, but disabled
        WARNING:
        FAIL:
            SNMP Service installed, no communities configured
        MANUAL:
            SNMP Service installed, communities listed
        NA:
            SNMP Service not installed

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-12-snmp-configuration
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-12-snmp-configuration'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT DisplayName, StartMode FROM Win32_Service WHERE DisplayName="SNMP Service"'
        [object]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object DisplayName, StartMode
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    If ([string]::IsNullOrEmpty($check) -eq $false)
    {
        Try
        {
            $reg    = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine', $serverName)
            $regKey = $reg.OpenSubKey('SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities')
            If ($regKey) { [array]$keyVal = $regKey.GetValueNames() }
            Try { $regKey.Close() } Catch { }
            $reg.Close()
        }
        Catch
        {
            $result.result  = $script:lang['Error']
            $result.message = $script:lang['Script-Error']
            $result.data    = $_.Exception.Message
            Return $result
        }

        If (($regKey) -and ($keyVal.Count -gt 0))
        {
            $result.result  = $script:lang['Manual']
            $result.message = 'SNMP Service installed, communities listed'

            ForEach ($key In $keyVal)
            {
                $keyVal_ = $regKey.GetValue($key)
                If ($keyVal_ -eq '4') { $result.data += $key + ' (readonly),#'  }
                If ($keyVal_ -eq '8') { $result.data += $key + ' (readwrite),#' }
            }
        }
        Else
        {
            If ($check.StartMode -eq 'Disabled')
            {
                $result.result  = $script:lang['Pass']
                $result.message = 'SNMP Service installed, but disabled'
            }
            Else
            {
                $result.result  = $script:lang['Warning']
                $result.message = 'SNMP Service installed, no communities configured'
            }
        }
    }
    Else
    {
        $result.result  = $script:lang['Not-Applicable']
        $result.message = 'SNMP Service not installed'
    }

    Return $result
}