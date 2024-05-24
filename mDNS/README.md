# Multicast DNS (mDNS) responder

**USAGE**  
- mDNS must be enable on Windows (enabled by default)  
- Configure variable `$interface` with your own network interface name.  
  You can get all your interfaces with `PS> Get-NetAdapter` 

*Note :  
Responder listen on `IPv4` and , if available, on `IPv6`.  
Responder only responds to `Question` types `A` and `AAAA` and ignore `AnswerRR`.  
You can run the script into Visual Code and use `CTRL+C` to stop the responder.*  

**FUNCTION**  
```
$nipv6 = [System.Net.IPAddress]::Parse("XX.X.X.XX")  
$nipv6 = [System.Net.IPAddress]::Parse("XXXX::XXXX:XXXX:XXXX:XXXX")  
mDNS_responder -nipv4 $nipv4 -nipv6 $nipv6 -verbose #-flush_cache_bit
```

**TEST**  
```
PS> Resolve-DnsName test.local  
Name                                           Type   TTL   Section    IPAddress
----                                           ----   ---   -------    ---------
test.local                                     AAAA   120   Answer     XXXX::XXXX:XXXX:XXXX:XXXX
test.local                                     A      120   Answer     XX.X.X.XX
```


**UTIL**  
```
netsh interface ipv4 show joins
netsh interface ipv6 show joins
Resolve-DnsName mdns.mcast.net (IANA reserved) 
```


    
# Multicast DNS (mDNS) querier

**USAGE**  
  IPv4 
  ```
  mDNS_querier -qname "test.local" -qtype "A"
  ```  
  IPv6
  ```
  mDNS_querier -qname "test.local" -qtype "A" -IPv6
  ```

*Note :  
Switch availables : `-verbose` ,`-dump` and `-IPv6`  
Only `one record` of type `A` or `AAAA` is supported.  
You can run the script into Visual Code and use `CTRL+C` to stop the responder.*    
  
**EXAMPLE**  
Using `-dump` switch  
```
Question [A] test.local
TID            : 00 00
Flags          : 84 00
Question       : 00 00
AnswerRRS      : 00 01
AuthorityRRS   : 00 00
AdditionalRRS  : 00 00
AnswerName     : test.local
AnswerNameNull : 00
Type           : A
Class          : 00 01
TTL            : 60
IPLen          : 00 04
IP             : 10.0.0.15
test.local A 10.0.0.15 (TTL:60)
```

  
**REFERENCES**  
https://www.rfc-editor.org/rfc/rfc6762.html  
