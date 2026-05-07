#Requires -Version 5.1
<#
.SYNOPSIS
    ResolveCore - Diagnostico completo de sistema Windows

.DESCRIPTION
    Recoge metricas de hardware, software, red y seguridad.
    Genera JSON estructurado consumible por el generador de informes.

    Exit codes:
      0  ok
      1  error de escritura del informe
      2  error fatal en recogida de datos

.PARAMETER OutputDir
    Directorio donde se guardara el diagnostico (default: ../diagnosticos)

.PARAMETER Silent
    Suprime la salida por consola

.EXAMPLE
    .\diagnostico.ps1
    .\diagnostico.ps1 -Silent -OutputDir C:\reports
#>

[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$Silent
)

if (-not $OutputDir) {
    $OutputDir = Join-Path (Split-Path $PSScriptRoot -Parent) "diagnosticos"
}

# Captura no-fatal: cada bloque hace su propio try/catch local.
# 'SilentlyContinue' silencia tambien bugs reales; usamos 'Continue' y try/catch granular.
$ErrorActionPreference = 'Continue'

function Invoke-Safe {
    param([scriptblock]$Block, $Default = $null)
    try { & $Block } catch { return $Default }
}

# Helpers de salida

function Write-Header {
    Write-Host ''
    Write-Host '  +---------------------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host '  |   ResolveCore - Diagnostico Completo - v3.2.0                |' -ForegroundColor Cyan
    Write-Host "  |   $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')                                       |" -ForegroundColor DarkGray
    Write-Host '  +---------------------------------------------------------------+' -ForegroundColor DarkCyan
    Write-Host ''
}

function Write-Section { param($t) if (-not $Silent) { Write-Host "  > $t" -ForegroundColor Cyan } }
function Write-Ok      { param($t) if (-not $Silent) { Write-Host "    [OK] $t" -ForegroundColor Green } }
function Write-Warn    { param($t) if (-not $Silent) { Write-Host "    [!] $t" -ForegroundColor Yellow } }
function Write-Fail    { param($t) if (-not $Silent) { Write-Host "    [X] $t" -ForegroundColor Red } }

# Privilegios

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $Silent) {
    Write-Header
    if (-not $isAdmin) {
        Write-Host '  [!] Sin privilegios de Administrador - algunas metricas seran limitadas.' -ForegroundColor Yellow
    }
}

$report = [ordered]@{}

# ============================================
# 1. SISTEMA OPERATIVO
# ============================================

Write-Section 'Sistema Operativo'

$os = Get-CimInstance Win32_OperatingSystem
$uptime = [math]::Round(($os.LocalDateTime - $os.LastBootUpTime).TotalHours, 1)
$uptimeDays = [math]::Floor($uptime / 24)
$hotfixes = Get-CimInstance Win32_QuickFixEngineering

Write-Ok $os.Caption.Trim()
Write-Host "    Build: $($os.BuildNumber) - $($os.OSArchitecture)" -ForegroundColor Gray
Write-Host "    Version: $($os.Version)" -ForegroundColor Gray
Write-Host "    Uptime: $uptime horas ($uptimeDays dias)" -ForegroundColor Gray
Write-Host "    Serial: $($os.SerialNumber)" -ForegroundColor Gray
Write-Host "    Instalacion: $($os.InstallationType)" -ForegroundColor Gray
Write-Host "    Zona horaria: UTC $([math]::Round($os.CurrentTimeZone / 60, 1))" -ForegroundColor Gray
Write-Host "    Idioma: $($os.MUILanguages)" -ForegroundColor Gray
Write-Host "    Directorio: $($os.WindowsDirectory)" -ForegroundColor Gray
Write-Host "    Parches instalados: $($hotfixes.Count)" -ForegroundColor Gray
Write-Host "    Memoria libre: $([math]::Round($os.FreePhysicalMemory / 1MB, 0)) MB" -ForegroundColor Gray
Write-Host "    Virtual libre: $([math]::Round($os.FreeVirtualMemory / 1MB, 0)) MB" -ForegroundColor Gray

$report['sistema'] = [ordered]@{
    nombre = $os.Caption.Trim()
    version = $os.Version
    build = $os.BuildNumber
    arquitectura = $os.OSArchitecture
    install_date = $os.InstallDate
    last_boot = $os.LastBootUpTime
    uptime_horas = $uptime
    uptime_dias = $uptimeDays
    windows_directory = $os.WindowsDirectory
    locale = $os.Locale
    mui_languages = $os.MUILanguages
    timezone = $os.CurrentTimeZone
    serial_number = $os.SerialNumber
    installation_type = $os.InstallationType
    free_physical_mb = [int]($os.FreePhysicalMemory / 1MB)
    free_virtual_mb = [int]($os.FreeVirtualMemory / 1MB)
    parches_count = $hotfixes.Count
}

# ============================================
# 2. PROCESADOR
# ============================================

Write-Section 'Procesador'

$cpus = Get-CimInstance Win32_Processor
$totalCores = ($cpus | Measure-Object -Property NumberOfCores -Sum).Sum
$totalThreads = ($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum

Write-Ok $cpus[0].Name.Trim()
Write-Host "    Nucleos: $totalCores - Hilos: $totalThreads" -ForegroundColor Gray
Write-Host "    Velocidad: $($cpus[0].MaxClockSpeed) MHz (actual: $($cpus[0].CurrentClockSpeed) MHz)" -ForegroundColor Gray
Write-Host "    Cache L1: $([math]::Round($cpus[0].L1CacheSize / 1024, 1)) MB - L2: $([math]::Round($cpus[0].L2CacheSize / 1024, 1)) MB - L3: $([math]::Round($cpus[0].L3CacheSize / 1024, 1)) MB" -ForegroundColor Gray
Write-Host "    Fabricante: $($cpus[0].Manufacturer)" -ForegroundColor Gray
Write-Host "    ID: $($cpus[0].ProcessorId)" -ForegroundColor Gray

try {
    $temp = Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSAcpi_ThermalZoneTemperature'
    if ($temp) { Write-Host "    Temperatura: $([math]::Round($temp[0].CurrentTemperature / 10 - 273.15, 1)) C" -ForegroundColor Gray }
} catch {}

$cpuList = @($cpus | ForEach-Object {
    [ordered]@{
        nombre = $_.Name.Trim()
        nucleos = $_.NumberOfCores
        hilos = $_.NumberOfLogicalProcessors
        velocidad_mhz = $_.MaxClockSpeed
        velocidad_actual = $_.CurrentClockSpeed
        cache_l1_kb = $_.L1CacheSize
        cache_l2_kb = $_.L2CacheSize
        cache_l3_kb = $_.L3CacheSize
        fabricante = $_.Manufacturer
        processor_id = $_.ProcessorId
    }
})

$report['cpu'] = [ordered]@{
    cantidad = $cpus.Count
    nucleos_total = $totalCores
    hilos_total = $totalThreads
    processors = $cpuList
}

# ============================================
# 3. MEMORIA
# ============================================

Write-Section 'Memoria'

$mem = Get-CimInstance Win32_ComputerSystem
$totalRam = [math]::Round($mem.TotalPhysicalMemory / 1GB, 2)
$availRam = [math]::Round($os.FreePhysicalMemory / 1024 / 1024, 2)

Write-Ok "Total: $totalRam GB - Disponible: $availRam GB"
Write-Host "    Usada: $([math]::Round($totalRam - $availRam, 2)) GB" -ForegroundColor Gray
Write-Host "    Fabricante: $($mem.Manufacturer)" -ForegroundColor Gray
Write-Host "    Modelo: $($mem.Model)" -ForegroundColor Gray
Write-Host "    Tipo: $($mem.SystemType)" -ForegroundColor Gray
Write-Host "    Hostname: $($mem.Name) - Dominio: $($mem.Domain)" -ForegroundColor Gray

$ramMods = Get-CimInstance Win32_PhysicalMemory
$ramList = @()
foreach ($r in $ramMods) {
    $ramList += [ordered]@{
        slot = $r.DeviceLocator
        capacidad_gb = [math]::Round($r.Capacity / 1GB, 2)
        velocidad = $r.Speed
        tipo = switch ([int]$r.SMBIOSMemoryType) { 26{'DDR4'} 34{'DDR5'} 24{'DDR3'} 20{'DDR2'} default{'Unknown'} }
        fabricante = $r.Manufacturer
        serial = $r.SerialNumber
    }
    Write-Host "    Slot $($r.DeviceLocator): $([math]::Round($r.Capacity / 1GB, 2))GB $($r.Speed)MHz $($r.Manufacturer)" -ForegroundColor Gray
}

Write-Host "    Modulos detectados: $($ramMods.Count)" -ForegroundColor Gray

$report['memoria'] = [ordered]@{
    total_gb = $totalRam
    disponible_gb = $availRam
    usada_gb = [math]::Round($totalRam - $availRam, 2)
    fabricante = $mem.Manufacturer
    modelo = $mem.Model
    modulos = $ramList
}

# ============================================
# 4. ALMACENAMIENTO
# ============================================

Write-Section 'Almacenamiento'

$discos = Get-CimInstance Win32_DiskDrive
$diskList = @()
foreach ($d in $discos) {
    $sizeGB = [math]::Round($d.Size / 1GB, 1)
    $tipo = switch ([int]$d.MediaType) {
        4 { 'HDD' } 3 { 'SSD' } 5 { 'SSD' }
        default { if ($d.Caption -match 'SSD|NVMe|Solid|Flash') { 'SSD' } elseif ($d.Caption -match 'HDD|SATA') { 'HDD' } else { 'Disk' } }
    }
    $diskList += [ordered]@{
        modelo = $d.Caption
        capacidad_gb = $sizeGB
        tipo = $tipo
        serial = $d.SerialNumber
        firmware = $d.FirmwareRevision
        bus = $d.InterfaceType
    }
    Write-Ok "$($d.Caption) - ${sizeGB}GB ($tipo)"
    Write-Host "    Serial: $($d.SerialNumber) - Bus: $($d.InterfaceType)" -ForegroundColor Gray
}

Write-Host "    ---" -ForegroundColor Gray

# S.M.A.R.T. via StorageReliabilityCounter
try {
    $smartData = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
    if ($smartData) {
        foreach ($sd in $smartData) {
            $matchDisk = $diskList | Where-Object { $_.modelo -and $sd.DeviceId }
            if ($sd.Temperature) {
                Write-Host "    S.M.A.R.T.: Temp $($sd.Temperature) C | Desgaste $($sd.Wear)% | ReadErrors $($sd.ReadErrorsTotal) | WriteErrors $($sd.WriteErrorsTotal) | Horas $($sd.PowerOnHours)" -ForegroundColor Gray
                if ($sd.Temperature -gt 55) { Write-Warn "Temperatura disco alta: $($sd.Temperature) C" }
                if ($sd.Wear -gt 80) { Write-Warn "Desgaste SSD > 80%: $($sd.Wear)%" }
            }
        }
        $smartJson = @($smartData | ForEach-Object { [ordered]@{
            temperatura_c    = $_.Temperature
            desgaste_pct     = $_.Wear
            read_errors      = $_.ReadErrorsTotal
            write_errors     = $_.WriteErrorsTotal
            horas_encendido  = $_.PowerOnHours
        }})
        $report['smart'] = $smartJson
    }
} catch {}

$drives = Get-PSDrive -PSProvider FileSystem
$driveList = @()
foreach ($dr in $drives) {
    if ($dr.Used -ne $null) {
        $totalGB = [math]::Round(($dr.Used + $dr.Free) / 1GB, 1)
        $freeGB = [math]::Round($dr.Free / 1GB, 1)
        $usedPct = [math]::Round($dr.Used / ($dr.Used + $dr.Free) * 100, 1)
        $driveList += [ordered]@{
            letra = $dr.Name
            capacidad_gb = $totalGB
            libre_gb = $freeGB
            usado_pct = $usedPct
            sistema_archivos = $dr.FSType
        }
        Write-Host "    $($dr.Name): ${totalGB}GB (libre: ${freeGB}GB, usado: ${usedPct}%) - $($dr.FSType)" -ForegroundColor Gray
    }
}

$report['discos'] = [ordered]@{
    fisicos = $diskList
    logicos = $driveList
}

# ============================================
# 5. GRAFICA
# ============================================

Write-Section 'Grafica'

$gpus = Get-CimInstance Win32_VideoController
$gpuList = @()
foreach ($g in $gpus) {
    $vramMB = if ($g.AdapterRAM) { [math]::Round($g.AdapterRAM / 1MB, 0) } else { 0 }
    $tipo = if ($g.Caption -match 'NVIDIA') { 'NVIDIA' } elseif ($g.Caption -match 'AMD|Radeon') { 'AMD' } elseif ($g.Caption -match 'Intel') { 'Intel' } else { 'Other' }
    $gpuList += [ordered]@{
        nombre = $g.Caption.Trim()
        tipo = $tipo
        driver = $g.DriverVersion
        vram_mb = $vramMB
        resolucion = "$($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution)"
        refresh = $g.CurrentRefreshRate
        estado = $g.Status
    }
    Write-Ok $g.Caption.Trim()
    Write-Host "    Driver: $($g.DriverVersion)" -ForegroundColor Gray
    Write-Host "    VRAM: $vramMB MB" -ForegroundColor Gray
    Write-Host "    Resolucion: $($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate)Hz" -ForegroundColor Gray
    Write-Host "    Estado: $($g.Status)" -ForegroundColor Gray
}

try {
    $nv = Get-Command nvidia-smi -ErrorAction SilentlyContinue
    if ($nv) {
        $gput = & nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null
        if ($gput -match '^\d+$') { Write-Host "    Temperatura GPU: $gput C" -ForegroundColor Gray }
    }
} catch {}

$report['gpu'] = $gpuList

# ============================================
# 6. RED
# ============================================

Write-Section 'Red'

$adapters = Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress }
$netList = @()
foreach ($a in $adapters) {
    $netList += [ordered]@{
        nombre = $a.Name
        mac = $a.MACAddress
        tipo = $a.AdapterType
        velocidad = $a.Speed
    }
    Write-Host "    $($a.Name): $($a.MACAddress) - $($a.Speed)" -ForegroundColor Gray
}

$ipconfigs = Get-NetIPConfiguration
$ipList = @()
foreach ($ip in $ipconfigs) {
    if ($ip.IPv4Address) {
        $ipv4 = $ip.IPv4Address.IPAddress
        $gw = if ($ip.IPv4DefaultGateway) { $ip.IPv4DefaultGateway.NextHop } else { '' }
        $dns = $ip.DNSServer.ServerAddresses -join ', '
        $ipList += [ordered]@{
            interfaz = $ip.InterfaceAlias
            ipv4 = $ipv4
            gateway = $gw
            dns = $dns
        }
        Write-Host "    $($ip.InterfaceAlias): $ipv4 - GW: $gw" -ForegroundColor Gray
        if ($dns) { Write-Host "      DNS: $dns" -ForegroundColor Gray }
    }
}

Write-Host "    ---" -ForegroundColor Gray
$ping1 = Test-Connection -ComputerName 8.8.8.8 -Count 3 -ErrorAction SilentlyContinue
if ($ping1) {
    $lat = [math]::Round(($ping1 | Measure-Object ResponseTime -Average).Average, 1)
    Write-Ok "Internet: OK ($lat ms)"
} else {
    Write-Fail "Sin conexion a internet"
}

$report['red'] = [ordered]@{
    adaptadores = $netList
    ip = $ipList
}

# ============================================
# 7. PLACA BASE Y BIOS
# ============================================

Write-Section 'Placa Base'

$mb = Get-CimInstance Win32_BaseBoard
$bios = Get-CimInstance Win32_BIOS

Write-Ok "$($mb.Product) - $($mb.Manufacturer)"
Write-Host "    Serial: $($mb.SerialNumber) - Version: $($mb.Version)" -ForegroundColor Gray
Write-Host "    ---" -ForegroundColor Gray
Write-Host "    BIOS: $($bios.Name)" -ForegroundColor Gray
Write-Host "    Version: $($bios.BIOSVersion) - Fecha: $($bios.ReleaseDate)" -ForegroundColor Gray
Write-Host "    UUID: $($bios.UUID)" -ForegroundColor Gray
Write-Host "    Serial: $($bios.SerialNumber)" -ForegroundColor Gray

$report['placa_base'] = [ordered]@{
    producto = $mb.Product
    fabricante = $mb.Manufacturer
    serial = $mb.SerialNumber
    bios_nombre = $bios.Name
    bios_version = $bios.BIOSVersion
    bios_fecha = $bios.ReleaseDate
    bios_uuid = $bios.UUID
}

# ============================================
# 8. BATERIA
# ============================================

Write-Section 'Bateria'

$bat = Get-CimInstance Win32_Battery | Select-Object -First 1

if ($bat) {
    Write-Ok "$($bat.EstimatedChargeRemaining)%"
    Write-Host "    Estado: $($bat.BatteryStatus) - Voltage: $($bat.DesignVoltage)mV" -ForegroundColor Gray

    $desgaste = $null
    $batCiclos = $null
    try {
        $bf = (Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity').FullChargedCapacity
        $bd = (Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData').DesignedCapacity
        if ($bf -and $bd -and $bd -gt 0) {
            $desgaste = [math]::Round((1 - $bf / $bd) * 100, 1)
            Write-Host "    Desgaste: $desgaste%" -ForegroundColor Gray
            if ($desgaste -gt 80) { Write-Warn "Desgaste > 80% -- considere sustituir la bateria" }
        }
        $bc = (Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryCycleCount' -ErrorAction SilentlyContinue)
        if ($bc) { $batCiclos = $bc.CycleCount }
    } catch {}

    $report['bateria'] = [ordered]@{
        carga_pct   = $bat.EstimatedChargeRemaining
        estado      = $bat.BatteryStatus
        voltage     = $bat.DesignVoltage
        desgaste_pct = $desgaste
        ciclos      = $batCiclos
    }
} else {
    Write-Host "    Escritorio (sin bateria)" -ForegroundColor Gray
    $report['bateria'] = $null
}

# ============================================
# 9. SERVICIOS
# ============================================

Write-Section 'Servicios'

$svcs = Get-Service
$running = ($svcs | Where-Object { $_.Status -eq 'Running' }).Count
$stopped = ($svcs | Where-Object { $_.Status -eq 'Stopped' }).Count

Write-Host "    Total: $($svcs.Count) - Iniciados: $running - Detenidos: $stopped" -ForegroundColor Gray

$autoStopped = $svcs | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -eq 'Stopped' }
if ($autoStopped) {
    Write-Warn "Automaticos detenidos: $($autoStopped.Count)"
    foreach ($s in $autoStopped | Select-Object -First 5) { Write-Host "    - $($s.Name)" -ForegroundColor Gray }
}

$criticos = @('wuauserv', 'WSearch', 'Spooler', 'BITS', 'Dnscache', 'Dhcp', 'LanmanServer', 'EventLog', 'Netlogon', 'PlugPlay')
$critList = @()
foreach ($c in $criticos) {
    $s = Get-Service -Name $c -ErrorAction SilentlyContinue
    if ($s) {
        $critList += [ordered]@{
            nombre = $s.Name
            estado = $s.Status.ToString()
            inicio = $s.StartType.ToString()
        }
        if ($s.Status -eq 'Running') { Write-Ok "$($s.DisplayName): OK" }
        else { Write-Warn "$($s.DisplayName): $($s.Status)" }
    }
}

$report['servicios'] = [ordered]@{
    total = $svcs.Count
    iniciados = $running
    detenidos = $stopped
    automaticos_detenidos = $autoStopped.Count
    criticos = $critList
}

# ============================================
# 10. SOFTWARE INSTALADO
# ============================================

Write-Section 'Software Instalado'

$apps = @(
    Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
    Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
    Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue
) | Where-Object { $_.DisplayName } | Sort-Object DisplayName | Get-Unique -AsString | Select-Object -First 50

Write-Host "    Aplicaciones: $($apps.Count)" -ForegroundColor Gray
foreach ($a in $apps | Select-Object -First 15) {
    Write-Host "    - $($a.DisplayName) v$($a.DisplayVersion)" -ForegroundColor Gray
}

$appList = @($apps | ForEach-Object {
    [ordered]@{
        nombre = $_.DisplayName
        version = $_.DisplayVersion
        proveedor = $_.Publisher
    }
})

$report['software'] = [ordered]@{
    cantidad = $apps.Count
    lista = $appList
}

# ============================================
# 11. RENDIMIENTO
# ============================================

Write-Section 'Rendimiento'

# Reusamos $cpus (linea 114) y $os (linea 70) para evitar nuevas consultas WMI
$cpuLoad = [math]::Round(($cpus | Measure-Object LoadPercentage -Average).Average, 0)
Write-Ok "CPU: $cpuLoad%"

$memUse = [math]::Round(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1)
Write-Ok "Memoria: $memUse%"

Write-Host "    Procesos (memoria):" -ForegroundColor Gray
$topProcs = Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5
foreach ($p in $topProcs) {
    Write-Host "    - $($p.ProcessName): $([math]::Round($p.WorkingSet64 / 1MB, 0))MB" -ForegroundColor Gray
}

$report['rendimiento'] = [ordered]@{
    cpu_pct = $cpuLoad
    memoria_pct = $memUse
    top_procesos = @($topProcs | ForEach-Object { @{nombre = $_.ProcessName; memoria_mb = [math]::Round($_.WorkingSet64 / 1MB, 0)} })
}

# ============================================
# 12. SEGURIDAD
# ============================================

Write-Section 'Seguridad'

try {
    $def = Get-MpComputerStatus
    if ($def) {
        $sigAge = [math]::Round(((Get-Date) - $def.AntivirusSignatureLastUpdated).TotalDays, 0)
        Write-Ok "Windows Defender"
        Write-Host "    Firmas: $sigAge dias ( $($def.AntivirusSignatureLastUpdated) )" -ForegroundColor Gray
        Write-Host "    Motor: $($def.AntivirusSignatureVersion)" -ForegroundColor Gray
        Write-Host "    Tiempo real: $(if($def.RealTimeProtectionEnabled){'ACTIVO'}else{'INACTIVO'})" -ForegroundColor Gray
        $defender = [ordered]@{ activo = $true; firmas_dias = $sigAge; firmas_version = $def.AntivirusSignatureVersion; realtime = $def.RealTimeProtectionEnabled }
    }
} catch { $defender = @{ activo = $false } }

try {
    $fw = Get-NetFirewallProfile
    Write-Host "    Firewall: $($fw.Enabled.Count) perfiles activos" -ForegroundColor Gray
    foreach ($f in $fw) { Write-Host "    - $($f.Name): $(if($f.Enabled){'ACTIVO'}else{'inactivo'})" -ForegroundColor Gray }
    $fwList = @($fw | ForEach-Object { [ordered]@{ nombre = $_.Name; activo = [bool]$_.Enabled } })
} catch { $fwList = @() }

$uac = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA
Write-Host "    UAC: $(if($uac.EnableLUA -eq 1){'ACTIVADO'}else{'DESACTIVADO'})" -ForegroundColor Gray

$bl = Get-Module -Name BitLocker -ListAvailable
if ($bl) {
    try {
        $blV = Get-BitLockerVolume -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($blV) { Write-Host "    BitLocker: $($blV.ProtectionStatus)" -ForegroundColor Gray }
    } catch {}
}

$report['seguridad'] = [ordered]@{
    windows_defender = $defender
    firewall = $fwList
    uac = ($uac.EnableLUA -eq 1)
}

# ============================================
# 13. USUARIOS
# ============================================

Write-Section 'Usuarios'

$users = Get-CimInstance Win32_UserAccount | Where-Object { $_.LocalAccount }
Write-Host "    Locales: $($users.Count)" -ForegroundColor Gray
foreach ($u in $users) {
    $estado = if ($u.Disabled) { 'DESHABILITADO' } else { 'ACTIVO' }
    Write-Host "    - $($u.Name): $estado | $($u.FullName)" -ForegroundColor Gray
}

$report['usuarios'] = @($users | ForEach-Object { [ordered]@{ nombre = $_.Name; completo = $_.FullName; disabled = [bool]$_.Disabled } })

# ============================================
# METADATA
# ============================================

$report['_meta'] = [ordered]@{
    version = '3.2.0'
    plataforma = 'windows'
    hostname = $env:COMPUTERNAME
    usuario = $env:USERNAME
    generado_en = (Get-Date -Format 'o')
    admin = $isAdmin
}

# ============================================
# OUTPUT JSON
# ============================================

try {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
} catch {
    Write-Fail "No se pudo crear directorio salida: $OutputDir"
    exit 1
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile = Join-Path $OutputDir "diagnostico_$($env:COMPUTERNAME)_$timestamp.json"

try {
    $report | ConvertTo-Json -Depth 10 | Out-File -FilePath $outFile -Encoding UTF8 -ErrorAction Stop
} catch {
    Write-Fail "Error escribiendo JSON: $($_.Exception.Message)"
    exit 1
}

# Informe HTML (best-effort: el JSON es la fuente autoritativa)
$templatePath = Join-Path $PSScriptRoot '../informe.html'
$htmlFile = $outFile -replace '\.json$', '.html'
if (Test-Path $templatePath) {
    try {
        $jsonContent = Get-Content $outFile -Raw -Encoding UTF8
        $html = (Get-Content $templatePath -Raw -Encoding UTF8) -replace '__JSON_DATA__', $jsonContent
        $html | Out-File -FilePath $htmlFile -Encoding UTF8 -ErrorAction Stop
        if (-not $Silent) { Start-Process $htmlFile }
    } catch {
        if (-not $Silent) { Write-Warn "No se pudo generar HTML: $($_.Exception.Message)" }
    }
}

if (-not $Silent) {
    Write-Host ''
    Write-Host '  ---------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '  [OK] Diagnostico completado' -ForegroundColor Green
    Write-Host "  JSON:  $outFile" -ForegroundColor White
    if (Test-Path $htmlFile) { Write-Host "  HTML:  $htmlFile" -ForegroundColor Cyan }
    Write-Host ''
}

# Imprimimos el path para captura por scripts padre, y exit 0 explicito
Write-Output $outFile
exit 0