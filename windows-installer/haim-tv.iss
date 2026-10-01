; Installer for the Windows build of Haim TV.
;
; Build it with (from the repo root, after `flutter build windows --release`):
;   ISCC.exe /DAppVersion=1.0.3 windows-installer\haim-tv.iss
; The result is dist\HaimTV-<version>-windows-setup.exe.
;
; It installs per user (no administrator rights, no UAC prompt), so the
; in-app updater can replace the files it installed.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "Haim TV"
#define AppExe "haim_tv.exe"
#define AppPublisher "jaimegarmun"
#define AppUrl "https://github.com/jaimegarmun/Haim-TV-IPTV"

[Setup]
; Keep this GUID: it is how Windows recognises an update of the same app.
AppId={{8F1B5A2E-6C44-4D93-9E27-0C3A5B6D7E81}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppUrl}
AppSupportURL={#AppUrl}/issues
AppUpdatesURL={#AppUrl}/releases
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\dist
OutputBaseFilename=HaimTV-{#AppVersion}-windows-setup
SetupIconFile=..\flutter\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
WizardStyle=modern
Compression=lzma2/max
SolidCompression=yes
; The updater runs this silently while the app is still closing.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\flutter\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
