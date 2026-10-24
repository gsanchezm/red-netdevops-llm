# Captura la línea base de la red real del home office.
# Solo lectura: no modifica router, switch ni configuración de Windows.
# Uso (PowerShell 7):  pwsh -File scripts/linea-base.ps1
# Salida: evidencia/dia1/*.txt (IP pública y MACs ocultas: el repo es público)
param(
    [string]$Salida = (Join-Path $PSScriptRoot '..\evidencia\dia1'),
    [int]$Pings = 20,
    # Ejecutar solo algunas capturas, p. ej. -Solo ipv6.txt
    [string[]]$Solo = @()
)

$ErrorActionPreference = 'Continue'
$env:WSL_UTF8 = '1'
New-Item -ItemType Directory -Force -Path $Salida | Out-Null

$gateway = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1)
$gw = $gateway.IPv4DefaultGateway.NextHop
$ont = '192.168.100.1'
$internet = '8.8.8.8'
$publicasConocidas = @('8.8.8.8', '1.1.1.1')

function Ocultar([string]$texto) {
    # IPs públicas: se conservan los dos primeros octetos (suficiente para identificar al ISP).
    $texto = [regex]::Replace($texto, '\b\d{1,3}(\.\d{1,3}){3}\b', {
            param($m)
            $o = $m.Value.Split('.') | ForEach-Object { [int]$_ }
            $privada = $o[0] -eq 10 -or $o[0] -eq 127 -or
                ($o[0] -eq 192 -and $o[1] -eq 168) -or
                ($o[0] -eq 172 -and $o[1] -ge 16 -and $o[1] -le 31) -or
                ($o[0] -eq 100 -and $o[1] -ge 64 -and $o[1] -le 127)
            if ($privada -or $publicasConocidas -contains $m.Value) { $m.Value } else { '{0}.{1}.x.x' -f $o[0], $o[1] }
        })
    # MACs: se conserva el OUI (fabricante) y se oculta el identificador del equipo.
    $texto = [regex]::Replace($texto, '\b[0-9A-Fa-f]{2}([-:][0-9A-Fa-f]{2}){5}\b', { param($m) $m.Value.Substring(0, 8) + '-xx-xx-xx' })
    # IPv6 de enlace local: con EUI-64 los últimos grupos derivan de la MAC.
    [regex]::Replace($texto, '(fe80::[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}):[0-9a-fA-F]{1,4}:[0-9a-fA-F]{1,4}', '$1:xxxx:xxxx')
}

# -Crudo: archivos sin IPs ni MACs (evita que versiones tipo 3.0.3.0 se tomen por IPs).
function Guardar([string]$nombre, [scriptblock]$bloque, [switch]$Crudo) {
    if ($Solo.Count -gt 0 -and $Solo -notcontains $nombre) { return }
    $texto = & $bloque 2>&1 | Out-String -Width 200
    if (-not $Crudo) { $texto = Ocultar $texto }
    $encabezado = "# $nombre - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "$encabezado`n$texto" | Set-Content -Path (Join-Path $Salida $nombre) -Encoding utf8NoBOM
    Write-Host "ok  $nombre"
}

Guardar 'sistema.txt' -Crudo {
    '== Equipo'
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model,
    @{n = 'RAM_GB'; e = { [math]::Round($_.TotalPhysicalMemory / 1GB, 1) } } | Format-List
    '== CPU'
    Get-CimInstance Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors | Format-List
    '== Sistema operativo'
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List
    '== GPU (nvidia-smi; WMI reporta mal la VRAM > 4 GB)'
    nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv
    '== Discos'
    Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID,
    @{n = 'Total_GB'; e = { [math]::Round($_.Size / 1GB) } }, @{n = 'Libre_GB'; e = { [math]::Round($_.FreeSpace / 1GB) } } | Format-Table -AutoSize
}

Guardar 'interfaces.txt' {
    '== Adaptadores activos'
    Get-NetAdapter | Where-Object Status -EQ 'Up' | Select-Object Name, InterfaceDescription, LinkSpeed, MacAddress | Format-Table -AutoSize
    '== Configuración IPv4 de la interfaz con gateway'
    $gateway | Select-Object InterfaceAlias,
    @{n = 'IPv4'; e = { $_.IPv4Address.IPAddress } },
    @{n = 'Prefijo'; e = { $_.IPv4Address.PrefixLength } },
    @{n = 'Gateway'; e = { $_.IPv4DefaultGateway.NextHop } },
    @{n = 'DNS'; e = { $_.DNSServer.ServerAddresses -join ', ' } } | Format-List
    '== Direcciones IPv6 (fe80 = enlace local, fd = ULA privada, 2xxx = global)'
    Get-NetIPAddress -AddressFamily IPv6 -InterfaceAlias $gateway.InterfaceAlias |
        Select-Object IPAddress, PrefixOrigin, PrefixLength | Format-Table -AutoSize
}

Guardar 'latencia-icmp.txt' {
    foreach ($destino in @($gw, $ont, $internet)) {
        $r = Test-Connection -TargetName $destino -Count $Pings -ErrorAction SilentlyContinue
        $ok = @($r | Where-Object Status -EQ 'Success')
        $perdida = [math]::Round(100 * ($Pings - $ok.Count) / $Pings, 1)
        if ($ok.Count -gt 0) {
            $lat = $ok.Latency
            $prom = ($lat | Measure-Object -Average).Average
            $jitter = [math]::Sqrt((($lat | ForEach-Object { [math]::Pow($_ - $prom, 2) }) | Measure-Object -Sum).Sum / $lat.Count)
            '{0,-15} n={1} min={2} ms  prom={3:N2} ms  max={4} ms  jitter(desv.est.)={5:N2} ms  pérdida={6}%' -f `
                $destino, $Pings, ($lat | Measure-Object -Minimum).Minimum, $prom, ($lat | Measure-Object -Maximum).Maximum, $jitter, $perdida
        }
        else { '{0,-15} sin respuesta (pérdida 100%)' -f $destino }
    }
    ''
    'Nota: Windows reporta la latencia ICMP con resolución de 1 ms; valores de 0 significan < 1 ms.'
}

Guardar 'traceroute.txt' {
    # tracert escribe en la página de códigos OEM (850 en español), no en UTF-8.
    $previa = [Console]::OutputEncoding
    try { [Console]::OutputEncoding = [Text.Encoding]::GetEncoding([Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage) } catch {}
    tracert -d -h 8 -w 1000 $internet
    [Console]::OutputEncoding = $previa
    ''
    'Lectura: salto 1 = Deco (NAT #2), salto 2 = módem/ONT del ISP (NAT #1) -> doble NAT.'
    'Los saltos 10.x posteriores pertenecen a la red interna del proveedor.'
}

Guardar 'ip-publica.txt' {
    $ip = try { (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 8).Content } catch { 'no disponible' }
    "IP pública vista desde internet: $ip"
    'Rango CGNAT (RFC 6598) = 100.64.0.0/10. Para descartarlo hay que comparar con la IP WAN del módem;'
    'no se requiere en este proyecto porque el acceso VPN se valida en el laboratorio emulado.'
}

Guardar 'vecinos-arp.txt' {
    $vecinos = Get-NetNeighbor -AddressFamily IPv4 -InterfaceAlias $gateway.InterfaceAlias |
        Where-Object { $_.State -ne 'Unreachable' -and $_.IPAddress -like '192.168.*' -and $_.IPAddress -notlike '*.255' }
    "Vecinos en caché ARP: $(@($vecinos).Count) (solo equipos con los que esta PC habló recientemente;"
    'el Deco reporta el total de clientes de la casa).'
    $vecinos | Sort-Object { [version]$_.IPAddress } | Select-Object IPAddress, LinkLayerAddress, State | Format-Table -AutoSize
}

Guardar 'ia-nube.txt' {
    # Dependencia actual: Claude Code en los equipos de trabajo envía el contexto a la nube por HTTPS.
    'Tiempos de conexión hacia api.anthropic.com (curl, segundos acumulados)'
    'dns = resolución, tcp = handshake TCP, tls = handshake TLS completo, total = respuesta HTTP'
    $formato = 'dns=%{time_namelookup} tcp=%{time_connect} tls=%{time_appconnect} total=%{time_total} http=%{http_code} ip=%{remote_ip}\n'
    foreach ($modo in @(@{ n = 'doble pila (comportamiento por defecto)'; a = @() }, @{ n = 'solo IPv4 (curl -4)'; a = @('-4') })) {
        ''
        "== $($modo.n)"
        1..5 | ForEach-Object { curl.exe @($modo.a) -s -o NUL -w $formato https://api.anthropic.com/ }
    }
    ''
    'Lectura: el Deco anuncia un prefijo IPv6 ULA (fd00::/8) sin salida a internet. Como el destino'
    'tiene registro AAAA, curl intenta IPv6 primero y cae a IPv4 tras ~200 ms (Happy Eyeballs, RFC 8305).'
    'La diferencia entre ambos modos es el costo de esa IPv6 "a medias" en cada conexión nueva.'
    'Se compara en el Día 3 contra la API local (Caddy + Ollama) dentro del laboratorio.'
}

Guardar 'ipv6.txt' {
    '== Ruta IPv6 por defecto (anunciada por el Deco mediante Router Advertisement)'
    Get-NetRoute -AddressFamily IPv6 -DestinationPrefix '::/0' -ErrorAction SilentlyContinue |
        Select-Object InterfaceAlias, NextHop, RouteMetric | Format-Table -AutoSize
    '== Conexión TCP 443 directa por IPv6 a api.anthropic.com'
    $v6 = (Resolve-DnsName api.anthropic.com -Type AAAA -ErrorAction SilentlyContinue | Where-Object IPAddress | Select-Object -First 1).IPAddress
    $ok = $false
    $t = Measure-Command { $ok = Test-NetConnection -ComputerName $v6 -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet }
    "destino=$v6  conectado=$ok  tiempo=$([math]::Round($t.TotalMilliseconds)) ms"
    ''
    'Lectura: existe ruta por defecto IPv6 pero el camino no tiene salida (agujero negro): los SYN'
    'se pierden sin error inmediato. Un cliente sin Happy Eyeballs esperaría hasta el timeout;'
    'curl cae a IPv4 tras ~200 ms (ver ia-nube.txt).'
}

Guardar 'herramientas.txt' -Crudo {
    foreach ($c in 'git', 'python', 'docker', 'wsl', 'claude', 'wg', 'ansible', 'iperf3', 'ollama') {
        $cmd = Get-Command $c -ErrorAction SilentlyContinue
        '{0,-8} {1}' -f $c, $(if ($cmd) { 'instalado' } else { 'NO instalado' })
    }
    ''
    '== Versiones'
    git --version
    docker --version
    wsl --version
    if (Get-Command claude -ErrorAction SilentlyContinue) { "claude $(claude --version)" }
    '== Distribuciones WSL'
    wsl -l -v
}

Write-Host "Línea base guardada en $((Resolve-Path $Salida).Path)"
