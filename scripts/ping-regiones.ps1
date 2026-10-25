# Mide la latencia ICMP desde esta PC hacia droplets de prueba en varias regiones de DigitalOcean
# para elegir la del concentrador WireGuard por datos (docs/guia-droplet-digitalocean.md, parte B).
# Solo lectura: no modifica nada. Las IP se ocultan en el archivo de salida (el repo es público).
# Uso (PowerShell 7):
#   pwsh -File scripts/ping-regiones.ps1 -Destino 'sfo3=203.0.113.10','nyc3=198.51.100.20' -Pings 50
param(
    # Pares etiqueta=IP, p. ej. sfo3=203.0.113.10
    [Parameter(Mandatory)][string[]]$Destino,
    [int]$Pings = 50,
    [string]$Salida = (Join-Path $PSScriptRoot '..\evidencia\dia4\regiones.txt')
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path (Split-Path $Salida) | Out-Null

# Con `pwsh -File` una lista separada por comas llega como una sola cadena: se separa aquí.
$Destino = @($Destino | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim(" '`"") } | Where-Object { $_ })

function Ocultar([string]$ip) { ($ip -replace '^(\d+\.\d+)\.\d+\.\d+$', '$1.x.x') }

$filas = foreach ($par in $Destino) {
    $etiqueta, $ip = $par -split '=', 2
    if (-not $ip) { throw "Formato inválido '$par': usar etiqueta=IP" }
    Write-Host "Midiendo $etiqueta ($Pings pings)..."
    $r = Test-Connection -TargetName $ip -Count $Pings -ErrorAction SilentlyContinue
    $ok = @($r | Where-Object { $_.Status -eq 'Success' })
    $lat = @($ok | ForEach-Object { [double]$_.Latency })
    if ($lat.Count -eq 0) {
        [pscustomobject]@{ Region = $etiqueta; IP = Ocultar $ip; Promedio = 'sin respuesta'; Min = ''; Max = ''; Jitter = ''; Perdida = '100 %' }
        continue
    }
    $prom = ($lat | Measure-Object -Average).Average
    $desv = [math]::Sqrt((($lat | ForEach-Object { ($_ - $prom) * ($_ - $prom) }) | Measure-Object -Sum).Sum / $lat.Count)
    [pscustomobject]@{
        Region   = $etiqueta
        IP       = Ocultar $ip
        Promedio = '{0:N1} ms' -f $prom
        Min      = '{0:N0} ms' -f ($lat | Measure-Object -Minimum).Minimum
        Max      = '{0:N0} ms' -f ($lat | Measure-Object -Maximum).Maximum
        Jitter   = '{0:N1} ms' -f $desv
        Perdida  = '{0:N0} %' -f (100 * ($Pings - $lat.Count) / $Pings)
    }
}

$texto = @(
    "# regiones.txt - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
    "Latencia ICMP desde esta PC (cableada) a droplets de prueba; $Pings pings por región. Jitter = desviación estándar."
    "Se elige la región con menor promedio y jitter, y pérdida de 0 %."
    ''
    ($filas | Sort-Object { if ($_.Promedio -match '^[\d.,]+') { [double]($_.Promedio -replace ' ms','') } else { 9999 } } | Format-Table -AutoSize | Out-String).TrimEnd()
) -join "`n"
Set-Content -Path $Salida -Value $texto -Encoding UTF8
Write-Host $texto
Write-Host "`nEscrito en $Salida"
