Clear-Host

#
# Epic Launcher Log file must contain : 
# LogWebView: UPDATE 
# or
# LogWebView: [Social User] Friends Updated: Added
#


$filePath = $("{0}\EpicGamesLauncher\Saved\Logs\EpicGamesLauncher.log" -f @($env:LOCALAPPDATA));
$out_JSON  = $("C:\Users\{0}\Desktop\EpicList.json" -f @($env:USERNAME));
$out_XLSX = $("C:\Users\{0}\Desktop\EpicList.xlsx" -f @($env:USERNAME));


$global:matches_availables   = $false
$global:friends_availables   = $false
$global:collection_available = $false
$global:EPICS                = @()
$global:debug                = $true
$global:fileformat           = "excel" #json or excel
$global:EXPORT               = $true
$global:FRIENDS_REQUEST_NOT_ACCEPTED =  @()
$global:METHOD               = 1




function setCellsColor($worksheet, $index, $color=-4142){
    $worksheet.Cells.Item($index,1).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,2).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,3).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,4).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,5).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,6).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,7).Interior.ColorIndex = $color
    $worksheet.Cells.Item($index,8).Interior.ColorIndex = $color
}


function toExcel($debug=$false){

    try{

        $excelPidsBefore = @(
            Get-Process -ErrorAction Ignore EXCEL | Select-Object -ExpandProperty Id
        )

        $excel = New-Object -ComObject excel.application
        $excel.visible = $false
        $excel.DisplayAlerts = $false;

        $excelComPid = Compare-Object -PassThru $excelPidsBefore (Get-Process -ErrorAction Ignore EXCEL).Id

        if([System.IO.File]::Exists($out_XLSX)){    
            $workbook  = $Excel.Workbooks.Open($out_XLSX)
            $worksheet = $workbook.Worksheets.Item('EpicGames') 
            $worksheet2 = $workbook.Worksheets.Item('Pending')            
        }else{
            $workbook = $excel.Workbooks.Add() 
            $workbook.Worksheets.Add() | Out-Null            
            $worksheet = $workbook.Worksheets.Item(1)

            $worksheet.Name = 'EpicGames'            
            $worksheet.Cells.Item(1,1) = 'EpicId'
            $worksheet.Cells.Item(1,2) = 'EpicName'
            $worksheet.Cells.Item(1,3) = 'Xbox'
            $worksheet.Cells.Item(1,4) = 'Playstation'
            $worksheet.Cells.Item(1,5) = 'Steam'
            $worksheet.Cells.Item(1,6) = 'Nintendo'
            $worksheet.Cells.Item(1,7) = 'Date'
            $worksheet.Cells.Item(1,8) = 'Removed'

            for($n=0; $n -lt 8; $n++){
                $worksheet.Cells.Item(2, $n+1) = " "
            }            

            $workbook.Worksheets.Add() | Out-Null
            $worksheet2 = $workbook.Worksheets.Item(2) 

            $worksheet2.Name = 'Pending'
            $worksheet2.Cells.Item(1,1) = 'EpicId'
            $worksheet2.Cells.Item(1,2) = 'EpicName'
            $worksheet2.Cells.Item(1,3) = 'Xbox'
            $worksheet2.Cells.Item(1,4) = 'Playstation'
            $worksheet2.Cells.Item(1,5) = 'Steam'
            $worksheet2.Cells.Item(1,6) = 'Nintendo'
            $worksheet2.Cells.Item(1,7) = 'Date'

            for($n=0; $n -lt 7; $n++){
                $worksheet2.Cells.Item(2, $n+1) = " "
            }

        }
        
        foreach($epic in $global:EPICS){

            $index = -1;
            for($i = 3; $i -lt $worksheet.UsedRange.Rows.Count+1; $i++){
                if($worksheet.Cells.Item($i,1).Text -eq $epic.epicid){
                    $index = $i;
                    break;
                }
            }

            if($index -ne -1){
                # UPDATE EXISTING
                if($debug){
                    $sindex = $index;
                    if($index -lt 10){
                        $sindex =$("0{0}" -f @($sindex))
                    }
                    Write-Host -ForegroundColor DarkYellow $("[EXCEL][UPDATE][{0}][{1}] {2}:{3}" -f@($sindex, $epic.epicid, $epic.epicname))  
                }
                $worksheet.Cells.Item($index,2) = $epic.epicname
                $worksheet.Cells.Item($index,3) = $epic.xbox
                $worksheet.Cells.Item($index,4) = $epic.playstation
                $worksheet.Cells.Item($index,5) = $epic.steam
                $worksheet.Cells.Item($index,6) = $epic.nintendo
                $worksheet.Cells.Item($index,8) = ""

                setCellsColor -worksheet $worksheet -index $index

            }else{
                # INSERT NEW
                $last_index = $worksheet.UsedRange.Rows.Count + 1
                if($debug){
                    $sindex = $last_index;
                    if($last_index -lt 10){
                        $sindex =$("0{0}" -f @($last_index))
                    }
                    Write-Host -ForegroundColor DarkBlue $("[EXCEL][INSERT][{0}][{1}] {2}:{3}" -f@($worksheet.name, $sindex, $epic.epicid, $epic.epicname))            
                }

                $worksheet.Cells.Item($last_index,1) = $epic.epicid
                $worksheet.Cells.Item($last_index,2) = $epic.epicname
                $worksheet.Cells.Item($last_index,3) = $epic.xbox
                $worksheet.Cells.Item($last_index,4) = $epic.playstation
                $worksheet.Cells.Item($last_index,5) = $epic.steam
                $worksheet.Cells.Item($last_index,6) = $epic.nintendo
                $worksheet.Cells.Item($last_index,7) = $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            }

        }


        $start_index = 3;
        foreach($epicuser in $global:FRIENDS_REQUEST_NOT_ACCEPTED){
                        
            # INSERT NEW

            if($global:METHOD -eq 1){
                
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
            }elseif($global:METHOD -eq 2){
                
                $epic = @{
                    "epicid" = "";
                    "epicname" = "";
                    "xbox" = "";
                    "playstation" = "";
                    "steam" = "";
                    "nintendo" = "";
                }

                $epicuser.payload[0].entity.id
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
            }
            
            if($debug){                
                Write-Host -ForegroundColor DarkBlue $("[EXCEL][INSERT][{0}][{1}] {2}:{3}" -f@($worksheet2.name, $start_index, $epic.epicid, $epic.epicname))            
            }            

            $worksheet2.Cells.Item($start_index,1) = $epic.epicid
            $worksheet2.Cells.Item($start_index,2) = $epic.epicname
            $worksheet2.Cells.Item($start_index,3) = $epic.xbox
            $worksheet2.Cells.Item($start_index,4) = $epic.playstation
            $worksheet2.Cells.Item($start_index,5) = $epic.steam
            $worksheet2.Cells.Item($start_index,6) = $epic.nintendo
            $worksheet2.Cells.Item($start_index,7) = $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
            
            $start_index++
        }


        Write-Host -ForegroundColor Blue 'Please wait while verifying deleted friends...'
        for($index = 3; $index -lt $worksheet.UsedRange.Rows.Count+1; $index++){

            $exists_in_friends_list = $false;
            foreach($epic in $global:EPICS){
                if([string]::Equals($worksheet.Cells.Item($index,1).Text, $epic.epicid)){
                    $exists_in_friends_list = $true;
                    break;
                }
            }

            if(-not $exists_in_friends_list){
                $worksheet.Cells.Item($index,8) = $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
                setCellsColor -worksheet $worksheet -index $index -color 34
            }

        }


    }finally{
        # Format, save and quit excel
        $workbook.Worksheets.Item('Feuil1').Delete()
        $worksheet.UsedRange.EntireColumn.AutoFit() | Out-Null                                                                                              
        $worksheet2.UsedRange.EntireColumn.AutoFit() | Out-Null 
        $workbook.SaveAs($out_XLSX)
        $workbook.Close($false)
        $excel.Quit()

        Stop-Process -Id $excelComPid -Confirm:$false -PassThru | Out-Null

        Remove-Variable -Name excel
    }
    

}


function display_friends_request_not_accepted(){
    if($global:FRIENDS_REQUEST_NOT_ACCEPTED.Length -gt 0){

        Write-Host -ForegroundColor Magenta $("Friends requests not accepted ({0})" -f $($global:FRIENDS_REQUEST_NOT_ACCEPTED.Length))

        if($global:METHOD -eq 1){

            foreach($epic in $global:FRIENDS_REQUEST_NOT_ACCEPTED){  
                                        
                $dname = $epic.value.displayName;
                if([string]::IsNullOrEmpty($dname)){
                    if($epic.value.externalAuths.Length -gt 0){
                        foreach($ext in $epic.value.externalAuths){
                            if(-not [string]::IsNullOrEmpty($ext.value.displayName)){
                                $dname = $ext.value.displayName
                                break;
                            }
                        }
                    }
                }

                Write-Host -ForegroundColor DarkMagenta $("{0} - {1}" -f @($epic.value.id, $dname))
            }

        }elseif($global:METHOD -eq 2){

            foreach($epic in $global:FRIENDS_REQUEST_NOT_ACCEPTED){  
                                        
                $dname = $epic.payload[0].entity.displayName;
                if([string]::IsNullOrEmpty($dname)){
                    if($epic.payload[0].entity.externalAuths.Length -gt 0){
                        foreach($ext in $epic.payload[0].entity.externalAuths){
                            if(-not [string]::IsNullOrEmpty($ext.payload[0].entity.displayName)){
                                $dname = $ext.payload[0].entity.displayName
                                break;
                            }
                        }
                    }
                }

                Write-Host -ForegroundColor DarkMagenta $("{0}" -f @($dname))
            }

        }
    } 
 
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
                                        
                                        if([String]::Equals($epicuser.value.type, "accepted")){

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
                                        
                                        }elseif([String]::Equals($epicuser.value.type, "outgoing")){                                            
                                            $global:FRIENDS_REQUEST_NOT_ACCEPTED += $epicuser; 
                                        }elseif([String]::Equals($epicuser.payload[0].entity.type, "incoming")){
                                            # Not implemented 
                                        }
                                        
                                    }
                                    
                                }
                            }
                        }
                    }else{
                        $_matches0 = [regex]::match($_, "LogWebView: \[Social User\] Friends Updated: Added (.*)$")

                        if($_matches0.Length -gt 0){

                            $global:METHOD = 2

                            $global:matches_availables = $true;

                            if($_matches0.Groups[0].Value -match 'friends' ){

                                $global:friends_availables = $true;  
                                $global:collection_available = $true                  

                                $json = $_matches0.Groups[0].Value.Replace('LogWebView: [Social User] Friends Updated: Added ', '')  
                                $json = "{ `"friends`" :"  + $json + "}" | ConvertFrom-Json

                                $already_proc = $true;

                                foreach($epicuser in $json.friends){     
                                    
                                    if([String]::Equals($epicuser.payload[0].entity.type, "accepted")){

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

                                    }elseif([String]::Equals($epicuser.payload[0].entity.type, "outgoing")){
                                        $global:FRIENDS_REQUEST_NOT_ACCEPTED += $epicuser; 
                                    }elseif([String]::Equals($epicuser.payload[0].entity.type, "incoming")){
                                        # Not implemented 
                                    }

                                    
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

                    Write-Host -ForegroundColor DarkBlue "Number of Epic friends : $($already_proc.Count)"
                }
                
                display_friends_request_not_accepted
                
                if($global:EXPORT){
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
        }

    }else{
        Write-Host -ForegroundColor Red $("ERROR: Unable to find {0}" -f @($filePath))
    }
}

Main
