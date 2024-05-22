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
# mDNS Responder

$interface = ""; # set network interface name

$ipv6_enabled = $false;
$adapter = Get-NetAdapter -ErrorAction SilentlyContinue -Name $interface;
if($adapter){
    $ipv4 = $(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex | Where-Object { $_.AddressFamily -eq 'IPv4' } | Select-Object -Property IPAddress).IPAddress
    $ipv6 = $(Get-NetIPAddress -InterfaceIndex $adapter.ifIndex | Where-Object { $_.AddressFamily -eq 'IPv6' } | Select-Object -Property IPAddress).IPAddress

    if([string]::IsNullOrEmpty($ipv4)){
        Write-Host -ForegroundColor Red "No IPv4 found on interface $interface"        
        return
    }else{
        if(-not [string]::IsNullOrEmpty($ipv6)){
            $ipv6_enabled = $true;
        }
    }
}else{
    Write-Host -ForegroundColor Red "Adapter $interface not exist" 
    Get-NetAdapter | Where-Object { $_.Status -eq 'Up' }
    return
}



$mcastPort     = 5353
$mcast4Addr    = [System.Net.IPAddress]::Parse("224.0.0.251");
$mcast6Addr    = [System.Net.IPAddress]::Parse("ff02::fb")
$localIP4Addr  = [System.Net.IPAddress]::Any
$localIP6Addr  = [System.Net.IPAddress]::IPv6Any


if($ipv6_enabled){

    # Listen on IPv6 and IPv4 using DualMode

    $mcastSocket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetworkV6, [System.Net.Sockets.SocketType]::Dgram, [System.Net.Sockets.ProtocolType]::Udp)
    $mcastSocket.Blocking = $false 
    $mcastSocket.DualMode = $true
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive, 255)
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::IPv6Only, $false)
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::MulticastInterface, [BitConverter]::GetBytes($adapter.ifIndex))

    $mcast6Option  = New-Object System.Net.Sockets.IPv6MulticastOption $mcast6Addr, $adapter.ifIndex
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IPv6, [System.Net.Sockets.SocketOptionName]::AddMembership, $mcast6Option)

    $mcast4Option  = New-Object System.Net.Sockets.MulticastOption $mcast4Addr, $localIP4Addr
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::AddMembership, $mcast4Option)

    $localEP6 = New-Object System.Net.IPEndPoint ($localIP6Addr, $mcastPort)
    $mcastSocket.Bind($localEP6)

}else{

    # Listen on IPv4 only

    $mcastSocket = New-Object System.Net.Sockets.Socket([System.Net.Sockets.AddressFamily]::InterNetwork, [System.Net.Sockets.SocketType]::Dgram, [System.Net.Sockets.ProtocolType]::Udp)
    $mcastSocket.Blocking = $false;
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::MulticastTimeToLive, 255)
    
    $localEP4 = New-Object System.Net.IPEndPoint ($localIP4Addr, $mcastPort)
    $mcastSocket.Bind($localEP4)

    $mcastOption  = New-Object System.Net.Sockets.MulticastOption $mcast4Addr, $localIP4Addr
    $mcastSocket.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::IP, [System.Net.Sockets.SocketOptionName]::AddMembership, $mcastOption)
    
}





Write-Host -ForegroundColor Green "MDNS RESPONDER STARTED !"
Write-Host -ForegroundColor Green "IPv4 Group : $($mcast4Option.Group)"
Write-Host -ForegroundColor Green "IPv4 Addr  : $($mcast4Option.LocalAddress)"
if($ipv6_enabled){
    Write-Host -ForegroundColor Green "IPv6 Group : $($mcast6Option.Group)"
    Write-Host -ForegroundColor Green "IPv6 Index : $($mcast6Option.InterfaceIndex)"
}
if(-not $ipv6_enabled){
    Write-Host -ForegroundColor Yellow "Note  : Questions [AAAA] disabled (no IPv6 addr)"   
}


$mDNS_Type = @{
    "A"    = [byte[]](0x00, 0x01);
    "AAAA" = [byte[]](0x00, 0x1c);
    "ANY"  = [byte[]](0x00, 0xff);
}

function Forge($mDNS_ans){

    $ignore = ("sAnswerName", "sType", "sIP", "iTTL")

    $pkt = [System.Collections.ArrayList]@()
    foreach($k in $mDNS_ans.Keys){
        if(-not $ignore.Contains($k)){
            $pkt.AddRange($mDNS_ans[$k])
        }
    }
    return $pkt;
}

function Set_IP($ans, [string]$ip, [bool]$IPv6=$false){
    $b_ip = [System.Net.IPAddress]::Parse($ip).GetAddressBytes() 
    $b_iplen = [System.BitConverter]::GetBytes([System.Convert]::ToUInt16($b_ip.Length))    
    [Array]::Reverse($b_iplen) # network order big-endian

    $ans.IPLen = $b_iplen    
    $ans.IP = $b_ip
    $ans.sIP = [System.Net.IPAddress]::new($b_ip).IPAddressToString
    
    return $ans
}


function Dump($ans){
       
    foreach($key in $ans.Keys){
        if($ans[$key].GetType().Name -ne "String" -and $ans[$key].GetType().Name -ne "UInt32"){
            Write-Host "$([string]($key).PadRight(14)) : $(($ans[$key]|ForEach-Object ToString X2) -join ' ')"
        }else{
            Write-Host -ForegroundColor DarkGray "$([string]($key).PadRight(14)) : $($ans[$key])"
        }
    }
}

function ParseAns([byte[]]$pkt, [bool]$dump, $type="QM"){

    <#
    $mDNS_ans = [ordered]@{
    "TID"            = [byte[]]@(0x00, 0x00); # Transaction id
    "Flags"          = [byte[]]@(0x84, 0x00); # Flags
    "Question"       = [byte[]]@(0x00, 0x00); # Question
    "AnswerRRS"      = [byte[]]@(0x00, 0x01); # AnswerRRS
    "AuthorityRRS"   = [byte[]]@(0x00, 0x00); # AuthorityRRS
    "AdditionalRRS"  = [byte[]]@(0x00, 0x00); # AdditionalRRS
    "AnswerName"     = [byte[]]@(0x00);       # AnswerName
    "AnswerNameNull" = [byte[]]@(0x00);       # AnswerNameNull
    "Type"           = [byte[]]@(0x00, 0x01); # Type
    "Class"          = [byte[]]@(0x00, 0x01); # Class
    "TTL"            = [byte[]]@(0x00, 0x00, 0x00, 0x78); # TTL 120 seconds
    "IPLen"          = [byte[]]@(0x00);       # IPLen
    "IP"             = [byte[]]@(0x00);       # IPv4 or # IPv6
    }
    #>

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

    $mDNS_ans.AnswerName = $pkt[12..$offset]
    $mDNS_ans.sAnswerName = $labels -join "."

    $btype = $pkt[($offset+1)..($offset+2)]
    $mDNS_ans.Type = $btype
    if($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.AAAA).Count -eq 0){
        $mDNS_ans.sType = "AAAA"
    }elseif($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.A).Count -eq 0){
        $mDNS_ans.sType = "A"
    }elseif($(Compare-Object -ReferenceObject $btype -DifferenceObject $mDNS_Type.ANY).Count -eq 0){
        $mDNS_ans.sType = "ANY"
    }    

    $mDNS_ans.Class = $pkt[($offset+3)..($offset+4)]

    if($dump){
        Dump -ans $mDNS_ans;
    }

    return $mDNS_ans

}



function mDNSResponder($ipv4, $ipv6, [switch]$verbose){

    $rx_pkt = [byte[]]::new(512)
    
    if($ipv6_enabled){
        $remoteEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::IPv6Any, 0)
    }else{
        $remoteEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
    }

    while ($true)
    {

        Write-Host -ForegroundColor Green "Waiting for multicast packets......."

        while($mcastSocket.Available -eq 0){            
            Start-Sleep -Milliseconds 5;
        }                

        $rb = $mcastSocket.ReceiveFrom($rx_pkt, [ref]$remoteEP);

        $src = $remoteEP.Address.IPAddressToString
        if($remoteEP.Address.IsIPv4MappedToIPv6){
            $src = $remoteEP.Address.MapToIPv4()
        }
        
        $ep = New-Object System.Net.IPEndPoint ($mcast4Addr, $mcastPort)

        if($ipv6_enabled){
            if($remoteEP.Address.IsIPv4MappedToIPv6){
                $ep = New-Object System.Net.IPEndPoint ($mcast4Addr, $mcastPort)
            }else{
                $ep = New-Object System.Net.IPEndPoint ($mcast6Addr, $mcastPort)
            }
        }

        $grp = $ep.Address.IPAddressToString
        if($ep.Address.IsIPv4MappedToIPv6){
            $grp = $ep.Address.MapToIPv4()
        }

        Write-Host -ForegroundColor Magenta $("Received {0} byte(s) {1}:{2} ➔  {3}:{4}" -f @($rb, $src, $remoteEP.Port, $grp, $ep.Port))
        
        
        # Ignore packet type AnswerRRS, proced only Question
        if(-not ($rx_pkt[7] -eq 0x01)){

            $ans = ParseAns -pkt $rx_pkt -dump $verbose.IsPresent

            $ans.Flags     = [byte[]](0x84, 0x00) # Tell to Flush Cache
            $ans.Question  = [byte[]](0x00, 0x00)
            $ans.AnswerRRS = [byte[]](0x00, 0x01)

            if([string]::Equals($ans.sType, "AAAA") -and !$ipv6_enabled){
                Write-Host -ForegroundColor DarkCyan "Question [AAAA] ignored (no IPv6 addr)"
                continue;
            }

            Write-Host -ForegroundColor Magenta $("Question [{0}] {1}" -f @($ans.sType, $ans.sAnswerName))
            

            $ttl = [byte[]]@(0x00, 0x00, 0x00, 0x78) # 120 seconds, 2mins
            $ans.TTL = $ttl
            [array]::Reverse($ttl);
            $ttl = [bitconverter]::ToUInt32($ttl, 0)
            $ans.iTTL = $ttl
            [array]::Reverse($ans.TTL);

            switch($ans.sType){
                "A" { 
                    $ans = Set_IP -ans $ans -ip $ipv4
                    break;
                }
                "AAAA" {
                    $ans = Set_IP -ans $ans -ip $ipv6 -IPv6 $true
                    break;
                }
                default { break; }
            }
            

            $bAns = Forge -mDNS_ans $ans; 

            do{

                $sb = $mcastSocket.SendTo($bAns, $ep)                

                Write-Host -ForegroundColor Blue $("Transmit {0} byte(s) {1}:{2} ➔  {3}:{4}" -f @($sb, $src, $remoteEP.Port, $grp, $ep.Port)) 
                if($verbose){
                    Dump -ans $ans       
                }

                Start-Sleep -Milliseconds 5
            
            }while($sb -ne $bAns.Length)

        

        }else{
            Write-Host -ForegroundColor DarkCyan "AnswerRRS (ignored)"
        }
        
    }
}

try{

    # Tell to not use server computer ipv4 address but use specific adress for the response
    $ipv4 = [System.Net.IPAddress]::Parse("10.0.1.15")

    mDNSResponder -ipv4 $ipv4 -ipv6 $ipv6 -verbose

}catch{
    Write-Host -ForegroundColor Red $_
}finally{
    
    try{
        $mcastSocket.Close()
        $mcastSocket.Dispose()
    }catch{}

    Write-Host -ForegroundColor Green "$([System.Environment]::NewLine)mDNS server stopped !"
}
