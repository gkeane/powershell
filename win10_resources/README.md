# Windows 10 EOL Migration Project - KACE SQL Scripts

This repository contains SQL scripts for the Windows 10 End of Life (EOL) migration project, designed to be used with the KACE Systems Management Appliance (SMA).

## Purpose

These scripts help identify and categorize Windows 10 systems in your environment to facilitate the migration process before Windows 10 reaches end of life.

## Scripts

### win10_green.sql
This script identifies Windows 10 systems that are capable of being upgraded. It returns:
- System name
- System description
- IP address
- MAC address
- System ID

The query specifically looks for:
- Systems running Windows 10
- Systems marked as "Capable" in the OSUPGRADE_READINESS table

### win10_red.sql
This script is currently empty and can be used to identify systems that may have compatibility issues or require special attention during the migration process.

## Usage

1. Log into your KACE SMA web interface
2. Navigate to the SQL Query tool
3. Copy and paste the desired script
4. Execute the query to get the results

## Requirements

- KACE Systems Management Appliance (SMA)
- Appropriate permissions to run SQL queries
- Access to the MACHINE and OSUPGRADE_READINESS tables

## Contributing

Feel free to contribute additional scripts or improvements to existing ones. Please ensure that any new scripts are properly documented and tested before submitting.

## Note

These scripts are specifically designed for the Windows 10 EOL migration project and should be used in conjunction with your organization's migration strategy. 