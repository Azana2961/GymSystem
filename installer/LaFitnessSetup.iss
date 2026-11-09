; Script generated for Inno Setup 6
; Lá Fitness Gym Management System Installer

#define MyAppName "Lá Fitness Gym"
#define MyAppVersion "2.2.0"
#define MyAppPublisher "Lá Fitness"
#define MyAppExeName "LaFitnessGym.exe"

[Setup]
AppId={{8B3F2A41-79A1-4D3C-B61E-C9A8E2B45001}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\La Fitness Gym
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=d:\GYMSYSTEM\installer
OutputBaseFilename=LaFitnessSetup
SetupIconFile=d:\GYMSYSTEM\installer\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog commandline
DisableDirPage=no
DisableProgramGroupPage=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "d:\GYMSYSTEM\installer\staging\*"; DestDir: "{app}"; Excludes: "backend\gym_backend.db"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "d:\GYMSYSTEM\installer\staging\backend\gym_backend.db"; DestDir: "{app}\backend"; Flags: ignoreversion onlyifdoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "netsh"; Parameters: "advfirewall firewall add rule name=""La Fitness Gym Server"" dir=in action=allow program=""{app}\runtime\node.exe"" enable=yes"; Flags: runhidden
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "netsh"; Parameters: "advfirewall firewall delete rule name=""La Fitness Gym Server"""; Flags: runhidden

