﻿<#
    DESCRIPTION: 
        Check to see if any non standard scheduled tasks exist on  the server (Any application specific scheduled tasks should be documented with a designated contact point specified).
        This check automatically ignores any Microsoft labelled specific tasks.
   
    REQUIRED-INPUTS:
        IgnoreTheseScheduledTasks - List of scheduled tasks that can be ignored

    DEFAULT-VALUES:
        IgnoreTheseScheduledTasks = ('SQM data sender', 'SystemSoundsService', 'StartComponentCleanup', 'Automatic-Workplace-Join', 'ReplaceOMCert', 'Optimize Start Menu Cache Files')

    DEFAULT-STATE:
        Enabled

    RESULTS:
        PASS:
            No additional scheduled tasks found
        WARNING:
            Additional scheduled tasks found - make sure these are documented
        FAIL:
        MANUAL:
        NA:

    APPLIES:
        All Servers

    REQUIRED-FUNCTIONS:
        None
#>

Function c-sys-09-scheduled-tasks
{
    Param ( [string]$serverName, [string]$resultPath )

    $serverName    = $serverName.Replace('[0]', '')
    $resultPath    = $resultPath.Replace('[0]', '')
    $result        = newResult
    $result.server = $serverName
    $result.name   = $script:lang['Name']
    $result.check  = 'c-sys-09-scheduled-tasks'

    #... CHECK STARTS HERE ...#

    Try
    {
        [string]$query = 'SELECT Caption FROM Win32_OperatingSystem'
        [string]$check = Get-WmiObject -ComputerName $serverName -Query $query -Namespace ROOT\Cimv2 | Select-Object -ExpandProperty Caption

        If ($check -notlike '*2003*')
        {
            $schedule = New-Object -ComObject('Schedule.Service')
            $schedule.Connect($serverName) 
            $tasks = Get-Tasks($schedule.GetFolder('\'))
        }
        Else
        {
            # Windows 2003 Servers
            $result.result  = $script:lang['Warning']
            $result.message = 'Operating system not supported by check'
            $result.data    = ''
            Return $result
        }
    }
    Catch
    {
        $result.result  = $script:lang['Error']
        $result.message = $script:lang['Script-Error']
        $result.data    = $_.Exception.Message
        Return $result
    }

    $tasksOut = ''
    $tasks | ForEach {
        [xml]   $xml    = $_.Xml
        [string]$author = $xml.Task.RegistrationInfo.Author
        If (($Author -notlike '*Microsoft*') -and ($Author -notlike '*SystemRoot*'))
        {
            $ns = New-Object 'System.Xml.XmlNamespaceManager'($xml.NameTable); $ns.AddNamespace("ns", $xml.DocumentElement.NamespaceURI)
            [string]$runAs = $xml.SelectSingleNode('//ns:Principal[@id="Author"]', $ns).UserID

            If ([string]::IsNullOrEmpty($runAs) -eq $true) { $runAs = $author   }
            If ([string]::IsNullOrEmpty($runAs) -eq $true) { $runAs = 'Unknown' }

            If (($_.Name).Contains('-S-1-5-21-')) { [string]$NewName = $($_.Name).Split('-')[0] } Else { [string]$NewName = $_.Name }
            [string]$tasksOut += '{0} ({1}),#' -f $_.Name, $runAs
        }
    }

    If ($tasksOut -eq '')
    {
        $result.result  = $script:lang['Pass']
        $result.message = 'No additional scheduled tasks found'
    }
    Else
    {
        $result.result  = $script:lang['Warning']
        $result.message = 'Additional scheduled tasks found - make sure these are documented'
        $result.data    = $tasksOut
    }
        
    Return $result
}

# Checks all task subfolders, not just root...
Function Get-Tasks
{
    Param ( [Object]$taskFolder )
    $tasks = $taskFolder.GetTasks(0)
    $tasks | ForEach-Object { $_ }
    Try {
        $taskFolders = $taskFolder.GetFolders(0)
        $taskFolders | ForEach-Object { Get-Tasks $_ $true } }
    Catch { }
}