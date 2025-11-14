@{
    RootModule = 'DnsZoneRecords.psm1'
    ModuleVersion = '1.0.0'
    RequiredModules = @('DnsServer')
    Author = 'Elligion'
    CompanyName = ''
    Copyright = '(c) 2025. All rights reserved.'
    Description = 'Модуль для поиска записей DNS'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Get-DnsZoneRecords')
    VariablesToExport = ''
    PrivateData = @{
        PSData = @{
            Tags = @('DNS', 'Network')
        }
    }
}