param(
    [switch]$Install,    
    [switch]$Uninstall,  
    [switch]$Run,        
    [switch]$Test        
)

$TaskName = "WindowsAutomaticMonitor"
$ScriptPath = "C:\Windows\System32\ShutdownManager.ps1"
$LogPath = "C:\Windows\System32\ShutdownManager.log"

function Write-Log {
    param([string]$Message)
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message" | Out-File $LogPath -Append
}

if ($Install) {
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-Host "La tarea '$TaskName' ya existe." -ForegroundColor Yellow
        $response = Read-Host "¿Desea reemplazarla? (S/N)"
        if ($response -notmatch '^[Ss]') {
            Write-Host "Instalación cancelada." -ForegroundColor Red
            exit
        }
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    $Action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`" -Run"
    
    $Trigger1 = New-ScheduledTaskTrigger -AtStartup
    $Trigger1.Delay = "PT1M"
    $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date)
    $Trigger2.RepetitionInterval = (New-TimeSpan -Minutes 1)
    $Trigger2.RepetitionDuration = [TimeSpan]::MaxValue 
    
    $Principal = New-ScheduledTaskPrincipal `
        -UserId "SYSTEM" `
        -LogonType ServiceAccount `
        -RunLevel Highest
    
    $Settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -WakeToRun `
        -RestartInterval (New-TimeSpan -Minutes 5) `
        -RestartCount 3 `
        -MultipleInstances Parallel
    
    $Task = New-ScheduledTask `
        -Action $Action `
        -Trigger @($Trigger1, $Trigger2) `
        -Principal $Principal `
        -Settings $Settings
    
    Register-ScheduledTask -TaskName $TaskName -InputObject $Task -Force
    
    Write-Log "Tarea programada instalada: $TaskName"
    Write-Host "Tarea programada instalada exitosamente: $TaskName" -ForegroundColor Green
    Write-Host "Script: $ScriptPath"
    Write-Host "Log: $LogPath"
    
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Tarea iniciada. Verificando cada 60 segundos..." -ForegroundColor Cyan
    
    exit
}

if ($Uninstall) {
    try {
        Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Log "Tarea programada eliminada: $TaskName"
        Write-Host "Tarea programada eliminada: $TaskName" -ForegroundColor Green
    } catch {
        Write-Host "No se pudo eliminar la tarea: $_" -ForegroundColor Yellow
    }
    exit
}

if ($Run) {
    Write-Log "Monitor iniciado"
    
    while ($true) {
        try {
            $Now = Get-Date
            $Hora = $Now.ToString("HH:mm")
            $Dia = $Now.DayOfWeek.Value__
            $Mes = $Now.Month
            
            if ($Dia -ge 2 -and $Dia -le 6) {
                
                if ($Mes -ge 3 -and $Mes -le 12) {
                    $HoraFin = "22:30"
                    $Temporada = "Mar-Dic"
                } else {
                    $HoraFin = "23:59"
                    $Temporada = "Ene-Feb"
                }
                
                $minutosActual = ($Now.Hour * 60) + $Now.Minute
                $minutosInicio = 9 * 60  
                $partes = $HoraFin.Split(':')
                $minutosFin = ([int]$partes[0] * 60) + [int]$partes[1]
                
                if ($minutosActual -lt $minutosInicio -or $minutosActual -gt $minutosFin) {
                    
                    $mensaje = "APAGADO - Fuera de horario. Límite:$HoraFin Actual:$Hora Dia:$Dia Mes:$Mes"
                    Write-Log $mensaje
                    Write-Log "Ejecutando shutdown..."
                    shutdown /s /f /t 0 /c "Apagado automático por horario. Permitido L-V: 09:00-$HoraFin"
                    
                    exit
                } else {
                    if ($Now.Minute -eq 0) {
                        Write-Log "Monitor activo. Dentro de horario: $Hora"
                    }
                }
            } else {
                if ($Now.Hour -eq 0 -and $Now.Minute -eq 0) {
                    Write-Log "Fin de semana - Sin restricciones"
                }
            }
            
            Start-Sleep -Seconds 60
            
        } catch {
            Write-Log "ERROR en loop: $_"
            Start-Sleep -Seconds 300
        }
    }
}

if ($Test) {
    Write-Host "MODO PRUEBA - No se apagará realmente" -ForegroundColor Cyan
    
    $Now = Get-Date
    $Hora = $Now.ToString("HH:mm")
    $Dia = $Now.DayOfWeek
    $Mes = $Now.Month
    
    Write-Host "Fecha: $($Now.ToString('dd/MM/yyyy'))"
    Write-Host "Hora: $Hora"
    Write-Host "Día: $Dia"
    Write-Host "Mes: $Mes"
    
    if ($Mes -ge 3 -and $Mes -le 12) {
        $HoraFin = "22:30"
        $Temporada = "Marzo-Diciembre"
    } else {
        $HoraFin = "23:59"
        $Temporada = "Enero-Febrero"
    }
    
    Write-Host "Temporada: $Temporada"
    Write-Host "Horario permitido L-V: 09:00 - $HoraFin"
    
    $minutosActual = ($Now.Hour * 60) + $Now.Minute
    $minutosInicio = 9 * 60
    $partes = $HoraFin.Split(':')
    $minutosFin = ([int]$partes[0] * 60) + [int]$partes[1]
    
    Write-Host "Minutos actuales: $minutosActual"
    Write-Host "Minutos inicio: $minutosInicio"
    Write-Host "Minutos fin: $minutosFin"
    
    if ($Dia -in @('Saturday', 'Sunday')) {
        Write-Host "Fin de semana - SIN RESTRICCIÓN" -ForegroundColor Green
    } elseif ($minutosActual -lt $minutosInicio) {
        Write-Host "FUERA DE HORARIO - Antes de las 09:00" -ForegroundColor Red
        Write-Host "   (En modo real: APAGARÍA INMEDIATAMENTE)"
    } elseif ($minutosActual -gt $minutosFin) {
        Write-Host "FUERA DE HORARIO - Después de las $HoraFin" -ForegroundColor Red
        Write-Host "   (En modo real: APAGARÍA INMEDIATAMENTE)"
    } else {
        Write-Host "DENTRO DE HORARIO PERMITIDO" -ForegroundColor Green
    }
    
    exit
}

Write-Host @"
╔══════════════════════════════════════════════╗
║   SHUTDOWN MANAGER - Control de Horarios     ║
╚══════════════════════════════════════════════╝

Ubicación: $ScriptPath
Tarea programada: $TaskName

PARÁMETROS:
  -Install     Instalar como tarea programada
  -Uninstall   Eliminar la tarea programada
  -Run         Ejecutar el monitor (solo manual)
  -Test        Modo prueba (verifica sin apagar)

HORARIOS CONFIGURADOS:
  • Lunes a Viernes: 
     - Marzo a Diciembre: 09:00 - 22:30
     - Enero y Febrero: 09:00 - 23:59
  • Sábados y Domingos: Sin restricciones

CARACTERÍSTICAS:
  ✓ Se ejecuta al iniciar Windows
  ✓ Verifica cada 60 segundos
  ✓ Apagado inmediato fuera de horario
  ✓ Log en: $LogPath

EJEMPLOS DE USO:
  # Instalar (requiere Administrador)
  .\ShutdownManager.ps1 -Install
  
  # Probar configuración actual
  .\ShutdownManager.ps1 -Test
  
  # Ver estado de la tarea
  Get-ScheduledTask -TaskName "$TaskName"
  
  # Ver log
  Get-Content "$LogPath"

Requiere permisos de administrador para instalar
"@ -ForegroundColor Cyan