# KACE Scripts Documentation

This directory contains various PowerShell and SQL scripts used for KACE system management and monitoring.

## Scripts Overview

### PowerShell Scripts

- **b64_encode.ps1**
  - Encodes files to base64 format
  - Creates a new file with "_b64" suffix

- **battery_health.ps1**
  - Checks battery health on laptops
  - Reports design capacity, full charge capacity, and health percentage

- **CI-CVE-2024_20666.txt**
  - Custom inventory rule to check WinRE compatibility

- **CI-CVE_2022-0001.ps1**
  - Checks registry values for CPU vulnerability mitigations
  - Verifies Hyperthreading and Hyper-V settings

- **CI-lastuptodate.ps1**
  - Monitors OneDrive sync status
  - Tracks last successful sync date

- **CI-quotaused.ps1**
  - Retrieves OneDrive quota usage information

- **ci-getwinupdatename.ps1**
  - Installs and uses PSWindowsUpdate module
  - Gets latest Windows cumulative update name

- **CI-java_installations.ps1**
  - Reads Java installation logs
  - Reports installed Java versions

- **isadmin.ps1**
  - Checks if current user has administrator privileges
  - Writes result to admin_check.txt

- **java_location.ps1**
  - Scans system for Java executable locations
  - Logs detailed Java installation information

- **java_usage.ps1** and **java_usage-CANR-gklaptop2.ps1**
  - Tracks Java application usage
  - Creates usage logs and monitoring files

- **kace_chromium_remediation.ps1**
  - Removes OneLaunch browser and related components
  - Cleans up registry entries and scheduled tasks

- **kace_java_rollout.sql**
  - SQL query for managing Java deployment
  - Targets machines based on naming convention

- **kace_onedrive_lsync.ps1**
  - Monitors OneDrive "Up to date" status
  - Maintains sync history log

- **kace_onsync.ps1**
  - Comprehensive OneDrive sync monitoring
  - Creates multiple log files for sync status, quota, and path matching

- **kace_query_machines.ps1**
  - Queries Active Directory for inactive computers
  - Identifies machines inactive for 90+ days

- **kace_reboot.ps1**
  - Displays reboot notification balloon
  - Provides interactive reboot prompt

- **kace_secboot.ps1**
  - Manages Secure Boot updates for CVE-2023-24932
  - Verifies and deploys SKUSiPolicy.P7b

- **kace_toast_reboot.ps1**
  - Shows a Windows Forms reboot prompt
  - Repeats prompt every hour until action taken

### SQL Scripts

- **kace_java_rollout.sql**
  - Manages phased deployment of Java updates
  - Uses machine naming convention for rollout scheduling

### Text Configuration Files

- **ci-recovery_part_size.txt**
  - PowerShell command to get recovery partition size
  - Used for custom inventory

### Batch Scripts

- **onedrive.bat**
  - Simple wrapper script to execute kace_onsync.ps1
  - Launches PowerShell with proper execution policy
  - Used by KACE to run OneDrive sync monitoring
  - Creates status files:
    - odrive.txt (all OneDrive instances)
    - odrive2.txt (current user's OneDrive)
    - odrive3.txt (sync history)
    - odrive_match.txt (path match status)
    - odrive_lastsync.txt (last successful sync timestamp)

All scripts are designed to work with KACE systems management and typically write their output to the `C:\ProgramData\Quest\KACE\user\` directory. 