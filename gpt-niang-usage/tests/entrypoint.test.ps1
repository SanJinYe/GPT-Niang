param([string]$PreviewDirectory)

$ErrorActionPreference='Stop'

$source=Split-Path $PSScriptRoot -Parent

. (Join-Path $source 'runtime\update-common.ps1')

function Get-FileHash {throw 'Get-FileHash module is unavailable in this fixture.'}

$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-entrypoint-'+[Guid]::NewGuid().ToString('N'))

$testApp=Join-Path $testRoot 'app'

$testData=Join-Path $testRoot 'state'

# Use the shipping manifest so newly added runtime modules are exercised too.
$files=@(Get-Content -LiteralPath (Join-Path $source 'runtime\install-files.json') -Raw -Encoding UTF8|ConvertFrom-Json)

$directories=@($testRoot,$testApp,$testData,(Join-Path $testApp 'runtime'),(Join-Path $testApp 'assets'),(Join-Path $testApp 'assets\characters'))

try{

  foreach($directory in $directories){$null=New-Item -ItemType Directory -Path $directory}

  foreach($file in $files){
    $target=Join-Path $testApp $file
    $null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
    Copy-Item -LiteralPath (Join-Path $source $file) -Destination $target
  }

  # Synthetic fixture exercises an alternate image without distributing third-party artwork.

  Add-Type -AssemblyName PresentationCore,WindowsBase

  $pixels=[byte[]]@(128,64,192,255,128,64,192,255,128,64,192,255,128,64,192,255)

  $image=[Windows.Media.Imaging.BitmapSource]::Create(2,2,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,8)

  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new()

  $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($image))

  $fixtureImage=Join-Path $testApp 'assets\characters\test-alternative.png'

  $stream=[IO.File]::Create($fixtureImage);try{$encoder.Save($stream)}finally{$stream.Dispose()}

  [IO.File]::WriteAllText((Join-Path $testApp 'assets\characters.json'),(@{version=1;characters=@(@{id='test-alternative';name='Test alternative';file='characters/test-alternative.png'})}|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))

  $config=@{appDir=$testApp;dataDir=$testData;codexPath='unused-in-preview'}

  [IO.File]::WriteAllText((Join-Path $testApp 'installation.json'),($config|ConvertTo-Json),[Text.UTF8Encoding]::new($false))

  $snapshot=@{ok=$true;queryOk=$true;observedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();windows=@(@{minutes=300;used=25;remaining=75;resetsAt=$null},@{minutes=10080;used=10;remaining=90;resetsAt=$null})}

  [IO.File]::WriteAllText((Join-Path $testData 'status.json'),($snapshot|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))

  $powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

  $preview=Join-Path $testApp 'preview.png'

  $previousHash=$null

  foreach($character in @(@{id='gpt-dragon';file='quota-aligned.png'},@{id='test-alternative';file='quota-alternative.png'})){

    [IO.File]::WriteAllText((Join-Path $testData 'settings.json'),(@{characterId=$character.id}|ConvertTo-Json),[Text.UTF8Encoding]::new($false))

    & $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $testApp 'runtime\start-widget.ps1') -WidgetPath (Join-Path $testApp 'widget.ps1') -Preview

    if($LASTEXITCODE-ne 0){throw ('The full WPF entry point failed for '+$character.id+'.')}

    if(!(Test-Path -LiteralPath $preview) -or [IO.File]::ReadAllBytes($preview).Length-lt 1000){throw 'The WPF preview is missing or empty.'}

    $hash=Get-WidgetFileHash $preview

    if($previousHash -and $hash-eq $previousHash){throw 'The saved alternate character was not applied by the full WPF entry point.'}

    $previousHash=$hash

    if($PreviewDirectory){

      $null=New-Item -ItemType Directory -Path $PreviewDirectory -Force

      Copy-Item -LiteralPath $preview -Destination (Join-Path $PreviewDirectory $character.file)

    }

  }

  Write-Output 'PASS: full WPF widget and UTF-8 entry point on Windows PowerShell 5.1 with stock and synthetic alternate characters'

}finally{

  $resolved=[IO.Path]::GetFullPath($testRoot)

  $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'

  if(!$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved)-notlike 'gpt-niang-entrypoint-*'){throw 'Unsafe entrypoint test cleanup path.'}

  if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}

}
