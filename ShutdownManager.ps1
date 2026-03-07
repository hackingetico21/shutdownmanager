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
            
            $HoraInicio = "09:00"
            
            if ($Dia -eq 5 -or $Dia -eq 6) { 
                $HoraFin = "23:59"
                $TipoDia = "Viernes/Sábado"
            } elseif ($Dia -ge 0 -and $Dia -le 4) { 
                if ($Mes -ge 3 -and $Mes -le 12) { 
                    $HoraFin = "22:30"
                    $TipoDia = "Dom-Jue (Mar-Dic)"
                } else { 
                    $HoraFin = "23:59"
                    $TipoDia = "Dom-Jue (Ene-Feb)"
                }
            }
            
            $minutosActual = ($Now.Hour * 60) + $Now.Minute
            $minutosInicio = 9 * 60
            $partesFin = $HoraFin.Split(':')
            $minutosFin = ([int]$partesFin[0] * 60) + [int]$partesFin[1]
            
            $apagar = $false
            $motivo = ""
            
            if ($minutosActual -lt $minutosInicio) {
                $apagar = $true
                $motivo = "antes de las 09:00"
            } elseif ($minutosActual -gt $minutosFin) {
                $apagar = $true
                $motivo = "después de las $HoraFin"
            }
            
            if ($apagar) {
                $mensaje = "APAGADO - Fuera de horario. $TipoDia - $motivo. Límite:$HoraFin Actual:$Hora"
                Write-Log $mensaje
                Write-Log "Ejecutando shutdown..."
                
                Start-Sleep -Seconds 2
                
                shutdown /s /f /t 0 /c "Apagado automático por horario. $TipoDia: 09:00-$HoraFin"
                
                exit
            } else {
                if ($Now.Minute -eq 0) {
                    Write-Log "Monitor activo. Dentro de horario: $Hora ($TipoDia: 09:00-$HoraFin)"
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
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    MODO PRUEBA - No se apagará" -ForegroundColor Cyan
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
    Write-Host "  Día: $DiaNombre (Número: $DiaNum - 0=Dom, 1=Lun, 2=Mar, 3=Mie, 4=Jue, 5=Vie, 6=Sab)"
    Write-Host "  Mes: $MesNombre (Número: $Mes)"
    Write-Host ""
    
    $HoraInicio = "09:00"
    
    if ($DiaNum -eq 5 -or $DiaNum -eq 6) { 
        $HoraFin = "23:59"
        $TipoDia = "Viernes/Sábado"
        $Temporada = "Todo el año"
    } elseif ($DiaNum -ge 0 -and $DiaNum -le 4) { 
        if ($Mes -ge 3 -and $Mes -le 12) { 
            $HoraFin = "22:30"
            $TipoDia = "Domingo a Jueves"
            $Temporada = "Marzo a Diciembre"
        } else { 
            $HoraFin = "23:59"
            $TipoDia = "Domingo a Jueves"
            $Temporada = "Enero a Febrero"
        }
    }
    
    Write-Host "CONFIGURACIÓN:" -ForegroundColor Yellow
    Write-Host "  Tipo de día: $TipoDia"
    Write-Host "  Temporada: $Temporada"
    Write-Host "  Horario permitido: 09:00 - $HoraFin"
    Write-Host ""
    
    $minutosActual = ($Now.Hour * 60) + $Now.Minute
    $minutosInicio = 9 * 60
    $partesFin = $HoraFin.Split(':')
    $minutosFin = ([int]$partesFin[0] * 60) + [int]$partesFin[1]
    
    Write-Host "CÁLCULOS:" -ForegroundColor Yellow
    Write-Host "  Minutos actuales: $minutosActual"
    Write-Host "  Minutos inicio: $minutosInicio"
    Write-Host "  Minutos fin: $minutosFin"
    Write-Host ""
    
    Write-Host "RESULTADO:" -ForegroundColor Yellow
    if ($minutosActual -lt $minutosInicio) {
        Write-Host "  ESTADO: FUERA DE HORARIO (antes de las 09:00)" -ForegroundColor Red
        Write-Host "  Acción: El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
    } elseif ($minutosActual -gt $minutosFin) {
        Write-Host "  ESTADO: FUERA DE HORARIO (después de las $HoraFin)" -ForegroundColor Red
        Write-Host "  Acción: El PC SE APAGARÍA INMEDIATAMENTE" -ForegroundColor Red
    } else {
        Write-Host "  ESTADO: DENTRO DE HORARIO PERMITIDO" -ForegroundColor Green
        Write-Host "  Acción: El PC NO se apagaría" -ForegroundColor Green
    }
    
    exit
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   SHUTDOWN MANAGER - Control de Horarios" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ubicación: $ScriptPath"
Write-Host "Tarea programada: $TaskName"
Write-Host ""
Write-Host "PARÁMETROS:" -ForegroundColor Yellow
Write-Host "  -Install     Instalar como tarea programada"
Write-Host "  -Uninstall   Eliminar la tarea programada"
Write-Host "  -Run         Ejecutar el monitor (solo manual)"
Write-Host "  -Test        Modo prueba (verifica sin apagar)"
Write-Host ""
Write-Host "HORARIOS CONFIGURADOS:" -ForegroundColor Yellow
Write-Host "  Domingo a Jueves:"
Write-Host "     - Marzo a Diciembre: 09:00 - 22:30"
Write-Host "     - Enero y Febrero: 09:00 - 23:59"
Write-Host "  Viernes y Sábado:"
Write-Host "     - Todo el año: 09:00 - 23:59"
Write-Host ""
Write-Host "CARACTERÍSTICAS:" -ForegroundColor Yellow
Write-Host "  Se ejecuta al iniciar Windows"
Write-Host "  Verifica cada 60 segundos"
Write-Host "  Apagado inmediato fuera de horario"
Write-Host "  Log en: $LogPath"
Write-Host "  Modo prueba para verificar configuración"
Write-Host ""
Write-Host "EJEMPLOS DE USO:" -ForegroundColor Yellow
Write-Host "  # Instalar (requiere Administrador)"
Write-Host "  .\ShutdownManager.ps1 -Install"
Write-Host ""
Write-Host "  # Probar configuración actual"
Write-Host "  .\ShutdownManager.ps1 -Test"
Write-Host ""
Write-Host "  # Ver estado de la tarea"
Write-Host "  Get-ScheduledTask -TaskName `"$TaskName`""
Write-Host ""
Write-Host "  # Ver log"
Write-Host "  Get-Content `"$LogPath`" -Wait"
Write-Host ""
Write-Host "NOTA: Requiere permisos de administrador para instalar" -ForegroundColor Yellow
