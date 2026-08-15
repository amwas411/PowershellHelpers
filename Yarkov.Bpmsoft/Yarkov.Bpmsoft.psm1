<#
.SYNOPSIS
Throw an error if at least one of the required environment variables were not set.
.DESCRIPTION
Required environment variables are: BPM_LOGIN, BPM_PASSWORD, BPM_URL.
.EXAMPLE
Check-BpmCredentials
#>
function Check-BpmCredentials
{
    if ($Env:BPM_LOGIN -eq $null)
    {
      throw "BPM_LOGIN was not set.";
    }
    if ($Env:BPM_PASSWORD -eq $null)
    {
      throw "BPM_PASSWORD was not set.";
    }
    if ($Env:BPM_URL -eq $null)
    {
      throw "BPM_URL was not set.";
    }
}

<#
.SYNOPSIS
Set required environment variables.
.DESCRIPTION
Required environment variables are: BPM_LOGIN, BPM_PASSWORD, BPM_URL.
.EXAMPLE
Set-BpmCredentials -Login Admin -Password Admin -Url http://localhost:5000/
#>
function Set-BpmCredentials {
  param (
    [Parameter(Mandatory)][string]  
    $Login,
    
    [Parameter(Mandatory)][string]
    $Password,

    [Parameter(Mandatory)][string]
    $Url
  )
  
  $Env:BPM_LOGIN = $Login;
  $Env:BPM_PASSWORD = $Password;
  $Env:BPM_URL = $Url.TrimEnd("/");

}

<#
.SYNOPSIS
Get session variable by calling to BPMSoft "AuthService.svc/Login" service.
.EXAMPLE
Invoke-BpmLogin
#>
function Invoke-BpmLogin {
  process {
    Check-BpmCredentials;
    $Env:BPM_URL = $Env:BPM_URL.TrimEnd("/");
    $Env:BPM_SERVICEMODELPATH = "0/ServiceModel";

    $Uri = "${Env:BPM_URL}/ServiceModel/AuthService.svc/Login";

    $Body = [PSCustomObject]@{
      UserName = $Env:BPM_LOGIN
      UserPassword = $Env:BPM_PASSWORD
    } | ConvertTo-Json;

    $Result = Invoke-WebRequest -Uri $Uri -SessionVariable "SessionVariable" -Method Post -Body $Body -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }
    $Response = $Result.Content | ConvertFrom-Json;

    if ($Response.Message -ne "") {
      throw $Response.Message;
    }

    $SessionVariable.Headers.Add("BPMCSRF", $SessionVariable.Cookies.GetCookies($Uri)["BPMCSRF"].Value);
    Write-Output $SessionVariable;
  }
}

<#
.SYNOPSIS
Upload files to BPMSoft from its "Pkg" folder.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmLoadFromFS
Invoke-BpmLogin | Invoke-BpmLoadFromFS
#>
function Invoke-BpmLoadFromFS {
  param (
      [Parameter(ValueFromPipeline)]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    $Uri = "${Env:BPM_URL}/${Env:BPM_SERVICEMODELPATH}/AppInstallerService.svc/LoadPackagesToDB";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }
    $Response = $Result.Content | ConvertFrom-Json;
    if (!$Response.success)
    {
      throw $Response.errorInfo.message;
    }

    $ErrorMessage = "";
    foreach ($e in $Response.errors)
    { 
      $ErrorMessage += "{0}{1}{2}" -f [Environment]::NewLine, $e.errorInfo.message, [Environment]::NewLine;
    }
    
    if ($ErrorMessage -ne "")
    {
      throw $ErrorMessage;
    }

    $ChangesMessage = "";
    foreach ($PackageChange in $Response.changes)
    {
      $ChangesMessage += "{0} {1}:{2}" -f $PackageChange.stateName, $PackageChange.name, [Environment]::NewLine;

      foreach ($ItemChange in $PackageChange.items)
      {
        $ChangesMessage += "{0} {1};{2}" -f $ItemChange.stateName, $ItemChange.name, [Environment]::NewLine;
      }
    }

    Write-Host $ChangesMessage;
    Write-Output $SessionVariable;
  }  
}

<#
.SYNOPSIS
Clear BPMSoft's Redis.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmClearRedis
Invoke-BpmLogin | Invoke-BpmClearRedis
#>
function Invoke-BpmClearRedis {
  param (
      [Parameter(ValueFromPipeline)]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    $Uri = "${Env:BPM_URL}/${Env:BPM_SERVICEMODELPATH}/AppInstallerService.svc/ClearRedisDb";

    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }
    $Response = $Result.Content | ConvertFrom-Json;
    if (!$Response.success)
    {
      throw $Response.errorInfo.message;
    }

    Write-Output $SessionVariable;
  }  
}

<#
.SYNOPSIS
Build BPMSoft.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmBuild
Invoke-BpmLogin | Invoke-BpmBuild
#>
function Invoke-BpmBuild {
  param (
      [Parameter(ValueFromPipeline)]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    
    $Uri = "${Env:BPM_URL}/${Env:BPM_SERVICEMODELPATH}/WorkspaceExplorerService.svc/Build";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }

    $Response = $Result.Content | ConvertFrom-Json;
    if (!$Response.success)
    {
      $ErrorMessage = "";
      foreach ($ErrorItem in $Response.errors)
      {
        $ErrorMessage += "{0};{1}" -f $ErrorItem, [Environment]::NewLine;
      }
      throw $ErrorMessage;
    }

    Write-Host $Response.message;
    Write-Output $SessionVariable;
  }
}

<#
.SYNOPSIS
Restart BPMSoft.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmRestart
Invoke-BpmLogin | Invoke-BpmRestart
#>
function Invoke-BpmRestart {
  param (
      [Parameter(ValueFromPipeline)]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }

    $Uri = "${Env:BPM_URL}/${Env:BPM_SERVICEMODELPATH}/AppInstallerService.svc/RestartApp";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }
    $Response = $Result.Content | ConvertFrom-Json;
    if (!$Response.success)
    {
      throw $Response.errorInfo.message;
    }

    Write-Output $SessionVariable;
  }
}

<#
.SYNOPSIS
Unload files from BPMSoft database to its "Pkg" folder.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmLoadToFS
Invoke-BpmLogin | Invoke-BpmLoadToFS
#>
function Invoke-BpmLoadToFS {
  param (
      [Parameter(ValueFromPipeline)]
      [Microsoft.PowerShell.Commands.WebRequestSession]
      $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }

    $Uri = "${Env:BPM_URL}/${Env:BPM_SERVICEMODELPATH}/AppInstallerService.svc/LoadPackagesToFileSystem";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    if ($Result -eq $null)
    {
      throw;
    }
    $Response = $Result.Content | ConvertFrom-Json;
    if (!$Response.success)
    {
      throw $Response.errorInfo.message;
    }

    $ChangesMessage = "";
    foreach ($PackageChange in $Response.changes)
    {
      $ChangesMessage += "{0} {1}:{2}" -f $PackageChange.stateName, $PackageChange.name, [Environment]::NewLine;

      foreach ($ItemChange in $PackageChange.items)
      {
        $ChangesMessage += "{0} {1};{2}" -f $ItemChange.stateName, $ItemChange.name, [Environment]::NewLine;
      }
    }

    Write-Host $ChangesMessage;
    Write-Output $SessionVariable;
  }
}

<#
.SYNOPSIS
Compile BPMSoft.
.DESCRIPTION
Build BPMSoft.Configuration solution and restart BPMSoft.
.EXAMPLE
Invoke-BpmCompile
#>
function Invoke-BpmCompile {
  process {
    Invoke-BpmLogin | Invoke-BpmBuild | Invoke-BpmRestart > $null;
  }
}

<#
.SYNOPSIS
Upgrade BPMSoft.
.DESCRIPTION
Load actual files from BPMSoft's Pkg folder, then build BPMSoft.Configuration solution and restart BPMSoft.
.EXAMPLE
Invoke-BpmUpgrade
#>
function Invoke-BpmUpgrade {
  process {
    Invoke-BpmLogin | Invoke-BpmLoadFromFS | Invoke-BpmBuild | Invoke-BpmRestart > $null;
  }
}

<#
.SYNOPSIS
Update all descriptors in given path recursively.
.DESCRIPTION
Add one second to unix time JSON variable "ModifiedOn" in all descriptor.json files that are located under given path.
.PARAMETER Path
Wildcard-ready path to the directory where descriptors should be updated.
.EXAMPLE
Update-BpmDescriptors -Path C:/app/BPMSoft.Configuration/Pkg/UsrPkg/Schemas/*
#>
function Update-BpmDescriptors {
	param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]$Path
		)
	process {
		$Processed = 0;
		$Descriptors = Get-ChildItem -Path ${Path} | Get-ChildItem -Filter descriptor.json
		$Descriptors | % {
      $ParseDepth = 10;
      $ObjectFile = Get-Content $_.FullName | ConvertFrom-Json;
      $ObjectFile.Descriptor.ModifiedOnUtc = $ObjectFile.Descriptor.ModifiedOnUtc.AddSeconds(1);
      $ObjectFile | ConvertTo-Json -Depth $ParseDepth | Set-Content -NoNewline $_.FullName;
      Write-Host "Processed $($_.FullName)";
      ++$Processed;
    };
    Write-Host "Processed ${Processed}";
	}
}

<#
.SYNOPSIS
Create "resource.en-US.xml" by copying "resource.ru-RU.xml" values in all files under given path.
.PARAMETER Path
Wildcard-ready path to the directory where resources should be created.
.EXAMPLE
Copy-RussianResources -Path C:/app/BPMSoft.Configuration/Pkg/UsrPkg
"C:/app/BPMSoft.Configuration/Pkg/UsrPkg" | Copy-RussianResources
#>
function Copy-RussianResources {
	param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]$Path
		)
	process {
    $Processed = 0;
		Get-ChildItem -Path ${Path}/Resources | % {
      $EngResourcePath = "$($_.FullName)/resource.en-US.xml"
      Copy-Item "$($_.FullName)/resource.ru-RU.xml" $EngResourcePath
      [xml]$EngResource = Get-Content $EngResourcePath
      $EngResource.Resources.Culture = "en-US"
      $EngResource.Save($EngResourcePath)
      Write-Host "Copied $($_.FullName)/resource.ru-RU.xml to $($_.FullName)/resource.en-US.xml";
      ++$Processed;
    }
    Write-Host "Processed ${Processed}";
	}
}

<#
.SYNOPSIS
Create "data.en-US.json" by copying "data.ru-RU.json" values in all files under given path.
.PARAMETER Path
Wildcard-ready path to the directory where localizations should be created.
.EXAMPLE
Copy-RussianData -Path C:/app/BPMSoft.Configuration/Pkg/UsrPkg
"C:/app/BPMSoft.Configuration/Pkg/UsrPkg" | Copy-RussianData
#>
function Copy-RussianData {
  param(
			[Parameter(Mandatory, ValueFromPipeline)]
			[string]$Path
		)
  process {
    $Processed = 0;
		Get-ChildItem -Path ${Path}/Data | % {
      $Directories = Get-ChildItem -ErrorAction SilentlyContinue "$($_.FullName)/Localization"
      if (! ($null -eq $Directories)) {
        Copy-Item "$($_.FullName)/Localization/data.ru-RU.json" "$($_.FullName)/Localization/data.en-US.json"
        Write-Host "Copied $($_.FullName)/Localization/data.ru-RU.json to $($_.FullName)/Localization/data.en-US.json";
        ++$Processed;
      }
      else {
        Write-Host "Skipped $($_.FullName) because it does not contain Localization folder"
      }
    }
    Write-Host "Processed ${Processed}";
  }
}

<#
.SYNOPSIS
Invoke BPMSoft's REST method.
.PARAMETER RelativeUrl
Relative url of the resource that needs to be accessed.
.PARAMETER HttpMethod
HTTP method of a request.
.PARAMETER Json
Request payload.
.PARAMETER SessionVariable
BPMSoft session variable.
.EXAMPLE
Invoke-BpmLogin | Invoke-BpmRequest -RelativeUrl rest/UsrService/GetContactName -HttpMethod Get
Invoke-BpmLogin | Invoke-BpmRequest -RelativeUrl rest/UsrService/SetContactName -HttpMethod Post -Json (@{Name="Pavel";Surname="Yarkov"} | ConvertTo-Json)
#>
function Invoke-BpmRequest {
  param (
    [Parameter(Mandatory)][string]
    $RelativeUrl,
    [Parameter(Mandatory)][string]
    $HttpMethod,
    [string]
    $Json,
    [Parameter(ValueFromPipeline)]
    [Microsoft.PowerShell.Commands.WebRequestSession]
    $SessionVariable
  )
  process {
    Check-BpmCredentials;
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    $RelativeUrl = $RelativeUrl.TrimStart("/");

    $Uri = "${Env:BPM_URL}/${RelativeUrl}";

    if (!$Json) 
    {
      Write-Host "Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method $HttpMethod";
      $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method $HttpMethod -ContentType "application/json";
    }
    else {
      Write-Host "Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method $HttpMethod -Body $Json";
      $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method $HttpMethod -Body $Json -ContentType "application/json";
    }

    if ($null -eq $Result)
    {
      throw;
    }
    $Response = $Result.Content;
    Write-Host $Response;
    Write-Output $SessionVariable;
  }
}

Export-ModuleMember -Function Invoke-BpmLoadFromFS, Invoke-BpmLoadToFS, Invoke-BpmBuild, Invoke-BpmRestart, Invoke-BpmCompile, Invoke-BpmUpgrade, Set-BpmCredentials, Invoke-BpmLogin, Update-BpmDescriptors, Invoke-BpmClearRedis, Invoke-BpmRequest, Copy-RussianResources, Copy-RussianData;