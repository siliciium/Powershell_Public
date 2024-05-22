<#
Original work by Siliciium

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
#>
Clear-Host
# mDNS Querier
$mcastPort = 5353
$mcast4Addr = [System.Net.IPAddress]::Parse("224.0.0.251")
$mcast6Addr = [System.Net.IPAddress]::Parse("ff02::fb")

$mDNS_QM = [ordered]@{
    "TID"            = [byte[]]@(0x00, 0x00); # Transaction id
    "Flags"          = [byte[]]@(0x00, 0x00); # Flags
    "Question"       = [byte[]]@(0x00, 0x01); # Question
    "AnswerRRS"      = [byte[]]@(0x00, 0x00); # AnswerRRS
    "AuthorityRRS"   = [byte[]]@(0x00, 0x00); # AuthorityRRS
    "AdditionalRRS"  = [byte[]]@(0x00, 0x00); # AdditionalRRS
    "AnswerName"     = [byte[]]@(0x00);       # AnswerName
    "AnswerNameNull" = [byte[]]@(0x00);       # AnswerNameNull
    "Type"           = [byte[]]@(0x00, 0x01); # Type
    "Class"          = [byte[]]@(0x00, 0x01); # Class
}

$mDNS_Type = @{
    "A"    = [byte[]](0x00, 0x01);
    "AAAA" = [byte[]](0x00, 0x1c);
    "ANY"  = [byte[]](0x00, 0xff);
}

function Set_QName($mDNS_QM, [string]$qname){

    $pkt = [System.Collections.ArrayList]@()

    $labels = $qname.Split(".");

    $labels | ForEach-Object {
        $len = [System.Convert]::ToByte($_.Length) # 8 bits
        $b   = [System.Text.Encoding]::Ascii.GetBytes($_)              
        $pkt.Add($len)
        $pkt.AddRange($b)
    }

    $mDNS_QM.AnswerName = $pkt
    return $mDNS_QM
}

function Set_QType($mDNS_QM, [string]$qtype){
    switch ($qtype) {
        "A"    { $mDNS_QM.Type = $mDNS_Type.A ; break }
        "AAAA" { $mDNS_QM.Type = $mDNS_Type.AAAA ; break}
        "ANY"  { $mDNS_QM.Type = $mDNS_Type.ANY ; break}
        Default { break }
    }
    return $mDNS_QM
}

function Forge($mDNS_QM){
    $pkt = [System.Collections.ArrayList]@()
    $mDNS_QM.Values | %{
        $pkt.AddRange($_)
    }
    return $pkt;
}

function Get_QType([byte[]]$pkt){

    $b = [byte[]]($pkt[($pkt.Length-4)..$pkt.Length])

    if($(Compare-Object -ReferenceObject $b -DifferenceObject $mDNS_Type.AAAA).Count -eq 0){
        return "AAAA"
    }elseif($(Compare-Object -ReferenceObject $b -DifferenceObject $mDNS_Type.A).Count -eq 0){
        return "A"
    }elseif($(Compare-Object -ReferenceObject $b -DifferenceObject $mDNS_Type.ANY).Count -eq 0){
        return "ANY"
    }
    return ""

}

function ParseAns([byte[]]$pkt, [bool]$dump){

    $mDNS_ans = [ordered]@{}
    $mDNS_ans.TID           = $pkt[0..1]
    $mDNS_ans.Flags         = $pkt[2..3]
    $mDNS_ans.Question      = $pkt[4..5]
    $mDNS_ans.AnswerRRS     = $pkt[6..7]
    $mDNS_ans.AuthorityRRS  = $pkt[8..9]
    $mDNS_ans.AdditionalRRS = $pkt[10..11]

    $labels = @()

    $offset = 12
    do{

        $len = $pkt[$offset];
        if($len -ne 0x00){
            $offset += 1
            $labels += [System.Text.Encoding]::ASCII.GetString( $pkt[$offset..($offset+($len-1))] )
            $offset += $len
        }

    }while($len -ne 0x00)

    $mDNS_ans.AnswerName = $labels -join "."
    $mDNS_ans.AnswerNameNull = $pkt[($offset)]

    $btype = $pkt[($offset+1)..($offset+2)]
    if($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.AAAA).Count -eq 0){
        $mDNS_ans.Type = "AAAA"
    }elseif($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.A).Count -eq 0){
        $mDNS_ans.Type = "A"
    }elseif($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.ANY).Count -eq 0){
        $mDNS_ans.Type = "ANY"
    }
    
    $mDNS_ans.Class = $pkt[($offset+3)..($offset+4)]


    $ttl = $pkt[($offset+5)..($offset+8)]
    [array]::Reverse($ttl);
    $ttl = [bitconverter]::ToUInt32($ttl, 0)
    $mDNS_ans.TTL = $ttl

    $mDNS_ans.IPLen = $pkt[($offset+9)..($offset+10)]
    $iplen = $pkt[($offset+9)..($offset+10)]
    [array]::Reverse($iplen);
    $iplen = [bitconverter]::ToUInt16($iplen, 0)

    $mDNS_ans.IP = [System.Net.IPAddress]::new($pkt[($offset+11)..($offset+11+$iplen)]).IPAddressToString

    if($dump){
        foreach($key in $mDNS_ans.Keys){
            
            if($mDNS_ans[$key].GetType().Name -ne "String" -and $mDNS_ans[$key].GetType().Name -ne "UInt32"){
                Write-Host "$([string]($key).PadRight(14)) : $(($mDNS_ans[$key]|ForEach-Object ToString X2) -join ' ')"
            }else{
                Write-Host "$([string]($key).PadRight(14)) : $($mDNS_ans[$key])"
            }
        }
    }

    return $mDNS_ans

}


function mDNS_cli($mDNS_QM, [string]$qname, [string]$qtype, [switch]$IPv6, [switch]$verbose, [switch]$dump){

    if($IPv6.IsPresent){
        $UdpClient = New-Object System.Net.Sockets.UdpClient([System.Net.Sockets.AddressFamily]::InterNetworkV6)
    }else{
        $UdpClient = New-Object System.Net.Sockets.UdpClient
    }

    $UdpClient.Client.Blocking = $false
    $UdpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    
    if($IPv6.IsPresent){        
        $UdpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive, 255)
        $mcast6Option = New-Object System.Net.Sockets.IPv6MulticastOption $mcast6Addr
        $UdpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::AddMembership, $mcast6Option)
        $local_ep6 = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::IPv6Any, $mcastPort)
        $UdpClient.Client.Bind($local_ep6)
        $remote_ep = New-Object System.Net.IPEndPoint ($mcast6Addr, $mcastPort)
    }else{                
        $UdpClient.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive, 255)
        $local_ep4 = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, $mcastPort)
        $UdpClient.Client.Bind($local_ep4)
        $UdpClient.JoinMulticastGroup($mcast4Addr)
        $remote_ep = New-Object System.Net.IPEndPoint ($mcast4Addr, $mcastPort)
    }


    $mDNS_QM = Set_QType -mDNS_QM $mDNS_QM -qtype $qtype
    $mDNS_QM = Set_QName -mDNS_QM $mDNS_QM -qname $qname    
    $mDNS_QM = Forge -mDNS_QM $mDNS_QM

    
    do{
        $sb = $UdpClient.Send($mDNS_QM, $mDNS_QM.Length, $remote_ep)

        Write-Host -ForegroundColor Magenta $("Question [{0}] {1}" -f @($qtype.ToUpper(), $qname))
        if($verbose.IsPresent){
            Write-Host -ForegroundColor Blue $("Transmit {0} byte(s) local ➔ {1}:{2}" -f @($sb, $remote_ep.Address.IPAddressToString, $remote_ep.Port))        
            Write-host -ForegroundColor DarkGray $(($mDNS_QM|ForEach-Object ToString X2) -join ' ')
        }

    }while($sb -ne $mDNS_QM.Length)

    if($verbose.IsPresent){
        Write-Host -ForegroundColor DarkGray "Waiting for response..."
    }

    $isAns = $false
    $isValidType = $false
    $isValidName = $false
    do{        
        while($UdpClient.Available -eq 0){
            Start-Sleep -Milliseconds 10
        }
        $pkt = $UdpClient.Receive([ref]$local_ep4)

        if(($pkt[7] -eq 0x01)){
            $isAns = $true
        
            $mDNS_ans = ParseAns -pkt $pkt -dump $dump.IsPresent

            if([String]::Equals($qtype, $mDNS_ans.Type)){
                $isValidType = $true
            }

            if([String]::Equals($qname, $mDNS_ans.AnswerName)){
                $isValidName = $true
            }
            
            Write-Host -ForegroundColor Magenta $("{0} {1} {2} (TTL:{3})" -f @($mDNS_ans.AnswerName, $mDNS_ans.Type, $mDNS_ans.IP, $mDNS_ans.TTL))
            if($verbose.IsPresent){
                Write-host -ForegroundColor DarkGray $(($pkt|ForEach-Object ToString X2) -join ' ')
            }
        }

    }while(-not $isAns -and -not $isValidType -and -not $isValidName)

    $UdpClient.Close()

}


try{
    #mDNS_cli -mDNS_QM $mDNS_QM -qname "test.local" -qtype "A" -verbose # -verbose -dump
    mDNS_cli -mDNS_QM $mDNS_QM -qname $("{0}.local" -f $env:COMPUTERNAME) -qtype "A" -IPv6 #-verbose -dump
}catch{
    Write-Host -ForegroundColor Red $_
}finally{
    $UdpClient.Close()
    $UdpClient.Dispose()
}
