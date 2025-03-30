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
			[string[]]$Paths
		)
	process {
		$Processed = 0;
		$SearchDepth = 10;
		$Descriptors = Get-ChildItem -Path ${Paths} -Depth $SearchDepth | Get-ChildItem -Filter "descriptor.json";
		$Descriptors | % {$ParseDepth = 10;
      $ObjectFile = Get-Content $_.FullName | ConvertFrom-Json;
      $ObjectFile.Descriptor.ModifiedOnUtc = $ObjectFile.Descriptor.ModifiedOnUtc.AddSeconds(1);
      $ObjectFile | ConvertTo-Json -Depth $ParseDepth | Set-Content $_.FullName;
      Write-Host "Processed ${_.FullName}";
      ++$Processed
    };
	}
}

Export-ModuleMember -Function Invoke-BpmLoadFromFS, Invoke-BpmLoadToFS, Invoke-BpmBuild, Invoke-BpmRestart, Invoke-BpmBuildAndRestart, Invoke-BpmLoadFromFSAndBuildAndRestart, Set-BpmCredentials, Invoke-BpmLogin, Update-BpmDescriptors, Invoke-BpmClearRedis;