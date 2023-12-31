$CONFIGDRIVE = "{{config_drive}}"
$CONFIGDRIVE = "C:"
$adminUserName = "{{admin_name}}"
$adminPassword = "{{admin_password}}"
function Start-App() {
    if (-not (Test-Administrator)) {
        Start-ElevatedProcess
        exit
    }
    Import-DotNetAssembly
    [WinImageBuilderAutomation]::EnableAdministratorAccount($adminUserName)
    [WinImageBuilderAutomation]::Main()
    if (-not (Test-RemoteManagementEnabled)) {
        Enable-RemoteManagement
    }
}

function Start-ElevatedProcess() {
    $PWord = ConvertTo-SecureString -String $adminPassword -AsPlainText -Force
    $adminCredential = New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $adminUserName, $PWord
    Start-Process powershell.exe -Credential $adminCredential `
        -ArgumentList "-NoExit -ExecutionPolicy Bypass ${CONFIGDRIVE}\start.ps1"

}

function Import-DotNetAssembly() {
    $MainCodeFile = "${CONFIGDRIVE}\main.cs";
    $MainCodeFile = "C:\Users\Virt\Documents\ConsoleApplication1\Program.cs"
    $sourceCode = [System.IO.File]::ReadAllText($MainCodeFile)
    $scriptAssembly = Get-NamesOfAssembliesToLoad @("System.Web.Extensions",
            "System.Management" )
    Add-Type -ReferencedAssemblies $scriptAssembly -TypeDefinition $sourceCode -Language CSharp
}

function Get-NamesOfAssembliesToLoad {
    param(
        [string[]] $PartialNames
    )
    $fullNames = @()
    foreach ($name in $PartialNames) {
        $result = [System.Reflection.Assembly]::LoadWithPartialName($name)
        if ($result) {
            $fullNames += $result.FullName
        }
    }
    return $fullNames
}

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Test-RemoteManagementEnabled {
    return (Get-Service WinRM).Status -eq "Running"
}

function Enable-RemoteManagement {
    [WinImageBuilderAutomation]::SetNetworksLocationToPrivate()
    Enable-PSRemoting -Force
    winrm quickconfig -q
    winrm set winrm/config/client/auth '@{Basic="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="2048"}'
    Restart-Service -Name WinRM
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in `
        localport=5985 protocol=TCP action=allow
}

Start-App
