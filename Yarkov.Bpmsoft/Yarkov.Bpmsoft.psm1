$BpmAppHost = "";
$BpmLogin = "";
$BpmPassword = "";
$BpmServiceModelPath = "";

function Set-BpmCredentials {
  param (
    [Parameter(Mandatory)][string]  
    $Login,
    
    [Parameter(Mandatory)][string]
    $Password,

    [Parameter(Mandatory)][string]
    $AppHost,

    [Parameter(Mandatory)][int]
    $IsFramework
  )
  
  $Global:BpmLogin = $Login;
  $Global:BpmPassword = $Password;
  $Global:BpmAppHost = $AppHost;

  if ($IsFramework) {
    $Global:BpmServiceModelPath = "0/ServiceModel";
  } else {
    $Global:BpmServiceModelPath = "ServiceModel";
  }
}

function Invoke-BpmLogin {
  process {
    $Uri = "${BpmAppHost}/ServiceModel/AuthService.svc/Login";

    $Body = [PSCustomObject]@{
      UserName = $BpmLogin
      UserPassword = $BpmPassword
    } | ConvertTo-Json;

    $Result = Invoke-WebRequest -Uri $Uri -SessionVariable "SessionVariable" -Method Post -Body $Body -ContentType "application/json";
    $Response = $Result.Content | ConvertFrom-Json;

    if ($Response.Message -ne "") {
      Write-Error $Response.Message;
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
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    $Uri = "${BpmAppHost}/${BpmServiceModelPath}/AppInstallerService.svc/LoadPackagesToDB";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    Write-Verbose $Result.Content;
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
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }
    
    $Uri = "${BpmAppHost}/${BpmServiceModelPath}/WorkspaceExplorerService.svc/Build";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    Write-Verbose $Result.Content;
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
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }

    $Uri = "${BpmAppHost}/${BpmServiceModelPath}/AppInstallerService.svc/RestartApp";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    Write-Verbose $Result.Content;
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
    if (!$SessionVariable) {
      $SessionVariable = Invoke-BpmLogin;
    }

    $Uri = "${BpmAppHost}/${BpmServiceModelPath}/AppInstallerService.svc/LoadPackagesToFileSystem";
    $Result = Invoke-WebRequest -Uri $Uri -WebSession $SessionVariable -Method Post -ContentType "application/json";
    Write-Verbose $Result.Content;
    Write-Output $SessionVariable;
  }
}

function Invoke-BpmBuildAndRestart {
  process {
    Invoke-BpmLogin | Invoke-BpmBuild -Verbose | Invoke-BpmRestart > $null;
  }
}

function Invoke-BpmLoadFromFSAndBuildAndRestart {
  process {
    Invoke-BpmLogin | Invoke-BpmLoadFromFS -Verbose | Invoke-BpmBuild -Verbose | Invoke-BpmRestart > $null;
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
      Write-Verbose "Processed ${_.FullName}";
      ++$Processed
    };
	}
}

Export-ModuleMember -Function Invoke-BpmLoadFromFS, Invoke-BpmLoadToFS, Invoke-BpmBuild, Invoke-BpmRestart, Invoke-BpmBuildAndRestart, Invoke-BpmLoadFromFSAndBuildAndRestart, Set-BpmCredentials, Invoke-BpmLogin, Update-BpmDescriptors;
Export-ModuleMember -Variable BpmAppHost, BpmLogin, BpmPassword, BpmServiceModelPath;