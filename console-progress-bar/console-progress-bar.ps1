# This file must be save has UTF-8 with BOM !
Clear-Host

# Save the current console foreground color
$SAVED_FOREGROUND = [console]::ForegroundColor;
# Set console output to UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8;

function showDuration($totalseconds){
    $hours   = [Math]::floor(($totalseconds /3600))
    $minutes = [Math]::floor(($totalseconds - $hours*3600)/60)
    $seconds = [Math]::floor(($totalseconds - ($hours*3600 + $minutes*60)));
    $hours   = ([string]$hours).PadLeft(2, '0')
    $minutes = ([string]$minutes).PadLeft(2, '0')
    $seconds = ([string]$seconds).PadLeft(2, '0')
    Write-Host -ForegroundColor Blue $("[+] Finished in {0}:{1}:{2}{3}" -f @($hours, $minutes, $seconds, [System.Environment]::NewLine))
}


function showProgress($PercentComplete, $Status, $total, $CursorTop, $ProgressColor='Blue'){
    
    $percent = [System.Math]::Ceiling($PercentComplete/$total*100) 
    $n = $PercentComplete/$total*50

    [console]::ForegroundColor = $SAVED_FOREGROUND
    [console]::SetCursorPosition(2,$CursorTop)
    [console]::Write($("{0}{1}" -f @($Status, $(' '*($Host.UI.RawUI.BufferSize.Width - $Status.length)))))
    [console]::SetCursorPosition(2,$CursorTop+1)
    [console]::ForegroundColor = $ProgressColor
    [console]::Write($("{0}{1}" -f  @($('―'*$n), $(' '*(50-$n)), $percent)))
    [console]::ForegroundColor = $SAVED_FOREGROUND
    [console]::SetCursorPosition(2+$n+(50-$n)+2,$CursorTop+1)
    [console]::Write($("{0}/100%" -f  @($percent)))    
    [Console]::Out.Flush()

    if($percent -eq 100){
        [console]::SetCursorPosition(2,$CursorTop)
        [console]::Write($("{0}{1}" -f @('Finished', $(' '*($Host.UI.RawUI.BufferSize.Width - 'Finished'.length)))))
        [console]::ForegroundColor = $SAVED_FOREGROUND
        [console]::WriteLine([System.Environment]::NewLine)
        [console]::WriteLine([System.Environment]::NewLine)
    }    
}

function Main(){

  $start_time = Get-Date
  
  # Can be $myobj.Count
  $total = 10000;

  # Get the cursor position before call showProgress(), this is where funciton start to write in console
  $top = [console]::CursorTop+2
  $i = 1;
  for($n = 0; $n -lt $total; $n++){
    # Call the function in your loop
    showProgress -PercentComplete $i -Status $("item:{0}" -f @($n)) -total $total -CursorTop $top
    $i++
  }

  # showProgress() display 2 returns cariage after finished, now ignore it 
  $top = [console]::CursorTop
  $i = 1;
  # ... other loop

  showDuration -totalseconds $($(Get-Date)-$start_time).TotalSeconds
  
}

Main
