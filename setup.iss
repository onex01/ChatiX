[Setup]
AppName=Rizz
AppVersion=0.1.48
DefaultDirName={autopf}\Rizz
DefaultGroupName=Rizz
UninstallDisplayIcon={app}\Rizz.exe
Compression=lzma2
SolidCompression=yes
OutputBaseFilename=Rizz-0.1.48
PrivilegesRequired=lowest

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\Rizz"; Filename: "{app}\Rizz.exe"
Name: "{commondesktop}\Rizzr"; Filename: "{app}\Rizz.exe"

[Run]
Filename: "{app}\Rizz.exe"; Description: "Запустить Rizz"; Flags: postinstall nowait skipifsilent