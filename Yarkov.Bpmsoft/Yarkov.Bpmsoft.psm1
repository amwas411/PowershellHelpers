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

function Invoke-BpmCompile {
  process {
    Invoke-BpmLogin | Invoke-BpmBuild | Invoke-BpmRestart > $null;
  }
}

function Invoke-BpmUpgrade {
  process {
    Invoke-BpmLogin | Invoke-BpmLoadFromFS | Invoke-BpmBuild | Invoke-BpmRestart > $null;
  }
}

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