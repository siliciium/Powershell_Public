**USAGE**  
- mDNS must be enable on Windows (enabled by default)  
- Configure variable `$interface` with your own network inerface name.  
  You can get all your interfaces with `PS> Get-NetAdapter` 

*Note :  
You can run the script into Visual Code and use `CTRL+C` to stop the responder.  
Responder only responds to types `A` and `AAAA`.*  

**TEST**  
`PS> Resolve-DnsName test.local`

**UTIL**  
```
netsh interface ipv4 show joins
netsh interface ipv6 show joins
Resolve-DnsName mdns.mcast.net (IANA reserved) 
```

**REFERENCES**  
https://www.rfc-editor.org/rfc/rfc6762.html
