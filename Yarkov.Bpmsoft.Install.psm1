function New-BpmApp {
  param (
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$ZipPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlTypeCastFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlChangeOwnerFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerName,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerPassword,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$RedisDbNumber,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$RedisPort,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$AppPort,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$DbPort,
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DockerPgContainerName
  )
  process {
    #Requires -RunAsAdministrator
    [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.ZipFile");

    $ErrorActionPreference = "Stop";
    $ProgressName = "New-BpmApp";
    
    $ZipFile = Get-Item -Path $ZipPath;
  
    if ($ZipFile.Extension -ne ".zip") {
      throw "ZipPath should be a zip archive";
    }
    
    $AppName = $ZipFile.BaseName;
    $AppPath = Join-Path -Path $ZipFile.DirectoryName -ChildPath $AppName;

    $Parameters = [PSCustomObject]@{
      ZipPath = $ZipPath;
      SqlTypeCastFilePath = $SqlTypeCastFilePath;
      SqlChangeOwnerFilePath = $SqlChangeOwnerFilePath;
      DbOwnerName = $DbOwnerName;
      DbOwnerPassword = $DbOwnerPassword;
      RedisDbNumber = $RedisDbNumber;
      RedisPort = $RedisPort;
      AppPort = $AppPort;
      DbPort = $DbPort;
      DockerPgContainerName = $DockerPgContainerName;
      AppPath = $AppPath;
    };

    Write-Progress -Activity $ProgressName -Status "Extract zip";
    [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile.FullName, $AppPath);
    
    Write-Progress -Activity $ProgressName -Status "Restore database";
    if ($DockerPgContainerName -ne $null)
    {
      $Parameters | Invoke-BpmDockerDbRestore;
    }
    else 
    {
      $Parameters | Invoke-BpmDbRestore;
    }

    Write-Progress -Activity $ProgressName -Status "Update connection string";
    $Parameters | Update-BpmConnectionString;

    Write-Progress -Activity $ProgressName -Status "Create IIS site";
    New-BpmSite -AppPort $AppPort -AppPath $AppPath;
    Write-Progress -Activity $ProgressName -Completed;
  }
}

function Update-BpmConnectionString {
  param (
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$AppPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerName,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerPassword,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$RedisDbNumber,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$RedisPort,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$DbPort
  )
  process {
    $AppName = (Get-Item $AppPath).BaseName;
    $ConnectionStringFilePath = "${AppPath}\ConnectionStrings.config";
    [xml]$ConnectionStringFile = Get-Content $ConnectionStringFilePath;
    $ConnectionStringFile.SelectSingleNode("/connectionStrings/add[@name='db']").connectionString = "Database=${AppName}; Username=${DbOwnerName}; Password=${DbOwnerPassword}; Port=${DbPort}; Host=localhost; Pooling=true;";
    $ConnectionStringFile.SelectSingleNode("/connectionStrings/add[@name='redis']").connectionString = "db=${RedisDbNumber}; port=${RedisPort}; host=localhost;";
    $ConnectionStringFile.Save($ConnectionStringFilePath);
  }
}

function Invoke-BpmDockerDbRestore {
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$AppPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlTypeCastFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlChangeOwnerFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerName,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$DbPort,
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]$DockerPgContainerName
  )
  process {
    $ErrorActionPreference = "Stop";

    $PsqlAdminName                  = "postgres";
    $AppDbDirName                   = "db";
    $DatabaseBackupFileFilter       = "*.backup";

    $AppName                        = (Get-Item $AppPath).BaseName;
    $SqlTypeCastFile                = Get-Item $SqlTypeCastFilePath;
    $SqlChangeOwnerFile             = Get-Item $SqlChangeOwnerFilePath;
    $DatabaseBackupFile             = Join-Path -Path $AppPath -ChildPath $AppDbDirName | Get-ChildItem -Filter $DatabaseBackupFileFilter | Sort-Object -Property "LastWriteTime" | Select-Object -First 1;
    $ScriptsDirPath                 = "/var/${AppName}_scripts";

    $PsqlCreateDbCommand            = "psql -U ${PsqlAdminName} -p ${DbPort} -c 'CREATE DATABASE \""${AppName}\"" WITH OWNER = ${DbOwnerName};'";
    $PgRestoreCommand               = "pg_restore -U ${PsqlAdminName} -p ${DbPort} -d ${AppName} -Oxe '${ScriptsDirPath}/$(${DatabaseBackupFile}.Name)'";
    $TypeCastCommand                = "psql -U ${PsqlAdminName} -p ${DbPort} -d ${AppName} -f '${ScriptsDirPath}/$(${SqlTypeCastFile}.Name)'";
    $ChangeOwnerCommand             = "psql -U ${PsqlAdminName} -p ${DbPort} -d ${AppName} -f '${ScriptsDirPath}/$(${SqlChangeOwnerFile}.Name)' -v owner=${DbOwnerName}";

    $MkdirCommand                   = "docker exec ${DockerPgContainerName} mkdir '${ScriptsDirPath}' -p";
    $CopySqlTypeCastFileCommand     = "docker container cp '$(${SqlTypeCastFile}.FullName)' ${DockerPgContainerName}:'${ScriptsDirPath}'";
    $CopySqlChangeOwnerFileCommand  = "docker container cp '$(${SqlChangeOwnerFile}.FullName)' ${DockerPgContainerName}:'${ScriptsDirPath}'";
    $CopyDbBackupCommand            = "docker container cp '$(${DatabaseBackupFile}.FullName)' ${DockerPgContainerName}:'${ScriptsDirPath}'";
    $DockerPsqlCreateDbCommand      = "docker exec ${DockerPgContainerName} ${PsqlCreateDbCommand}";
    $DockerPgRestoreCommand         = "docker exec ${DockerPgContainerName} ${PgRestoreCommand}";
    $DockerTypeCastCommand          = "docker exec ${DockerPgContainerName} ${TypeCastCommand}";
    $DockerChangeOwnerCommand       = "docker exec ${DockerPgContainerName} ${ChangeOwnerCommand}";

    try {
      Invoke-Expression $MkdirCommand;
      Invoke-Expression $CopySqlTypeCastFileCommand;
      Invoke-Expression $CopySqlChangeOwnerFileCommand;
      Invoke-Expression $CopyDbBackupCommand;
      Invoke-Expression $DockerPsqlCreateDbCommand;
      Invoke-Expression $DockerPgRestoreCommand;
      Invoke-Expression $DockerTypeCastCommand;
      Invoke-Expression $DockerChangeOwnerCommand;
    }
    catch {
      throw;
    }
  }
}

function Invoke-BpmDbRestore {
  param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$AppPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlTypeCastFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$SqlChangeOwnerFilePath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$DbOwnerName,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$DbPort
  )
  process {
    $ErrorActionPreference = "Stop";

    $PsqlAdminName                  = "postgres";
    $AppDbDirName                   = "db";
    $DatabaseBackupFileFilter       = "*.backup";

    $AppName                        = (Get-Item $AppPath).BaseName;
    $SqlTypeCastFile                = Get-Item $SqlTypeCastFilePath;
    $SqlChangeOwnerFile             = Get-Item $SqlChangeOwnerFilePath;
    $DatabaseBackupFile             = Join-Path -Path $AppPath -ChildPath $AppDbDirName | Get-ChildItem -Filter $DatabaseBackupFileFilter | Sort-Object -Property "LastWriteTime" | Select-Object -First 1;

    $PsqlCreateDbCommand            = "psql -U ${PsqlAdminName} -p ${DbPort} -c 'CREATE DATABASE \""${AppName}\"" WITH OWNER = ${DbOwnerName};'";
    $PgRestoreCommand               = "pg_restore -U ${PsqlAdminName} -d ${AppName} -Oxe '$(${DatabaseBackupFile}.FullName)'";
    $TypeCastCommand                = "psql -U ${PsqlAdminName} -p ${DbPort} -f '$(${SqlTypeCastFile}.FullName)'";
    $ChangeOwnerCommand             = "psql -U ${PsqlAdminName} -p ${DbPort} -f '$(${SqlChangeOwnerFile}.FullName)' -v owner=${DbOwnerName}";

    Invoke-Expression $PsqlCreateDbCommand;
    Invoke-Expression $PgRestoreCommand;
    Invoke-Expression $TypeCastCommand;
    Invoke-Expression $ChangeOwnerCommand;
  }
}

function New-BpmSite {
  param (
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$AppPath,
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [int]$AppPort,
    [switch]$IsFramework
  )
  process {
    $ErrorActionPreference = "Stop";

    $AppName = (Get-Item $AppPath).BaseName;

    $PoolConfig = 
    [PSCustomObject]@{
      Name = $AppName;
    };
    
    $SiteConfig = 
    [PSCustomObject]@{
      Name            = $AppName;
      IPAddress       = "*";
      Port            = $AppPort;
      ApplicationPool = $PoolConfig.Name;
      PhysicalPath    = $AppPath;
    };
    
    $PoolConfig | New-WebAppPool;
    $SiteConfig | New-Website | Start-Website;
    
    if ($IsFramework) {
      $AppConfig = 
      [PSCustomObject]@{
        Name            = "0";
        Site            = $SiteConfig.Name;
        ApplicationPool = $PoolConfig.Name;
        PhysicalPath    = $AppPath + "\BPMSoft.WebApp";
      };
      $AppConfig | New-Webapplication;
    }

    if (-not $IsFramework) {
      Set-WebConfigurationProperty -PSPath IIS:\ -Location ${AppName} -Name enabled -Filter /system.webServer/security/authentication/windowsAuthentication -Value true;
    }
    
    $IISPoolFullName = "IIS AppPool\" + $PoolConfig.Name;
    $FolderAccessControlList = Get-Acl $SiteConfig.PhysicalPath;
    $AccessControlEntity = New-Object System.Security.AccessControl.FileSystemAccessRule($IISPoolFullName, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow");
    $FolderAccessControlList.SetAccessRule($AccessControlEntity);
    $FolderAccessControlList | Set-Acl;
  }
}

function Restart-BpmPool {
  param (
    [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
    [string]$AppName
  )
  process {
    Restart-WebAppPool -Name $((Get-Website $AppName).applicationPool);
  }
}

Export-ModuleMember -Function New-BpmApp, Update-BpmConnectionString, Invoke-BpmDockerDbRestore, Invoke-BpmDbRestore, New-BpmSite, Restart-BpmPool;