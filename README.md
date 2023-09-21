# Viper - PowerShell Azure Active Directory Audit Log Collector

## Description

Viper is a forensic audit tool for Azure Active Directory, designed to gather logs farther back than the AzureAD Sign-In logs will show. Viper leverages the power of Search-UnifiedAuditLog command to extract login data from your Azure Active Directory tenant. The tool captures this information into a readable CSV format for easy inspection and analysis.

## Features

* Retrieves login data from the past 90 days (or a user-specified period)
* Connects to Exchange Online to fetch audit logs
* Converts raw data into readable CSV format
* Dynamically names output files based on the tenant's display name

## Pre-requisites

* PowerShell 5.1 or later
* Exchange Online Management Module
* AzureAD PowerShell Module

Please note that to run this script, you need to have the necessary permissions in your Azure tenant to execute the Get-AzureADTenantDetail and Search-UnifiedAuditLog cmdlets.

## Usage

1. Clone this repository to your local system
2. Navigate to the repository directory
3. Run the Viper.ps1 PowerShell script
4. When prompted, enter:
    * The start date for audit logs as a number of days ago (0-90)
    * The directory to save the audit logs

## Output

Viper produces two types of output CSV files:

1. AuditLogs_<TenantName>.csv: Contains the raw audit logs
2. Converted_AuditLogs_<TenantName>.csv: Contains the unpacked and formatted audit logs for easy analysis

## License

Viper is an open-source tool under the MIT License.

## Contributing

Contributions, issues, and feature requests are welcome! For major changes, please open an issue first to discuss what you would like to change.
