$ResourceGroupName = "rg-avd"
$HostPoolName = "hp-avd"
$ThrottleLimit = "5" # Total machines being processed in parallel. Make sure you'll keep enough resources available in your environment to run this script.

# Ensure the required modules are imported
Import-Module Az.DesktopVirtualization
Import-Module Az.Compute

# Get all session host VMs in the host pool
$sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName

$sessionHosts | ForEach-Object -Parallel {
    # Import required modules in parallel runspaces (defensive, but can be omitted if all runspaces have modules loaded)
    Import-Module Az.DesktopVirtualization -ErrorAction SilentlyContinue
    Import-Module Az.Compute -ErrorAction SilentlyContinue

    $vmResourceId = $_.ResourceId
    $vm = Get-AzVM -ResourceId $vmResourceId

    # Clean session host name (extract after last '/')
    $sessionHostName = ($_.ResourceId -split '/')[-1]
    Write-Host "Processing session host: $sessionHostName"

    # Check VM uptime
    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    if ($vmStatus.Statuses[1].Code -eq "PowerState/running") {
        $bootTime = $vmStatus.Disks[0].Statuses[0].Time
        $uptime = (Get-Date) - $bootTime
        Write-Host "VM $($vm.Name) boot time: $bootTime, uptime: $([math]::Round($uptime.TotalHours,2)) hours"
        # MODIFY YOUR MAXIMUM UPTIME THRESHOLD
        if ($uptime.TotalHours -lt 23) {
            Write-Host "Skipping $($vm.Name): uptime less than maximum allowed hours."
            return
        }
    } else {
        Write-Host "Skipping $($vm.Name): not running."
        return
    }

    Write-Host "VM $($vm.Name) has uptime $([math]::Round($uptime.TotalHours,2)) hours. Processing..."

    # Add tag Exclude tag'
    $tags = $vm.Tags
    $tags["ExcludeFromScaling"] = "true" # Modify your tag name as needed
    $null = Set-AzResource -ResourceId $vmResourceId -Tag $tags -Force
    Write-Host "Exclude from Scaling tag added to $($vm.Name)"

    # Set VM in drain mode
    $null = Update-AzWvdSessionHost -ResourceGroupName $using:ResourceGroupName -HostPoolName $using:HostPoolName -Name $sessionHostName -AllowNewSession:$false
    Write-Host "Set $sessionHostName to drain mode"

    # Wait for 0 active sessions
    do {
        $currentHost = Get-AzWvdSessionHost -ResourceGroupName $using:ResourceGroupName -HostPoolName $using:HostPoolName -Name $sessionHostName
        $activeSessions = $currentHost.Session
        Write-Host "Waiting for sessions to drain from $sessionHostName. Active sessions: $activeSessions"
        Start-Sleep -Seconds 30
    } while ($activeSessions -gt 0)
    Write-Host "No active sessions on $sessionHostName"

    # Shutdown VM (or reboot)
    $null = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
    Write-Host "Shutdown initiated for $($vm.Name)"

    # Verify VM is stopped (deallocated)
    do {
        Start-Sleep -Seconds 15
        $status = (Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status).Statuses | Where-Object { $_.Code -like "PowerState*" }
        $powerState = $status.DisplayStatus
        Write-Host "Waiting for VM $($vm.Name) to stop. Current state: $powerState"
    } while ($powerState -ne "VM deallocated")
    Write-Host "VM $($vm.Name) is now deallocated."

    # Remove Exclude tag
    $tags.Remove("ExcludeFromScaling") | Out-Null
    $null = Set-AzResource -ResourceId $vmResourceId -Tag $tags -Force
    Write-Host "Tag removed from $($vm.Name)"

    Write-Host "Completed cycle for $($vm.Name)"
} -ThrottleLimit $ThrottleLimit
