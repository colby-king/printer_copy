Param ([Parameter(mandatory=$true)][string] $CopyFrom)


$printers = Get-Printer -ComputerName $CopyFrom

$ipregex = "\b((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\.|$)){4}\b"


$printers = $printers
$ports = Get-PrinterPort -Name $printers.PortName -ComputerName "WINESSNSPRD04" | 
         Select Name, DeviceUrl, Port, PortMonitor, Description | 
         Sort-Object -Property PortMonitor


$printers | Add-Member DriverAdded $false
$printers | Add-Member PortAdded $false
$printers | Add-Member PrinterAdded $false
$printers | Add-Member Errors "" 

$drivers = $printers | Select DriverName -Unique



# function to add WSD printer... Not currently supported in the script 
function addWSDPrinter{
    param($name, $url)
    $ip = ($url  |  Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value
    if($ip -match $ipregex){
        $existingPort = Get-PrinterPort $name -ErrorAction SilentlyContinue
        if(-not $existingPort){
            try{
                Add-Printer -Name $name -DeviceURL $url -ErrorAction Stop
                $p = Get-Printer | Where DeviceUrl -eq $url
                # Add this to correct add printer name mis-assignment
                $n = $p.Name 
                Rename-Printer -Name $n -NewName $name 
            } catch {
                Write-Host -BackgroundColor DarkRed "Could not create WSD Printer $name"
                return $Error[0]
            }
        } else {
            Write-Host "WSD Port $name already exists"
        }
    } else {
        return "Invalid IP $ip parsed from Device URL: $name"
    }
}

function addIPPrinter{
    param($name, $driver, $port, $portPrefix)
    $portname = ($portPrefix + $port)
    try{
        Add-Printer -Name $name -DriverName $driver -PortName $portname -ErrorAction Stop
    } catch {
        Write-Host -BackgroundColor DarkRed "Could not create printer $name"
        return $Error[0]
    }
}

function addTCPPrinterPort {
    param($name, $namePrefix)
    $portname = ($namePrefix + $name)
    $ip = ($name  |  Select-String -Pattern "\d{1,3}(\.\d{1,3}){3}" -AllMatches).Matches.Value
    if($ip -match $ipregex){
        try{
            Add-PrinterPort -Name $portname -PrinterHostAddress $ip -ErrorAction Stop
        } catch {
            Write-Host -BackgroundColor DarkRed "Could not create port $g $ip"
            Write-Host $Error[0]
            return $Error[0]
        }
    } else {
        return "Invalid IP $ip parsed from port $name"
    }

}


function addPrinterDriver {
    param($name)
    try{
        Add-PrinterDriver $name -ErrorAction Stop
    } catch {
        Write-Host -BackgroundColor DarkRed "Could not install driver: $name"
        return $Error[0]
    }
}

$PORT_PREFIX = "IP:"


# Add printer Drivers
ForEach($p in $printers){
    $existingDriver = Get-PrinterDriver | Where Name -eq $p.DriverName
    if(-not $existingDriver){
        $err = addPrinterDriver $p.DriverName
        if($err){
            $p.DriverAdded = $false
            $p.Errors += $err
        } else {
            $p.DriverAdded = $true
        }
    } else {
        $p.DriverAdded = $true
    }
}


# Add the IP Ports
ForEach($p in $printers){
    # Parse the IP address
    $port = $ports | where Name -like $p.PortName
    $portname = $port.Name
    
    # Proceed if it's an IP printer and its
    if($port -and $p.DriverAdded -and $port.PortMonitor -eq "TCPMON.DLL"){
        $portCheck = ($PORT_PREFIX + $portname)
        $existingPort = Get-PrinterPort $portCheck -ErrorAction SilentlyContinue
        if(-not $existingPort){
            $err = addTCPPrinterPort $portname $PORT_PREFIX
            if($err){
                $p.PortAdded = $false
                $p.Errors += $err
            } else {
                $p.PortAdded = $true
            }
         } else {
            $p.PortAdded = $true
         }   
    }
}

# Add the Printers 
ForEach($p in $printers){
    if($p.PortAdded -and $p.DriverAdded){
        $err = addIPPrinter $p.Name $p.DriverName $p.PortName $PORT_PREFIX
        if($err){
            $p.PrinterAdded = $false
            $p.Errors += $err
        } else {
            $p.PrinterAdded = $true
        }
    }
}


# Add the WSD Printers
#ForEach($p in $printers){
#    $port = $ports | where Name -like $p.PortName
#    if($port -and $port.PortMonitor -eq "WSD Port Monitor"){
#        $err = addWSDPrinter $port.Name $port.DeviceUrl
#        if($err){
#            $p.PortAdded = $false 
#            $p.Errors += $err
#            Write-Host $err
#        } else {
#            $p.PortAdded = $true
#            $p.PrinterAdded = $true
#        }
#    }
#}


# Return the printers object
$printers 