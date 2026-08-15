<#
.SYNOPSIS
Concatenates files at a given search query into a new file.
.PARAMETER Path
Specifies root directory from which files should be concatenated.
.PARAMETER Include
Specifies wildcard rules for searching files to concatenate.
.PARAMETER Exclude
Specifies wildcard rules for files that should not be concatenated.
.EXAMPLE
Get-ConcatenateFiles -Path . *.cs,*.js wwwroot,bin,obj,*.cs
#>
function Get-ConcatenateFiles
{
  param(
    [Parameter(Mandatory)][string[]]$Path,
    [string[]]$Include,
    [string[]]$Exclude
  )

  if ($null -eq $Include) {
    $Include = "*.cs","*.js","*.sql";
  }
  if ($null -eq $Exclude) {
    $Exclude = "*.dll";
  }
  
  Get-ChildItem -File -Path $Path -Include $Include -Exclude $Exclude -Recurse | % {"Content of file ""$($_.FullName)"" starts here.";Get-Content $_ -Encoding utf8;"Content of file ""$($_.FullName)"" ends here.";}
}

<#
.SYNOPSIS
Prints git difference between contents of two commits based on origin.
.PARAMETER FirstCommit
Specifies origin commit.
.PARAMETER LastCommit
Specifies commit with changes.
.EXAMPLE
Get-Difference -FirstCommit 0e69a0de3e93ca73c7cc800f57df83cc4d20e2bc -SecondCommit cea17c7a0e0186d8de70307b05874a84733e8429 | Out-File diff.txt -Encoding utf8
#>
function Get-Difference() {
  param(
    [Parameter(Mandatory)][string]$FirstCommit,
    [Parameter(Mandatory)][string]$LastCommit
  )
	$MaxBase64StringLength = 500;
  if ($FirstCommit -eq $LastCommit) {
    throw "First commit can not be equal to the last";
  }

  $GitOutput = git checkout $FirstCommit 2>&1;
  if (-not $?) {
    if ($GitOutput.Exception.Message.Count -gt 1 -and -not $GitOutput.Exception.Message[0].Contains("HEAD")) {
      throw $GitOutput;
    }
  }

  $GitOutput = git diff $FirstCommit $LastCommit --name-only 2>&1;
  if (-not $?) {
	throw $GitOutput;
  }
  "Contents of the original folder ""a"" start here."
  foreach ($fileName in $GitOutput) {
  	$File = Get-Item $fileName -ErrorAction Ignore;
  	if (-not $?) {
  		continue;
  	}
    
    if ($File.Extension -eq ".dll") {
      continue;
    }

    $GitDiffFileName = $File.FullName -replace "(.+)(?=\\Pkg\\)", "a"
  	"Contents of file ""$GitDiffFileName"" start here.";
    $FileContent = Get-Content $File -Encoding utf8;
    if ($File.Extension -eq ".xml") {
      $FileContent = $FileContent | Where-Object -FilterScript {-not ($_.Contains("ContentType=""Data""") -or $_.Contains("Type=""Image"""))};
    }
    elseif ($File.Extension -eq ".json") {
      $FileContent = $FileContent -replace "(\w{$MaxBase64StringLength,}={0,2})","null";
    }
    $FileContent;
  	"Contents of file ""$GitDiffFileName"" end here.";
  }
  "Contents of the original folder ""a"" end here."

  "Proposed changes to the original folder ""a"" start here."
   $GitOutput = git diff $FirstCommit $LastCommit 2>&1;
  if (-not $?) {
	throw $GitOutput;
  }
  $GitOutput = $GitOutput | Where-Object -FilterScript {-not ($_.Contains("ContentType=""Data""") -or $_.Contains("Type=""Image"""))};
  $GitOutput = $GitOutput  -replace "(\w{$MaxBase64StringLength,}={0,2})","null";
  $GitOutput;
  "Proposed changes to the original folder ""a"" end here."
}
<#
.SYNOPSIS
Splits one concatenated source code file with delimiters in it to several files.
.PARAMETER Path
Specifies concatenated source code file.
.PARAMETER StartDelimiter
Specifies wildcard rule for the start file delimiter. Important: delimiter should contain absolute path to a file.
Example: "Content of file ""(.+)"" starts here."
.PARAMETER EndDelimiter
Specifies wildcard rule for the end file delimiter. Important: delimiter should contain absolute path to a file.
Example: "Content of file ""(.+)"" ends here."
.EXAMPLE
Split-ToFiles -Path E:/Project/concat.txt
#>
function Split-ToFiles() {
  param (
    [Parameter(Mandatory)][string]$Path,
    [string]$StartDelimiter,
    [string]$EndDelimiter
  )
  if ('' -eq $StartDelimiter) {
    $StartDelimiter = "Content of file ""(.+)"" starts here.";
  }
  if ('' -eq $EndDelimiter) {
    $EndDelimiter = "Content of file ""(.+)"" ends here.";
  }

  $Content = Get-Content $Path;
  $StartIndex = 0;
  $EndIndex = 0;
  foreach ($row in $Content) 
  {
    if ('' -eq $row) 
    {
      continue;
    }
    if ($row -match $StartDelimiter)
    {
      $StartIndex = $Content.IndexOf($row);
    }
    if ($row -match $EndDelimiter)
    {
      $FileName = $Matches[1];
      $EndIndex = $Content.IndexOf($row);
      if (-not ($StartIndex + 1 -eq $EndIndex)) 
      {
        $FileContent = $Content[($StartIndex + 1)..($EndIndex - 1)];
        $FileContent | Out-File -FilePath $FileName -Encoding utf8 -Force;
        Write-Host "$FileName written"
      } 
      else 
      {
        Out-File -FilePath $FileName -Encoding utf8 -Force;
        Write-Host "$FileName written empty"
      }
    }
  }
}

Export-ModuleMember -Function Get-ConcatenateFiles, Get-Difference, Split-ToFiles, Get-Difference2;