<#
    If you work with Visual Studio Code on Linux and you are 
    already connected to github , you can get your token with :

    # Get git extension askpass file path
    ──(user@linux)-[~] export GIT_TRACE=1
    ──(user@linux)-[~] export GIT_TRACE_PACKET=1

    #! In visual studio terminal :
    ──(user@linux)-[~] cd your_git_project_folder
    ──(user@linux)-[~] cp /usr/share/code/resources/app/extensions/git/dist/askpass.sh askpass.sh
    ──(user@linux)-[~] bash askpass.sh 'Username for '\''https://github.com'\'': ' 
    A_NUMBER
    ──(user@linux)-[~] bash askpass.sh 'Password for '\''https://A_NUMBER@github.com'\'': '
    gh_TOKEN_
#>



$config = @{
    "git.username"    = "";
    "git.oauth_token" = "";
}


$github_api = "https://api.github.com";


function makeAPIreq($method, $uri, $body=$null, $ret_headers=$false){
    $headers = @{
        "Authorization" = $("token {0}" -f @($config["git.oauth_token"]))
        "Content-Type"  = "application/json";
        "Accept"        = "application/vnd.github.v3+json";
    }

    if ($null -ne $body){
        $body = $($body|ConvertTo-Json)
    }

    try{
        Write-Host -ForegroundColor yellow $("{0} {1}" -f @($method.ToUpper(), $uri))
        if ($null -ne $body){
            $r = $(Invoke-WebRequest -Uri $uri -Method $method -Headers $headers -Body $body)
        }else{
            $r = $(Invoke-WebRequest -Uri $uri -Method $method -Headers $headers)
        }

        if($ret_headers){
            return @($r.Headers)
        }else{
            return $($r.Content | ConvertFrom-Json)
        }

        
    }catch{
        Write-Host -ForegroundColor Red $_
    }

    return $null
}

function tokenInfos(){

    <#
        Make simple GET request to /user endpoint to get HTTP headers
        containing token informations
    #>

    $uri = $("{0}/user" -f @($github_api))  

    $headers = $(makeAPIreq -method "Get" -uri $uri -debug $true -ret_headers $true)

    return @{ 
        "OAuth-Scopes"          = $headers["X-OAuth-Scopes"]; 
        "Accepted-OAuth-Scopes" = $headers["X-Accepted-OAuth-Scopes"];
        "oauth-client-id"       = $headers["x-oauth-client-id"];
        "RateLimit-Limit"       = $headers["X-RateLimit-Limit"];
        "RateLimit-Remaining"   = $headers["X-RateLimit-Remaining"];
        "RateLimit-Reset"       = $headers["X-RateLimit-Reset"];
        "RateLimit-Used"        = $headers["X-RateLimit-Used"];
        "RateLimit-Resource "   = $headers["X-RateLimit-Resource"];
    }

}

function userInfos(){

    $uri = $("{0}/user" -f @($github_api))  

    return $(makeAPIreq -method "Get" -uri $uri)

}

function newRepo($repo_name){
    <#
        https://docs.github.com/en/rest/guides/getting-started-with-the-rest-api
    #>
    
    $uri = $("{0}/user/repos" -f @($github_api))   

    $body = @{
        "name"      = $repo_name;
        "auto_init" = $true;
        "private"   = $true;
    }
    
    return $(makeAPIreq -method "Post" -uri $uri -body $body)
}

function newIssue($repo_name, $title, $body, $assignees=@(), $labels=@()){
    <#
        https://docs.github.com/en/rest/reference/issues#create-an-issue
    #>
    
    $uri = $("{0}/repos/{1}/{2}/issues" -f @($github_api, $config["git.username"], $repo_name))    

    $body = @{
        "title"     = $title;
        "body"      = $body;
        "assignees" = $assignees;
        "labels"    = $labels;
        #"milestone" = $milestone;        
    }
    
    return $(makeAPIreq -method "Post" -uri $uri -body $body)
}

function delRepo($repo_name){
    <#
        https://docs.github.com/rest/reference/repos#delete-a-repository
        token 'delete_repo' scope is required but vscode git extension not have this scope
    #>

    $uri = $("{0}/repos/{1}/{2}" -f @($github_api, $config["git.username"], $repo_name))
    
    $delete = $false

    while ($true){
        Write-Host -NoNewLine -ForegroundColor yellow $("Are you sure you want to delete your repository {0} [yes/no] > " -f @($repo_name))
        $c = Read-Host
        if ([string]::Equals($c, "yes")){
            $delete = $true
            break
        }elseif ([string]::Equals($c, "no")){
            break
        }
    }

    if ($delete){        
        return $(makeAPIreq -method "Delete" -uri $uri) 
    }

    return $null
}

function Main(){
    tokenInfos | Format-Table
    # newRepo -repo_name "myrepo" | Format-List
    # userInfos | Format-List
    # newIssue -repo_name "myrepo" -title "Found a bug" -body "I'm having a problem with this." -assignees @($config["git.username"]) -labels @("bug") | Format-List
    # delRepo -repo_name "myrepo" | Format-List
}

Main
