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
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "$timestamp - $Message"
    
    try {
        $logMessage | Out-File $LogPath -Append -ErrorAction Stop
    } catch {
        $tempLog = "$env:TEMP\ShutdownManager.log"
        $logMessage | Out-File $tempLog -Append
        Write-Host "Usando log temporal: $tempLog" -ForegroundColor Yellow
    }
}

function Test-ScriptLocation {
    if (-not (Test-Path $ScriptPath)) {
        try {
            Copy-Item $MyInvocation.MyCommand.Path $ScriptPath -Force
            Write-Host "Script copiado a: $ScriptPath" -ForegroundColor Green
        } catch {
            Write-Host "ERROR: No se pudo copiar el script a $ScriptPath" -ForegroundColor Red
            Write-Host "Asegúrate de ejecutar como Administrador" -ForegroundColor Yellow
            return $false
        }
    }
    return $true
}

if ($Install) {
    if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Host "Este script debe ejecutarse como Administrador para instalar la tarea." -ForegroundColor Red
        exit
    }
    
    if (-not (Test-ScriptLocation)) {
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
    
    Write-Log "=== Tarea programada instalada: $TaskName ==="
    
    Write-Host "Tarea programada instalada exitosamente: $TaskName" -ForegroundColor Green
    Write-Host "Script: $ScriptPath"
    Write-Host "Log: $LogPath"
    
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Tarea iniciada. Verificando cada 60 segundos..." -ForegroundColor Cyan
    
    Write-Host "" -ForegroundColor Yellow
    Write-Host "Para verificar que funciona:" -ForegroundColor Yellow
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Format-List" -ForegroundColor Cyan
    Write-Host "  Get-Content '$LogPath' -Wait" -ForegroundColor Cyan
    
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
    Write-Log "=== Monitor iniciado ==="
    Write-Log "Versión: 2.0 - Corregido"
    
    $ultimoLogHora = -1
    
    while ($true) {
        try {
            $Now = Get-Date
            $Hora = $Now.ToString("HH:mm")
            $MinutoActual = $Now.Minute
            $Dia = [int]$Now.DayOfWeek 
            $Mes = $Now.Month
            
            $HoraInicio = "09:00"
            $minutosInicio = 9 * 60
            
            if ($Dia -eq 5 -or $Dia -eq 6) { 
                $HoraFin = "23:59"
                $minutosFin = (23 * 60) + 59
                $TipoDia = "Viernes/Sábado"
                $Descripcion = "Vie/Sab - Siempre hasta 23:59"
            } elseif ($Dia -ge 0 -and $Dia -le 4) { 
                if ($Mes -ge 3 -and $Mes -le 12) { 
                    $HoraFin = "22:30"
                    $minutosFin = (22 * 60) + 30
                    $TipoDia = "Dom-Jue (Mar-Dic)"
                    $Descripcion = "Dom-Jue de Mar-Dic: hasta 22:30"
                } else { 
                    $HoraFin = "23:59"
                    $minutosFin = (23 * 60) + 59
                    $TipoDia = "Dom-Jue (Ene-Feb)"
                    $Descripcion = "Dom-Jue de Ene-Feb: hasta 23:59"
                }
            }
            
            $minutosActual = ($Now.Hour * 60) + $Now.Minute
            
            $apagar = $false
            $motivo = ""
            
            if ($minutosActual -lt $minutosInicio) {
                $apagar = $true
                $motivo = "antes de las 09:00"
            } elseif ($minutosActual -gt $minutosFin) {
                $apagar = $true
                $motivo = "después de las $HoraFin"
            }
            
            $hacerLog = ($MinutoActual -eq 0) -or ($ultimoLogHora -ne $Now.Hour)
            
            if ($apagar) {
                $mensaje = "APAGANDO - Fuera de horario. $Descripcion - $motivo (Actual: $Hora)"
                Write-Log $mensaje
                Write-Log "Ejecutando shutdown..."
                
                Write-Host $mensaje -ForegroundColor Red
                
                Start-Sleep -Seconds 3
                
                try {
                    $process = Start-Process -FilePath "shutdown" -ArgumentList "/s /f /t 0 /c `"Apagado automático por horario. $Descripcion`"" -Wait -PassThru -NoNewWindow
                    Write-Log "Comando shutdown ejecutado. Código de salida: $($process.ExitCode)"
                } catch {
                    Write-Log "ERROR al ejecutar shutdown: $_"
                }
                
                exit
            } else {
                if ($hacerLog) {
                    Write-Log "Monitor activo. Dentro de horario: $Hora ($Descripcion)"
                    $ultimoLogHora = $Now.Hour
                }
            }
            
            Start-Sleep -Seconds 60
            
        } catch {
            Write-Log "ERROR en loop: $_"
            Write-Log "Detalles: $($_.Exception.Message)"
            Write-Log "StackTrace: $($_.ScriptStackTrace)"
            Start-Sleep -Seconds 300
        }
    }
}

if ($Test) {
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    MODO PRUEBA - DIAGNÓSTICO COMPLETO" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $Now = Get-Date
    $Hora = $Now.ToString("HH:mm")
    $DiaNum = [int]$Now.DayOfWeek
    $DiaNombre = $Now.DayOfWeek
    $Mes = $Now.Month
    $MesNombre = $Now.ToString("MMMM")
    
    Write-Host "FECHA Y HORA ACTUAL:" -ForegroundColor Yellow
    Write-Host "  Fecha: $($Now.ToString('dd/MM/yyyy'))"
    Write-Host "  Hora: $Hora"
    Write-Host "  Día: $DiaNombre (Número: $DiaNum)"
    Write-Host "   0=Domingo, 1=Lunes, 2=Martes, 3=Miércoles, 4=Jueves, 5=Viernes, 6=Sábado"
    Write-Host "  Mes: $MesNombre (Número: $Mes)"
    Write-Host ""
    
    $HoraInicio = "09:00"
    $minutosInicio = 9 * 60
    
    if ($DiaNum -eq 5 -or $DiaNum -eq 6) { 
        $HoraFin = "23:59"
        $minutosFin = (23 * 60) + 59
        $TipoDia = "Viernes/Sábado"
        $Temporada = "Todo el año"
        $Descripcion = "Siempre hasta 23:59"
    } elseif ($DiaNum -ge 0 -and $DiaNum -le 4) { 
        if ($Mes -ge 3 -and $Mes -le 12) { 
            $HoraFin = "22:30"
            $minutosFin = (22 * 60) + 30
            $TipoDia = "Domingo a Jueves"
            $Temporada = "Marzo a Diciembre"
            $Descripcion = "Hasta 22:30"
        } else { 
            $HoraFin = "23:59"
            $minutosFin = (23 * 60) + 59
            $TipoDia = "Domingo a Jueves"
            $Temporada = "Enero a Febrero"
            $Descripcion = "Hasta 23:59"
        }
    }
    
    Write-Host "CONFIGURACIÓN APLICADA:" -ForegroundColor Yellow
    Write-Host "  Tipo de día: $TipoDia"
    Write-Host "  Temporada: $Temporada"
    Write-Host "  Descripción: $Descripcion"
    Write-Host "  Horario permitido: $HoraInicio - $HoraFin"
    Write-Host ""
    
    $minutosActual = ($Now.Hour * 60) + $Now.Minute
    
    Write-Host "CÁLCULOS:" -ForegroundColor Yellow
    Write-Host "  Minutos desde medianoche: $minutosActual"
    Write-Host "  Minutos inicio (09:00): $minutosInicio"
    Write-Host "  Minutos fin ($HoraFin): $minutosFin"
    Write-Host "  Diferencia con inicio: $($minutosActual - $minutosInicio) minutos"
    Write-Host "  Diferencia con fin: $($minutosFin - $minutosActual) minutos"
    Write-Host ""
    
    Write-Host "RESULTADO:" -ForegroundColor Yellow
    if ($minutosActual -lt $minutosInicio) {
        Write-Host "  FUERA DE HORARIO (antes de las 09:00)" -ForegroundColor Red
        Write-Host "  El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
        Write-Host "  Motivo: Faltan $($minutosInicio - $minutosActual) minutos para las 09:00" -ForegroundColor Red
    } elseif ($minutosActual -gt $minutosFin) {
        Write-Host "  FUERA DE HORARIO (después de las $HoraFin)" -ForegroundColor Red
        Write-Host "  El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
        Write-Host "  Motivo: Pasaron $($minutosActual - $minutosFin) minutos desde las $HoraFin" -ForegroundColor Red
    } else {
        Write-Host "  DENTRO DE HORARIO PERMITIDO" -ForegroundColor Green
        Write-Host "  El PC NO se apagaría" -ForegroundColor Green
        $minutosRestantes = $minutosFin - $minutosActual
        Write-Host "  Tiempo restante: $($minutosRestantes) minutos (hasta las $HoraFin)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "VERIFICACIÓN DE INSTALACIÓN:" -ForegroundColor Yellow
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "  Tarea '$TaskName' instalada" -ForegroundColor Green
        Write-Host "  Estado: $($task.State)" -ForegroundColor Cyan
    } else {
        Write-Host "  Tarea '$TaskName' NO instalada" -ForegroundColor Red
        Write-Host "  Ejecuta: .\ShutdownManager.ps1 -Install" -ForegroundColor Yellow
    }
    
    if (Test-Path $ScriptPath) {
        Write-Host "  Script encontrado en: $ScriptPath" -ForegroundColor Green
    } else {
        Write-Host "  Script NO encontrado en: $ScriptPath" -ForegroundColor Red
    }
    
    exit
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   SHUTDOWN MANAGER - Control de Horarios" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "UBICACIONES:" -ForegroundColor Yellow
Write-Host "  Script: $ScriptPath"
Write-Host "  Log: $LogPath"
Write-Host "  Tarea: $TaskName"
Write-Host ""
Write-Host "PARÁMETROS DISPONIBLES:" -ForegroundColor Yellow
Write-Host "  -Install     Instalar como tarea programada (requiere Admin)"
Write-Host "  -Uninstall   Eliminar la tarea programada"
Write-Host "  -Run         Ejecutar el monitor manualmente"
Write-Host "  -Test        Modo diagnóstico (recomendado para probar)"
Write-Host ""
Write-Host "HORARIOS CONFIGURADOS:" -ForegroundColor Yellow
Write-Host "  Domingo a Jueves:"
Write-Host "     • Marzo a Diciembre: 09:00 - 22:30"
Write-Host "     • Enero y Febrero: 09:00 - 23:59"
Write-Host "  Viernes y Sábado:"
Write-Host "     • Todo el año: 09:00 - 23:59"
Write-Host ""
Write-Host "RECOMENDACIÓN:" -ForegroundColor Green
Write-Host "  Primero prueba con: .\ShutdownManager.ps1 -Test" -ForegroundColor Cyan
Write-Host "  Luego instala con: .\ShutdownManager.ps1 -Install" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para monitorear el log en tiempo real:" -ForegroundColor Yellow
Write-Host "  Get-Content '$LogPath' -Wait" -ForegroundColor Cyan
