# Windows 10 EOL Migration Project - KACE Scripts

This repository contains scripts for the Windows 10 End of Life (EOL) migration project, designed to be used with the KACE Systems Management Appliance (SMA) and related tools.

## Purpose

These scripts help identify and categorize Windows 10 systems in your environment to facilitate the migration process before Windows 10 reaches end of life. They also include maintenance and diagnostic tools to ensure system health during the migration process.

## Scripts

### SQL Queries

#### win10_green.sql
This script identifies Windows 10 systems that are capable of being upgraded. It returns:
- System name
- System description
- IP address
- MAC address
- System ID

The query specifically looks for:
- Systems running Windows 10
- Systems marked as "Capable" in the OSUPGRADE_READINESS table

#### win10_red.sql
This script identifies Windows 10 systems that are NOT capable of being upgraded. It returns:
- System name
- System description
- IP address
- MAC address
- System ID

The query specifically looks for:
- Systems running Windows 10
- Systems NOT marked as "Capable" in the OSUPGRADE_READINESS table

### Batch Scripts

#### sfc_scannow.bat
This batch script performs a System File Checker (SFC) scan on Windows systems and logs the results. Key features:
- Automatically detects system architecture (32-bit vs 64-bit)
- Runs SFC scan using the appropriate method for the system
- Implements a 30-day cooldown period between scans
- Logs results to both local and network locations
- Uses PowerShell for timestamp generation and file age checking

Log locations:
- Local: `C:\ProgramData\Quest\KACE\user\sfcscan.log`
- Network: `\\chs-deploy\kacereport\sfc\[COMPUTERNAME]_sfc_[TIMESTAMP].log`

The script includes:
- Timestamp generation for unique log files
- Automatic bitness detection and appropriate SFC execution
- Error handling for network share access
- Detailed logging of all operations
- 30-day cooldown period to prevent excessive scanning

## Usage

### SQL Queries
1. Log into your KACE SMA web interface
2. Navigate to the SQL Query tool
3. Copy and paste the desired script
4. Execute the query to get the results

### Batch Scripts
1. Deploy the script through KACE SMA or run manually
2. Script will automatically:
   - Check if a scan was performed in the last 30 days
   - Run SFC scan using the appropriate method for the system architecture
   - Log results locally and to network share
   - Handle both 32-bit and 64-bit systems appropriately

## Requirements

- KACE Systems Management Appliance (SMA)
- Appropriate permissions to run SQL queries
- Access to the MACHINE and OSUPGRADE_READINESS tables
- Network access to `\\chs-deploy\kacereport\sfc` for log storage
- Windows system with PowerShell available
- Write access to `C:\ProgramData\Quest\KACE\user`

## Contributing

Feel free to contribute additional scripts or improvements to existing ones. Please ensure that any new scripts are properly documented and tested before submitting.

## Note

These scripts are specifically designed for the Windows 10 EOL migration project and should be used in conjunction with your organization's migration strategy. 