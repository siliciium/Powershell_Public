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
$verbose = $false;


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

function Forge($mDNS_ans){
    $pkt = [System.Collections.ArrayList]@()
    $mDNS_ans.Values | %{
        $pkt.AddRange($_)
    }
    return $pkt;
}

function Set_IP([string]$ip, [bool]$IPv6=$false){
    $b_ip = [System.Net.IPAddress]::Parse($ip).GetAddressBytes() 
    $b_iplen = [System.BitConverter]::GetBytes([System.Convert]::ToUInt16($b_ip.Length))    
    [Array]::Reverse($b_iplen) # network order big-endian

    $mDNS_ans.IP = $b_ip
    $mDNS_ans.IPLen = $b_iplen
}

function Get_QName([byte[]]$MDNS_Name){
    $know_total_len = $MDNS_Name.Count;
    $total_len = 0
    $offset = 0;
    $name = @()
    while($total_len -ne $know_total_len){

            $bl  = $MDNS_Name[$offset];
            $len = $offset+$bl
            $offset += 1;

            $datas = [System.Text.Encoding]::Ascii.getstring( $MDNS_Name[$offset..$len] )
            $total_len += $datas.Length +1

            $name += $datas

            $offset = $total_len;
    }

    return $name -join "."
}

function Get_QType([byte[]]$pkt){

    $p0 = [byte[]](0x00, 0x1c, 0x00, 0x01) # Type AAAA
    $p1 = [byte[]](0x00, 0x01, 0x00, 0x01) # Type A
    $p2 = [byte[]](0x00, 0xff, 0x00, 0x01) # Type ANY

    $b = [byte[]]($pkt[($pkt.Length-4)..$pkt.Length])

    if($(Compare-Object -ReferenceObject $b -DifferenceObject $p0).Count -eq 0){
        return "AAAA"
    }elseif($(Compare-Object -ReferenceObject $b -DifferenceObject $p1).Count -eq 0){
        return "A"
    }elseif($(Compare-Object -ReferenceObject $b -DifferenceObject $p2).Count -eq 0){
        return "ANY"
    }
    return ""

}


function mDNSServer($mDNS_ans){

    $rx_pkt = [byte[]]::new(512)
    
    if($ipv6_enabled){
        $remoteEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::IPv6Any, 0)
    }else{
        $remoteEP = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Any, 0)
    }

    while ($true)
    {

        Write-Host -ForegroundColor White "Waiting for multicast packets......."

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

            if($verbose){
                $i = 0;
                foreach($b in $rx_pkt){
                    if($i -lt $rb){
                        Write-Host -NoNewline -ForegroundColor DarkGray $("{0} " -f $b.ToString("X2"))                
                    }
                    $i++
                }
                Write-Host
            }

            $rx_pkt_truncated = [System.Collections.ArrayList]@()
            for($i=12; $i -lt $rb; $i++){
                $rx_pkt_truncated.AddRange([byte[]]@($rx_pkt[$i])) 
            }        

            $qtype = Get_QType -pkt $rx_pkt_truncated;

            if([string]::Equals($qtype, "AAAA") -and !$ipv6_enabled){
                Write-Host -ForegroundColor DarkCyan "Question [AAAA] ignored (no IPv6 addr)"
                continue;
            }


            $b_qname = [System.Collections.ArrayList]@()
            for($i=12; $i -lt $rb-5; $i++){
                $b_qname.AddRange([byte[]]@($rx_pkt[$i])) 
            }

            Write-Host -ForegroundColor Magenta $("Question [{0}] {1}" -f @($qtype, $(Get_QName -MDNS_Name $b_qname)))
            
            $mDNS_ans.AnswerName = $b_qname

            switch($qtype){
                "A" { 
                    $mDNS_ans.Type = [byte[]](0x00, 0x01)
                    Set_IP -ip $ipv4
                    break;
                }
                "AAAA" {
                    $mDNS_ans.Type = [byte[]](0x00, 0x1c)
                    Set_IP -ip $ipv6 -IPv6 $true
                    break;
                }
                default { break; }
            }


            $ans = Forge -mDNS_ans $mDNS_ans;  
            do{

                $sb = $mcastSocket.SendTo($ans, $ep)                

                Write-Host -ForegroundColor Blue $("Transmit {0} byte(s) {1}:{2} ➔  {3}:{4}" -f @($sb, $src, $remoteEP.Port, $grp, $ep.Port)) 
                if($verbose){       
                    Write-host -ForegroundColor DarkGray $(($ans|ForEach-Object ToString X2) -join ' ')
                }

                Start-Sleep -Milliseconds 5
            
            }while($sb -ne $ans.Length)

        

        }else{
            Write-Host -ForegroundColor DarkCyan "AnswerRRS (ignored)"
        }
        
    }
}

try{
    mDNSServer -mDNS_ans $mDNS_ans
}catch{
    Write-Host -ForegroundColor Red $_
}finally{
    
    try{
        $mcastSocket.Close()
        $mcastSocket.Dispose()
    }catch{}

    Write-Host -ForegroundColor Green "$([System.Environment]::NewLine)mDNS server stopped !"
}
