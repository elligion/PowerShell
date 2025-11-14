# Ваш модуль DnsModule.psm1

# Внутренняя переменная модуля для кеширования
$Script:SORT_LIST = $null

function Get-DnsZoneRecords {
<#
.SYNOPSIS
    Поиск и анализ DNS записей в указанных доменных зонах

.DESCRIPTION
    Модуль предоставляет функционал для поиска и анализа DNS записей (A, CNAME, MX, TXT и др.)
    в одной или нескольких доменных зонах. Поддерживает кеширование результатов для повышения
    производительности при повторных запросах.

    ТРЕБОВАНИЯ:
    - Модуль DnsServer версии 2.0.0.0 или выше
    - Права на чтение DNS зон
    - Доступ к DNS серверу

    ВЕРСИЯ: 1.0.0

.PARAMETER Name
    Имя хоста для поиска (без указания домена). Например: "server1" вместо "server1.domain.com"

.PARAMETER All
    Выводит все DNS записи без фильтрации и дополнительного форматирования

.PARAMETER Zones
    Список доменных зон для поиска. Если не указан, используется значение переменной 
    окружения $env:GetDNSZonesRedcords или запрашивается у пользователя

.PARAMETER DNSComputerName
    DNS сервер для выполнения запросов. Приоритет определения:
    1. Указанное значение параметра
    2. Домен текущего компьютера (Get-ComputerInfo).CsDomain
    3. Локальный хост (localhost)

.PARAMETER Refresh
    Принудительное обновление кеша DNS записей

.PARAMETER ClearDnsCache
    Полная очистка кешированных DNS записей

.PARAMETER DnsCacheStatus
    Отображение текущего статуса кеша (количество записей и зон)

.EXAMPLE
    Get-DnsZoneRecords example
    # Базовый поиск записи "example" во всех зонах из переменной окружения

.EXAMPLE
    Get-DnsZoneRecords -All
    # Вывод всех DNS записей для анализа или дальнейшей обработки

.EXAMPLE
    Get-DnsZoneRecords -Name example -Refresh
    # Поиск записи "example" с предварительным обновлением кеша

.EXAMPLE
    Get-DnsZoneRecords -Name example -Zones domain.com,develop.domain.com -DNSComputerName domain.com -Verbose
    # Расширенный поиск с указанием зон, DNS сервера и подробным выводом

.EXAMPLE
    Get-DnsZoneRecords -DnsCacheStatus
    # Проверка текущего состояния кеша

.EXAMPLE
    Get-DnsZoneRecords -ClearDnsCache
    # Очистка кеша DNS записей

.NOTES
    АВТОР МОДУЛЯ: M.E. Viktorov aka Elligion
    ВДОХНОВЛЕНО: оригинальным скриптом DNSZoneRecord.ps1 (https://github.com/lawson2305/Powershell)
        
    Отличия от оригинальной реализации:
    - Полная переработка в формате модуля PowerShell
    - Добавлена система кеширования записей
    - Расширенные параметры поиска и фильтрации
    - Улучшенная обработка ошибок
    - Поддержка автоматического определения DNS сервера
#>
    
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][string]$Name,
        
        [switch]$All,

        [string[]]$Zones,
        
        [string]$IP = $null,
        
        [string]$DnsComputerName,
        
        [switch]$Refresh,
        
        [switch]$ClearDnsCache,
        
        [switch]$DnsCacheStatus
    )
    
    # Обработка специальных флагов
    if ($ClearDnsCache) {
        $Script:SORT_LIST = $null
        Write-Host "Кеш DNS записей очищен" -ForegroundColor Green
        return
    }
    
    if ($DnsCacheStatus) {
        if ($null -eq $Script:SORT_LIST) {
            Write-Host "Кеш пуст" -ForegroundColor Yellow
        } else {
            $zoneCount = ($Script:SORT_LIST | Group-Object ZoneName).Count
            Write-Host "В кеше содержится $($Script:SORT_LIST.Count) записей из $zoneCount зон" -ForegroundColor Green
        }
        return
    }
    
    # Проверка обязательных параметров
    if (-not $Name -and -not $IP -and -not $All -and -not $Refresh) {
        throw "Необходимо выбрать обязательную опцию: имя хоста (-Name), либо IP адрес (-IP), либо вывод всех записей (-All)"
    }
    
    
    # Обновление кеша при необходимости
    if ($Refresh -or ($null -eq $Script:SORT_LIST)) {
        Write-Verbose "Начато обновление кеша DNS записей"

        # Определяем DNS сервер для запросов        
        Write-Verbose "Определяем DNS сервер для запросов"
        $dnsServer = $null
        if ($DNSComputerName) {
            # 1. Приоритет: пользовательский ввод
            $dnsServer = $ComputerName
            Write-Verbose "Используется указанный DNS сервер: $dnsServer"
        } else {
            try {
                # 2. Попытка получить домен из ComputerInfo
                $csDomain = (Get-ComputerInfo).CsDomain
                if (-not [string]::IsNullOrEmpty($csDomain)) {
                    $dnsServer = $csDomain
                    Write-Verbose "Используется DNS сервер из домена: $dnsServer"
                } else {
                    # 3. Fallback: локальный хост
                    $dnsServer = $env:COMPUTERNAME
                    Write-Verbose "Используется локальный хост как DNS сервер: $dnsServer"
                }
            }
            catch {
                # 3. Fallback: локальный хост при ошибке
                $dnsServer = $env:COMPUTERNAME
                Write-Verbose "Ошибка получения домена, используется локальный хост: $dnsServer"
                Write-Verbose "Ошибка: $($_.Exception.Message)"
            }
        }

        # Получение списка зон
        if (-not $Zones) {
            if ($env:GetDNSZonesRedcords) {
                $Zones = $env:GetDNSZonesRedcords -split ',' | ForEach-Object { $_.Trim() }
                Write-Verbose "Используются зоны из переменной окружения: $($Zones -join ', ')"
            } else {
                $inputZones = Read-Host "Введите доменные зоны через запятую"
                $Zones = $inputZones -split ',' | ForEach-Object { $_.Trim() }
                if (-not $Zones) {
                    throw "Не указаны доменные зоны для поиска"
                }
            }
        }
        
        Write-Verbose "Обновление кеша DNS записей для зон: $($Zones -join ', ') с сервера: $dnsServer"
        
        # Проверка наличия модуля DnsServer
        $dnsModule = Get-Module -Name DnsServer -ListAvailable
        if (-not $dnsModule) {
            throw "Модуль DnsServer не установлен. Установите его с помощью: Install-WindowsFeature -Name DNS -IncludeManagementTools"
        }
        
        # Проверка версии модуля (2.0.0.0 или выше)
        $requiredVersion = [version]"2.0.0.0"
        $moduleVersion = $dnsModule[0].Version
        
        if ($moduleVersion -lt $requiredVersion) {
            throw "Требуется модуль DnsServer версии $requiredVersion или выше. Установленная версия: $moduleVersion"
        }
        
        Write-Verbose "Используется модуль DnsServer версии $moduleVersion"
        
        # Импортируем модуль, если еще не импортирован
        # Import-Module DnsServer -Force -ErrorAction Stop
        
        $allRecords = @()
        
        foreach ($zone in $Zones) {
            try {
                Write-Verbose "Запрос записей для зоны: $zone с сервера $dnsServer"
                
                # Ваша логика получения DNS записей с улучшенной обработкой ошибок
                $zoneRecords = $zone | ForEach-Object {
                    $zoneName = $_
                    try {
                        $getDnsParams = @{
                            ZoneName = $zoneName
                            ErrorAction = 'Stop'
                        }
                        
                        # Добавляем ComputerName только если он указан
                        if ($dnsServer) {
                            $getDnsParams.ComputerName = $dnsServer
                        }
                        
                        Get-DnsServerResourceRecord @getDnsParams |
                        Select-Object hostname, recordType, 
                            @{n='ZoneName';Expression={$zoneName}},
                            @{n='Data';e={
                                $selectedObject = $_
                                switch ($selectedObject.RecordType) {
                                    'A'     {$selectedObject.RecordData.IPv4Address}
                                    'CNAME' {$selectedObject.RecordData.HostnameAlias}
                                    'NS'    {$selectedObject.RecordData.NameServer}
                                    'SOA'   {$selectedObject.RecordData.PrimaryServer}
                                    'SRV'   {$selectedObject.RecordData.DomainName}
                                    'PTR'   {$selectedObject.RecordData.PtrDomainName}
                                    'MX'    {$selectedObject.RecordData.MailExchange}
                                    'AAAA'  {$selectedObject.RecordData.IPv6Address}
                                    'TXT'   {$selectedObject.RecordData.DescriptiveText}
                                    default {$selectedObject.RecordData.ToString()}
                                }
                            }}
                    }
                    catch {
                        Write-Warning "Ошибка при получении записей для зоны $zoneName с сервера $dnsServer : $($_.Exception.Message)"
                        return $null
                    }
                } | Where-Object { $null -ne $_ }
                
                if ($zoneRecords) {
                    $allRecords += $zoneRecords
                    Write-Verbose "Получено $($zoneRecords.Count) записей для зоны $zone"
                }
            }
            catch {
                Write-Warning "Не удалось получить записи для зоны $zone : $($_.Exception.Message)"
            }
        }
        
        $Script:SORT_LIST = $allRecords
        Write-Verbose "Кеш обновлен. Загружено $($allRecords.Count) записей из $($Zones.Count) зон"
    }
    
    function GetDnsRecordsByIP {
        param (
            [string]$IP
        )
        Write-Verbose "Ищем записи по $IP"
        $result = $Script:SORT_LIST | Where-Object{$_.data -like $IP}
        return $result
    }
    function GetDNSCNameHit {
        param (
            $TargetDNSObject
        )
        Write-Verbose "Ищем записи для $TargetDNSObject" 
        $result = $Script:SORT_LIST | Where-Object{$_.data -like $TargetDNSObject.hostname+"."+$TargetDNSObject.ZoneName+"."}
        if ($result){
            $result | Foreach-Object { 
                GetDNSCNameHit($_) 
            }
        }
        return $result
    }
    function FindRecordTypeA {
        param (
            $TargetDNSObject
        )
        if ($TargetDNSObject.recordType -in ("CNAME")){
            Write-Verbose "Ищем запись типа A для $TargetDNSObject"
            $result = $Script:SORT_LIST | Where-Object{$_.hostname -like $TargetDNSObject.Data.Split('.')[0]}
            $result | ForEach-Object{
                if ($_.recordType -cnotin ("A","AAAA","TXT")){
                    $result = FindRecordTypeA($_)
                }
            }
        } else {
            $result = $TargetDNSObject
        }
        return $result
    }

    # Поиск записей
    $results = @()
    
    # Если был ввод имени, либо первая переменная без ключа.
    if ($Name) {
        Write-Verbose "Поиск по имени: $Name"
        $nameResult = ($Script:SORT_LIST | Where-Object{ $_.hostname -like "$Name" } )
        # Выдаем ошибку 
        if (-not $nameResult){
            Write-Error "Записи не найдены для указанных параметров: $Name" -ErrorAction Stop
        }
        
        Write-Verbose "Поиск исходной записи типа А для объекта: $nameResult"
        $ipResult = ($nameResult | ForEach-Object{ FindRecordTypeA($_) })
        if (-not $ipResult){
            Write-Warning "Внимание! Для имени $Name не найдено исходной записи типа А для объекта: $nameResult"
            Write-Warning "Поиск совпадений невозможен"
            return $nameResult
        }
        
        Write-Verbose "Поиск всех записей по IP: $ipResult"
        $ipResult | ForEach-Object {
            $results += GetDnsRecordsByIP($_.Data.IPAddressToString)
        }
        # $results += GetDnsRecordsByIP($ipResult.Data.IPAddressToString)
        Write-Verbose "Поиск всех CNAME для $ipResult"
        $results += GetDNSCNameHit( $ipResult | Get-Unique )
        
        return $results
    }
    
    # Если использовался ключ -IP
    if ($IP) {
        Write-Verbose "Поиск всех записей по IP: $IP"
        $results += GetDnsRecordsByIP($IP)
        
        return $results
    }

    # Если использовался ключ -All
    if ($All) {
        Write-Verbose "Вывод всех записей"
        $results += $Script:SORT_LIST
        
        return $results
    }
    
    # Вывод предупреждения, если записи не найдены
    if (-not $results) {
        if ($Refresh){
            Write-Warning "Произведено только обновление кеша. Для вывода результата используйте ключи -All -Name или -IP"
        }else{
            Write-Warning "Записи не найдены для указанных параметров"
        }
    }
}

# Экспортируем только основную функцию
Export-ModuleMember -Function Get-DnsZoneRecords