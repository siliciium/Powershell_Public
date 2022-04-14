Clear-Host
$twitch_oauth_endpoint = "https://id.twitch.tv/oauth2";

<#
    https://dev.twitch.tv/console/
#>
$config = @{
    "cli_id"       = "";
    "cli_secret"   = "";
    "redirect_uri" = ""; 
    "scopes"       = @(
        "user:read:follows";
        "user:manage:blocked_users";
        "user:read:blocked_users";
        "chat:read";
        "chat:edit";
        "channel:moderate";
        # ...
    );
    "creds_file"   = ".twitch_creds.json";
}


function AuthorizationGrantFlow(){

    <#
        https://dev.twitch.tv/docs/authentication/getting-tokens-oauth#authorization-code-grant-flow
        This Auth flow also return refresh_token
    #>

    $obj = $null;

    <#
        This return a Code
    #>

    $params = @{
        "client_id"     = $config.cli_id;
        "redirect_uri"  = $config.redirect_uri;
        "force_verify"  = $true;
        "response_type" = "code";
        "scope"         = $($config.scopes -join "+")
    }

    $sparams = ""
    foreach($key in $params.Keys){
        $sparams += $("{0}={1}&" -f @($key, $params[$key]))
    }
    $sparams = $sparams.Substring(0, $sparams.Length-1)

    $uri = $("https://id.twitch.tv/oauth2/authorize?{0}" -f @($sparams));

    Write-Host -ForegroundColor Yellow $("- Copier/Coller cette URL dans un navigateur WEB :{0}" -f @([System.Environment]::NewLine));
    Write-Host -ForegroundColor Yellow $("{0}{1}" -f @($uri, [System.Environment]::NewLine));

    while ($true){
        Write-Host -NoNewline -ForegroundColor Yellow "Veuillez entrer le code obtenu > "
        $code = Read-Host
        if(-not [string]::IsNullOrEmpty($code)){
            if($code.Length -eq 30){
                break
            }
        }
    }


    <#
        Exchange code for access token
    #>

    $body = @{
        "client_id"     = $config.cli_id;
        "client_secret" = $config.cli_secret; 
        "code"          = $code;
        "grant_type"    = "authorization_code";
        "redirect_uri"  = $config.redirect_uri;  
    }

    $uri = $("{0}/token" -f @($twitch_oauth_endpoint));

    try{
        $r = $(Invoke-WebRequest -Method Post -Uri $uri -Body $body -ErrorAction Stop);                

        if($r.StatusCode -eq 200){
            $obj =  $($r.Content | ConvertFrom-Json);
        }   

    }catch{
        $err = $($_.ErrorDetails | ConvertFrom-Json)
        $("[{0}] {1}" -f @($err.status, $err.message)) | Write-Host -ForegroundColor Red;        
    }

    return $obj;
}

function InfosToken($token, $check_expire=$false){

    <#
        https://dev.twitch.tv/docs/authentication/validate-tokens
    #>
        
    $obj     = $null;
    $expired = $true;

    if(-not [string]::IsNullOrEmpty($token)){
        $headers = @{
            "Client-Id"     = $config.cli_id;
            "Authorization" = $("Bearer {0}" -f @($token));        
        }

        $uri = $("{0}/validate" -f @($twitch_oauth_endpoint));

        try{
            $r = $(Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -ErrorAction Stop);                

            if($r.StatusCode -eq 200){
                $obj =  $($r.Content | ConvertFrom-Json); 

                if($check_expire){
                    if($obj.expires_in -ge (60 * 15)){ # valid for >= 15 min
                        $expired = $false;
                    }
                }
            }               

        }catch{
            $err = $($_.ErrorDetails | ConvertFrom-Json)
            $("[{0}] {1}" -f @($err.status, $err.message)) | Write-Host -ForegroundColor Red;        
        }
    }

    if($check_expire){
        return $expired
    }else{
        return $obj;
    }
}

function RevokeTokens($tokens=@()){

    <#
        https://dev.twitch.tv/docs/authentication/revoke-tokens
    #>

    $total = $tokens.Length;
    $i = 0;

    foreach($token in $tokens){
        if(-not [string]::IsNullOrEmpty($token)){  
            
            $tokenInfos = InfosToken($token)
            if($null -ne $tokenInfos){                                

                $body = @{
                    "client_id" = $tokenInfos.client_id;
                    "token"     = $token;
                }

                $uri = $("{0}/revoke" -f @($twitch_oauth_endpoint));
                
                try{
                    Write-Host -NoNewline -f Yellow $("[{0}/{1}] Revoking {2} : " -f @(($i+1), $total, $token));
                    $r = $(Invoke-WebRequest -Uri $uri -Method Post -Body $body);

                    if($r.StatusCode -eq 200){
                        Write-Host -f Green $("SUCCESS")
                    }else{
                        Write-Host -f Red $("ERROR")
                    }                    
                }catch{
                    $_ | Write-Host -f Red 
                }
            }
            
        }
        $i++;
    }
    
}

function RefreshToken($refresh_token, $older_token=$null){

    <#
        https://dev.twitch.tv/docs/authentication/refresh-tokens
    #>

    $obj = $null;

    $body = @{
        "client_id"     = $config.cli_id;
        "client_secret" = $config.cli_secret; 
        "refresh_token" = $refresh_token;
        "grant_type"    = "refresh_token";
        "scope"         = $($config.scopes -join " ");
    }

    $uri = $("{0}/token" -f @($twitch_oauth_endpoint));

    try{
        $r = $(Invoke-WebRequest -Method Post -Uri $uri -Body $body -ErrorAction Stop);                

        if($r.StatusCode -eq 200){
            $obj =  $($r.Content | ConvertFrom-Json);
        }   

    }catch{
        $err = $($_.ErrorDetails | ConvertFrom-Json)
        $("[{0}] {1}" -f @($err.status, $err.message)) | Write-Host -ForegroundColor Red;        
    }

    if($null -ne $older_token){
        RevokeTokens(@($older_token))
    }

    return $obj;    
}

function SaveToJson($token, $check_exists=$true){

    $overwrite = $false;

    if($check_exists){
        if([System.IO.File]::Exists($config.creds_file)){

            while ($true){
                Write-Host -NoNewline -ForegroundColor Yellow $("Le fichier {0} existe déjà, voulez-vous le remplacer [y/n] > " -f @($config.creds_file))
                $choice = Read-Host
                if(-not [string]::IsNullOrEmpty($choice)){
                    if([string]::Equals($choice, "y")){
                        $overwrite = $true;
                        break
                    }elseif([string]::Equals($choice, "n")){
                        break
                    }
                }
            }       

        }else{
            $overwrite = $true;
        }
    }else{
        $overwrite = $true;
    }

    if($overwrite){
        $($tokenInfos | ConvertTo-Json -Depth 10) | Out-File -FilePath $config.creds_file -Encoding utf8 -Confirm:$false -Force
    }
    
}

function ReadJsonToken(){
    if([System.IO.File]::Exists($config.creds_file)){
        return $(Get-Content -Path $config.creds_file -Encoding UTF8 | ConvertFrom-Json)
    }else{
        Write-Host -ForegroundColor Red $("{0} n'existe pas." -f @($config.creds_file))
    }

    return $null
}

function Main(){

    $token = $(AuthorizationGrantFlow);
    if($null -ne $token){

        # Display new token
        $token | Format-List

        # Save the token into json file
        # SaveToJson -token $token.access_token

        # Read Token from json file
        # $json_token = $(ReadJsonToken)
        # if($null -ne $json_token){
        #     $json_token | Format-List
        # }

    }

    <# $tokenInfos = $(InfosToken -token $token.access_token);
    if($null -ne $tokenInfos){
        $tokenInfos | Format-List
    } #>

    <# $tokenIsExpired = $(InfosToken -token $token.access_token -check_expire $true);
    if(-not $tokenIsExpired){
        Write-Host -ForegroundColor Yellow "Jeton valide."
    }else{
        Write-Host -ForegroundColor Red "Jeton expiré."
    } #>
    
    <# $refreshedToken  = $(RefreshToken -refresh_token $token.refresh_token -older_token $token.access_token);
    if($null -ne $refreshedToken){
        $refreshedToken | Format-List
    } #>

    #RevokeTokens -tokens @($token.access_token)

}

Main
