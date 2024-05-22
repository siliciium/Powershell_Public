# Multicast DNS (mDNS) responder

**USAGE**  
- mDNS must be enable on Windows (enabled by default)  
- Configure variable `$interface` with your own network interface name.  
  You can get all your interfaces with `PS> Get-NetAdapter` 

*Note :  
Responder listen on `IPv4` and , if available, on `IPv6`.  
Responder only responds to `Question` types `A` and `AAAA` and ignore `AnswerRR`.  
You can run the script into Visual Code and use `CTRL+C` to stop the responder.*  

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
Only one record of type `A` or `AAAA` is supported.  
You can run the script into Visual Code and use `CTRL+C` to stop the responder.*    
  
  
**REFERENCES**  
https://www.rfc-editor.org/rfc/rfc6762.html  
