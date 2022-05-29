Clear-Host

#
# Epic Launcher Log file must contain : 
# LogWebView: UPDATE 
# or
# LogWebView: [Social User] Friends Updated: Added


$filePath = $("{0}\EpicGamesLauncher\Saved\Logs\EpicGamesLauncher.log" -f @($env:LOCALAPPDATA));
$out_JSON  = $("C:\Users\{0}\Desktop\EpicList.json" -f @($env:USERNAME));
$out_XLSX = $("C:\Users\{0}\Desktop\EpicList.xlsx" -f @($env:USERNAME));


$global:matches_availables   = $false
$global:friends_availables   = $false
$global:collection_available = $false
$global:datas_written        = $false
$global:EPICS                = @()
$global:debug                = $true
$global:fileformat           = "excel" #json or excel

function toExcel($debug=$false){
    $excel = New-Object -ComObject excel.application
    $excel.visible = $false
    $excel.DisplayAlerts = $false;

    if([System.IO.File]::Exists($out_XLSX)){
        $workbook = $Excel.Workbooks.Open($out_XLSX)
        $Data= $workbook.Worksheets.Item(1)
    }else{
        $workbook = $excel.Workbooks.Add() 
        $workbook.Worksheets.Add() | Out-Null
        $Data= $workbook.Worksheets.Item(1)
        $Data.Name = 'MySpreadsheet'
        $Data.Cells.Item(1,1) = 'EpicId'
        $Data.Cells.Item(1,2) = 'EpicName'
        $Data.Cells.Item(1,3) = 'Xbox'
        $Data.Cells.Item(1,4) = 'Playstation'
        $Data.Cells.Item(1,5) = 'Steam'
        $Data.Cells.Item(1,6) = 'Nintendo'

        for($n=0; $n -lt 6; $n++){
            $Data.Cells.Item(2,$n+1) = " "
        }
        
    }

    foreach($epic in $global:EPICS){

        $index = -1;
        for($i = 3; $i -lt $Data.UsedRange.Rows.Count+1; $i++){
            if($Data.Cells.Item($i,1).Text -eq $epic.epicid){
                $index = $i;
                break;
            }
        }

        if($index -ne -1){
            # UPDATE EXISTING
            if($debug){
                Write-Host -ForegroundColor DarkYellow $("[EXCEL][UPDATE] {0}:{1}" -f@($epic.epicid, $epic.epicname))  
            }
            $Data.Cells.Item($index,2) = $epic.epicname
            $Data.Cells.Item($index,3) = $epic.xbox
            $Data.Cells.Item($index,4) = $epic.playstation
            $Data.Cells.Item($index,5) = $epic.steam
            $Data.Cells.Item($index,6) = $epic.nintendo
        }else{
            # INSERT NEW
            $last_index = $Data.UsedRange.Rows.Count + 1
            if($debug){
                Write-Host -ForegroundColor DarkBlue $("[EXCEL][INSERT][{0}] {1}:{2}" -f@($last_index, $epic.epicid, $epic.epicname))            
            }

            $Data.Cells.Item($last_index,1) = $epic.epicid
            $Data.Cells.Item($last_index,2) = $epic.epicname
            $Data.Cells.Item($last_index,3) = $epic.xbox
            $Data.Cells.Item($last_index,4) = $epic.playstation
            $Data.Cells.Item($last_index,5) = $epic.steam
            $Data.Cells.Item($last_index,6) = $epic.nintendo
        }

    }
    
    # Format, save and quit excel
    $usedRange = $Data.UsedRange                                                                                              
    $usedRange.EntireColumn.AutoFit() | Out-Null
    $workbook.SaveAs($out_XLSX)
    $workbook.Close($false)
    $excel.Quit()

    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()

    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($workbook.Worksheets)
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($excel)

    Remove-Variable -Name excel
}

function Main(){
    if ([System.IO.File]::Exists($filePath)){

        Write-Host -ForegroundColor Yellow $("Using Log file : {0}" -f @($filePath))

        # WAIT WHILE FRIENDS LIST IS AVAILABLE/UPADTED
        while(-not $global:matches_availables -or -not $global:friends_availables -or -not $global:collection_available){

            # WAIT WHILE USER OPEN EPIC GAMES LAUNCHER
            $launcher_pid = $(Get-Process -Name "EpicGamesLauncher" -ErrorAction SilentlyContinue).id;
            if([string]::IsNullOrEmpty($launcher_pid)){
                write-host -ForegroundColor Yellow "WARNING ! Epic Game launcher must be opened, next check in 30 secs..."
                Start-Sleep -Seconds 30
                continue;
            } 
            
            $already_proc = $false;
            
            Get-Content -Path $filePath -Encoding UTF8 | ForEach-Object {

                    if(-not $already_proc){
                    
                    $_matches0 = [regex]::match($_, "LogWebView: UPDATE (.*)$")        

                    if($_matches0.Length -gt 0){
                        
                        $global:matches_availables = $true;

                        if($_matches0.Groups[0].Value -match 'friends' ){

                            $global:friends_availables = $true;                    

                            $json = $_matches0.Groups[0].Value.Replace('LogWebView: UPDATE ', '') | ConvertFrom-Json            

                            if(($json.PSobject.Properties.name -match "collection")){

                                $global:collection_available = $true

                                if(($json.PSobject.Properties.name -match "add")){

                                    $already_proc = $true;

                                    foreach($epicuser in $json.add){                        

                                        $epic = @{
                                            "epicid" = "";
                                            "epicname" = "";
                                            "xbox" = "";
                                            "playstation" = "";
                                            "steam" = "";
                                            "nintendo" = "";
                                        }

                                        $epic.epicid = $epicuser.id

                                        $display_name = $epicuser.value.displayName;
                                        if(-not [string]::IsNullOrEmpty($display_name)){
                                            $epic.epicname = $display_name
                                        }                                    

                                        $global:datas_written = $true
                                        if($epicuser.value.externalAuths.Count -gt 0){
                                            foreach($externalauths in $epicuser.value.externalAuths){

                                                $ex_type = $externalauths.type;
                                                $ex_name = $externalauths.displayName; 

                                                switch ($ex_type) {
                                                    'xbl' { $epic.xbox = $ex_name }
                                                    'psn' { $epic.playstation = $ex_name }
                                                    'steam' { $epic.steam = $ex_name }
                                                    'nintendo' { $epic.nintendo = $ex_name }
                                                    Default {}
                                                }                                                                                                                        

                                            }                                        
                                            
                                        }

                                        $global:EPICS += $epic
                                        
                                    }
                                    
                                }
                            }
                        }
                    }else{
                        $_matches0 = [regex]::match($_, "LogWebView: \[Social User\] Friends Updated: Added (.*)$")

                        if($_matches0.Length -gt 0){

                            $global:matches_availables = $true;

                            if($_matches0.Groups[0].Value -match 'friends' ){

                                $global:friends_availables = $true;  
                                $global:collection_available = $true                  

                                $json = $_matches0.Groups[0].Value.Replace('LogWebView: [Social User] Friends Updated: Added ', '')  
                                $json = "{ `"friends`" :"  + $json + "}" | ConvertFrom-Json

                                $already_proc = $true;

                                foreach($epicuser in $json.friends){                                

                                    $epic = @{
                                        "epicid" = "";
                                        "epicname" = "";
                                        "xbox" = "";
                                        "playstation" = "";
                                        "steam" = "";
                                        "nintendo" = "";
                                    }

                                    $epic.epicid = $epicuser.payload[0].entity.id

                                    $display_name = $epicuser.payload[0].entity.displayName;
                                    if(-not [string]::IsNullOrEmpty($display_name)){
                                        $epic.epicname = $display_name
                                    }                                    

                                    if($epicuser.payload[0].entity.externalAuths.Count -gt 0){
                                        foreach($externalauths in $epicuser.payload[0].entity.externalAuths){

                                            $ex_type = $externalauths.type;
                                            $ex_name = $externalauths.displayName; 

                                            switch ($ex_type) {
                                                'xbl' { $epic.xbox = $ex_name }
                                                'psn' { $epic.playstation = $ex_name }
                                                'steam' { $epic.steam = $ex_name }
                                                'nintendo' { $epic.nintendo = $ex_name }
                                                Default {}
                                            }                                                                                                                    

                                        }                                    

                                    }

                                    $global:EPICS += $epic
                                    
                                }

                            }
                        
                        }
                    }

                }
            }

            if(-not $global:matches_availables){
                Write-Host -ForegroundColor Yellow $("No lines containing [LogWebView: UPDATE] was found, next check in 30 secs...")
                Start-Sleep -Seconds 30
            }elseif(-not $global:friends_availables){
                Write-Host -ForegroundColor Yellow $("No lines containing [friends] was found, next check in 30 secs...")
                Start-Sleep -Seconds 30
            }elseif(-not $global:collection_available){
                Write-Host -ForegroundColor Yellow $("No data containing [collection] was found, next check in 30 secs...")
                Start-Sleep -Seconds 30
            }else{

                if($global:EPICS.Count -gt 0){
                    $already_proc = @()
                    foreach($epic in $global:EPICS){    
                        if(-not $already_proc.Contains($epic.epicid)){
                            Write-Host -ForegroundColor Blue $("{0} : {1} : {2} : {3} : {4}" -f @($epic.epicid, $epic.epicname, $epic.playstation, $epic.xbox, $epic.steam))
                        }
                        $already_proc += $epic.epicid
                    }

                    Write-Host "Nombre d'amis :$($already_proc.Count)"
                }
                
                if([string]::Equals($global:fileformat, 'json')){
                    
                    $global:EPICS | ConvertTo-Json -Depth 50 | Out-File -FilePath $out_JSON -Force -Encoding utf8 -Confirm:$false                    
                    Write-Host -ForegroundColor Green $("Exported JSON file : {0}" -f @($out_JSON))

                }elseif([string]::Equals($global:fileformat, 'excel')){
                    
                    if($global:EPICS.Count -gt 0){
                        Write-Host -ForegroundColor Blue "Please wait while creating Excel file..."
                        toExcel -debug $global:debug
                        Write-Host -ForegroundColor Green $("Exported XLSX file : {0}" -f @($out_XLSX))
                    }else{
                        Write-Host -ForegroundColor Blue "No datas to export in Excel file."
                    }

                }                                
            }        
        }

    }else{
        Write-Host -ForegroundColor Red $("ERROR: Unable to find {0}" -f @($filePath))
    }
}
Main
