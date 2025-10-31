<#
compile-jack.ps1

Usage examples:
  # Provide path to a compiler (.jar, .py or .bat)
  .\compile-jack.ps1 -CompilerPath 'C:\path\to\JackCompiler.jar'
  .\compile-jack.ps1 -CompilerPath 'C:\path\to\JackCompiler.py'

What it does:
 - Compiles all .jack files inside ./DinoAdventure/src using the provided compiler
 - Creates ./DinoAdventure/vm_code if it doesn't exist
 - Moves generated .vm files from src into vm_code
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$CompilerPath
)

# Resolve script root (script is expected inside DinoAdventure folder)
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
if (-not $scriptRoot) { $scriptRoot = Get-Location }

$src = Join-Path $scriptRoot 'src'
$out = Join-Path $scriptRoot 'vm_code'

if (-not (Test-Path $src)) {
    Write-Error "Source folder not found: $src"
    exit 1
}

if (-not (Test-Path $out)) {
    Write-Host "Creating output folder: $out"
    New-Item -ItemType Directory -Path $out | Out-Null
}

if (-not (Test-Path $CompilerPath)) {
    Write-Error "Compiler not found at: $CompilerPath"
    exit 1
}

# Run the compiler based on extension
Write-Host "Compiling .jack files in: $src using: $CompilerPath"
$ext = [IO.Path]::GetExtension($CompilerPath).ToLower()
switch ($ext) {
    '.jar' {
        & java -jar $CompilerPath $src
        $exit = $LASTEXITCODE
    }
    '.py' {
        # Some Python JackCompiler implementations expect a single .jack file
        # instead of a directory. Compile each .jack file individually to be
        # robust against those variants and against paths with spaces/parentheses.
        $jackFiles = Get-ChildItem -Path $src -Filter '*.jack' -File
        if ($jackFiles.Count -eq 0) {
            Write-Error "No .jack files found in $src"
            exit 1
        }
        $exit = 0
        foreach ($f in $jackFiles) {
            Write-Host "Compiling $($f.FullName)"
            & python $CompilerPath $f.FullName
            if ($LASTEXITCODE -ne 0) { $exit = $LASTEXITCODE; break }
        }
    }
    '.bat' {
        & cmd /c "`"$CompilerPath`" `"$src`""
        $exit = $LASTEXITCODE
    }
    default {
        Write-Error "Unsupported compiler type: $ext. Provide a .jar, .py or .bat"
        exit 1
    }
}

if ($exit -ne 0) {
    Write-Error "Compiler exited with code $exit"
    exit $exit
}

# Move generated .vm files to vm_code
Write-Host "Moving generated .vm files to: $out"
Get-ChildItem -Path $src -Filter '*.vm' -File | ForEach-Object {
    $dest = Join-Path $out $_.Name
    if (Test-Path $dest) { Remove-Item $dest -Force }
    Move-Item $_.FullName $dest
}
Write-Host "Done. Generated .vm files are in: $out"
