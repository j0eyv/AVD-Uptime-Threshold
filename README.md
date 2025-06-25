# AVD Uptime Threshold

This PowerShell script automates the maintenance cycle for Azure Virtual Desktop (AVD) session host virtual machines (VMs) in a specified host pool. It is designed to ensure session hosts are regularly rebooted after exceeding a defined uptime threshold, helping to maintain performance and stability.

## Features

- **Parallel Processing:** Processes all session hosts in the host pool concurrently for efficiency.
- **Uptime Check:** Only targets VMs that have been running longer than a configurable threshold (default: 23 hours).
- **Tagging:** Temporarily tags VMs as `ExcludeFromScaling=true` to exclude them from scaling operations.
- **Drain Mode:** Puts session hosts into drain mode to prevent new user sessions.
- **Session Drain Wait:** Waits until all active user sessions have logged off before proceeding.
- **Graceful Shutdown:** Shuts down (deallocates) the VM after sessions are drained.
- **Tag Cleanup:** Removes the `ExcludeFromScaling` tag after the cycle is complete.
- **Logging:** Provides detailed output for each step of the process.

## Usage

1. **Configure Variables:**  
   Edit the script to set your Azure resource group, host pool name, and location.

2. **Exclude tag:**
   Edit the ExcludeFromScaling tag with your required exclusion tag. This one can be found in your scaling plan.
   
3. **Run the Script:**  
   Run the script in a PowerShell session that has the required Azure permissions. For better automation, it's recommended to integrate this into a pipeline.

   ```powershell
   .\SessionHostRebootCycle.ps1
   ```

## Prerequisites

- Azure PowerShell modules:  
  - `Az.DesktopVirtualization`
  - `Az.Compute`
- Sufficient permissions to manage VMs and session hosts in the specified resource group and host pool.

## Customization

- **Uptime Threshold:**  
  Change the value in the uptime check section to adjust how long a VM must be running before it is cycled.

## Disclaimer

Use this script at your own risk. Test thoroughly in a non-production environment before deploying to
