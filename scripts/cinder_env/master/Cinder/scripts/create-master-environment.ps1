Param(
    [Parameter(Mandatory=$true)][string]$devstackIP,
    [string]$branchName='master',
    [string]$buildFor='openstack/cinder'
)

$projectName = $buildFor.split('/')[-1]

$openstackDir = "C:\Openstack"
$scriptdir = "C:\ci-overcloud-init-scripts\scripts"
$baseDir = "$scriptdir\devstack"
$configDir = "C:\cinder\etc\cinder"
$templateDir = "$scriptdir\cinder_env\master\Cinder\templates"
$cinderTemplate = "$templateDir\cinder.conf"
$pythonDir = "C:\Python27"
$hostname = hostname

. "$scriptdir\cinder_env\master\Cinder\scripts\utils.ps1"

$hasCinderTemplate = Test-Path $cinderTemplate
$hasConfigDir = Test-Path $configDir

$ErrorActionPreference = "SilentlyContinue"

if ($hasProject -eq $false){
    Throw "$projectName repository was not found."
}

if ($hasCinderTemplate -eq $false){
    Throw "Cinder template not found"
}

#copy distutils.cfg
Copy-Item $templateDir\distutils.cfg $pythonDir\Lib\distutils\distutils.cfg

if ($buildFor -eq "openstack/cinder"){
    ExecRetry {
        GitClonePull "C:/$projectName" "https://github.com/openstack/$projectName" $branchName
    }
}else{
    Throw "Cannot build for project: $buildFor"
}

# Mount devstack samba. Used for log storage
ExecRetry {
    New-SmbMapping -RemotePath \\$devstackIP\openstack -LocalPath u:
    if ($LastExitCode) { Throw "Failed to mount devstack samba" }
}

$hasLogDir = Test-Path U:\$hostname
if ($hasLogDir -eq $false){
    mkdir U:\$hostname
}

ExecRetry {
    cmd.exe /C $scriptdir\cinder_env\master\Cinder\scripts\install_openstack_from_repo.bat C:\$projectName
    if ($LastExitCode) { Throw "Failed to install cinder from repo" }
}

#mkdir C:\ImageConversionDir
Copy-Item $templateDir\cinder.conf $configDir\cinder.conf
$cinderConfig = (gc "$configDir\cinder.conf").replace('[DEVSTACK_IP]', "$devstackIP").Replace('[LOGDIR]', "U:\$hostname")

Set-Content $configDir\cinder.conf $cinderConfig
if ($? -eq $false){
    Throw "Error writting $templateDir\cinder.conf"
}

Invoke-WMIMethod -path win32_process -name create -argumentlist "$scriptdir\cinder_env\master\Cinder\scripts\run_openstack_service.bat $pythonDir\Scripts\cinder-volume $configDir\cinder.conf U:\$hostname\cinder-console.log"
