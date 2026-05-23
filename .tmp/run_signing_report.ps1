$env:JAVA_HOME='C:\Program Files\Java\jdk-17'
$env:Path = $env:JAVA_HOME + '\\bin;' + $env:Path
Write-Host "JAVA_HOME=$env:JAVA_HOME"
Set-Location -Path 'android'
& .\gradlew.bat signingReport
