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
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script debe ejecutarse como Administrador para instalar la tarea." -ForegroundColor Red
        exit
    }
    
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
    $Trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration (New-TimeSpan -Days 3650)
    
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
            
            $Dia = [int]$Now.DayOfWeek 
            $Mes = $Now.Month
            
            if ($Dia -ge 1 -and $Dia -le 5) {
                
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
                    Start-Sleep -Seconds 2
                    
                    shutdown /s /f /t 0 /c "Apagado automático por horario. Permitido L-V: 09:00-$HoraFin"
                    
                    exit
                } else {
                    if ($Now.Minute -eq 0) {
                        Write-Log "Monitor activo. Dentro de horario: $Hora (Día $Dia, Mes $Mes)"
                    }
                }
            } else {
                if ($Now.Hour -eq 0 -and $Now.Minute -eq 0) {
                    Write-Log "Fin de semana - Sin restricciones (Día $Dia)"
                }
            }
            
            Start-Sleep -Seconds 60
            
        } catch {
            Write-Log "ERROR en loop: $_"
            Write-Log "Detalles: $($_.Exception.Message)"
            Start-Sleep -Seconds 300
        }
    }
}

if ($Test) {
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║        MODO PRUEBA - No se apagará          ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    $Now = Get-Date
    $Hora = $Now.ToString("HH:mm")
    $DiaNum = [int]$Now.DayOfWeek
    $DiaNombre = $Now.DayOfWeek
    
    $DiasSemana = @{
        0 = "Domingo"
        1 = "Lunes"
        2 = "Martes"
        3 = "Miércoles"
        4 = "Jueves"
        5 = "Viernes"
        6 = "Sábado"
    }
    
    $Mes = $Now.Month
    $MesNombre = $Now.ToString("MMMM")
    
    Write-Host "FECHA Y HORA ACTUAL:" -ForegroundColor Yellow
    Write-Host "  • Fecha: $($Now.ToString('dd/MM/yyyy'))"
    Write-Host "  • Hora: $Hora"
    Write-Host "  • Día: $DiaNombre (Número: $DiaNum)"
    Write-Host "  • Mes: $MesNombre (Número: $Mes)"
    Write-Host ""
    
    if ($Mes -ge 3 -and $Mes -le 12) {
        $HoraFin = "22:30"
        $Temporada = "Marzo a Diciembre"
        $TemporadaInfo = "Horario de verano/invierno"
    } else {
        $HoraFin = "23:59"
        $Temporada = "Enero a Febrero"
        $TemporadaInfo = "Horario especial"
    }
    
    Write-Host "CONFIGURACIÓN:" -ForegroundColor Yellow
    Write-Host "  • Temporada: $Temporada"
    Write-Host "  • $TemporadaInfo"
    Write-Host "  • Horario permitido L-V: 09:00 - $HoraFin"
    Write-Host ""
    
    $minutosActual = ($Now.Hour * 60) + $Now.Minute
    $minutosInicio = 9 * 60
    $partes = $HoraFin.Split(':')
    $minutosFin = ([int]$partes[0] * 60) + [int]$partes[1]
    
    Write-Host "CÁLCULOS:" -ForegroundColor Yellow
    Write-Host "  • Minutos desde medianoche: $minutosActual"
    Write-Host "  • Minutos inicio (09:00): $minutosInicio"
    Write-Host "  • Minutos fin ($HoraFin): $minutosFin"
    Write-Host ""
    
    Write-Host "RESULTADO:" -ForegroundColor Yellow
    if ($DiaNum -eq 0 -or $DiaNum -eq 6) {
        Write-Host "  • ES FIN DE SEMANA ($DiasSemana[$DiaNum])" -ForegroundColor Green
        Write-Host "  • ESTADO: SIN RESTRICCIONES" -ForegroundColor Green
        Write-Host "  • Acción: El PC NO se apagará"
    } elseif ($minutosActual -lt $minutosInicio) {
        Write-Host "  • ES DÍA LABORABLE ($DiasSemana[$DiaNum])" -ForegroundColor Red
        Write-Host "  • ESTADO: FUERA DE HORARIO (antes de las 09:00)" -ForegroundColor Red
        Write-Host "  • Acción: El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
    } elseif ($minutosActual -gt $minutosFin) {
        Write-Host "  • ES DÍA LABORABLE ($DiasSemana[$DiaNum])" -ForegroundColor Red
        Write-Host "  • ESTADO: FUERA DE HORARIO (después de las $HoraFin)" -ForegroundColor Red
        Write-Host "  • Acción: El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
    } else {
        Write-Host "  • ES DÍA LABORABLE ($DiasSemana[$DiaNum])" -ForegroundColor Green
        Write-Host "  • ESTADO: DENTRO DE HORARIO PERMITIDO" -ForegroundColor Green
        Write-Host "  • Acción: El PC NO se apagaría" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║   Para probar diferentes horarios, usa:     ║" -ForegroundColor Cyan
    Write-Host "║   Set-Date -Date \"2026-03-02 23:30\"         ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    
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
  ✓ Modo prueba para verificar configuración

EJEMPLOS DE USO:
  .\ShutdownManager.ps1 -Install
  .\ShutdownManager.ps1 -Test
  Get-ScheduledTask -TaskName "$TaskName"
  Get-Content "$LogPath"

NOTA: Requiere permisos de administrador para instalar
"@ -ForegroundColor Cyan
