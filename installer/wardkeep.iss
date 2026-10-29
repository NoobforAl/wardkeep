; Wardkeep for Windows: a per-user installer (no administrator rights, nothing outside the user's own folders
; and HKEY_CURRENT_USER). Built with Inno Setup 6 (https://jrsoftware.org/isinfo.php):
;
;   ISCC.exe installer\wardkeep.iss /DAppVersion=0.1.0 /DSourceDir=dist\app /DOutputDir=dist
;
; SourceDir is the Flutter release folder (omnitun.exe, the DLLs, data\) with omnitun-svc.exe, the core,
; next to it: the same folder that goes into the ZIP. Defines:
;   AppVersion      numbers only, x.y.z (the version the installer and Windows' "Apps" list show)
;   AppVersionName  the version as written in the file name (0.1.0, 0.2.0-rc1, dev-abc1234); default AppVersion
;   SourceDir       the folder to install (default ..\dist\app)
;   OutputDir       where the setup .exe is written (default ..\dist)
;   MutexName       the single-instance mutex of the app (only a test changes it, to run next to a real copy)
;   Signed          when given, the installer and its uninstaller are signed with the tool that ISCC was
;                   told about with /Ssign=... (see .github/workflows/release.yml)
;
; What it does, all for the current user:
;   * copies the app to %LOCALAPPDATA%\Programs\Wardkeep (the folder can be changed, and /DIR= works);
;   * a Start menu shortcut; optional: a desktop shortcut, start with Windows (to the tray: --background);
;   * optional: registers Wardkeep for share links (vless://, vmess://, ...) and offers it for VPN config
;     files, like app\windows\packaging\omnitun-file-associations.reg does for a hand-made install;
;   * the uninstaller removes all of that, and asks whether to keep the servers and settings
;     (%APPDATA%\dev.omnitun\omnitun). Silent: they are kept; add /DELETEDATA to delete them.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppVersionName
  #define AppVersionName AppVersion
#endif
#ifndef SourceDir
  #define SourceDir "..\dist\app"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#ifndef MutexName
  #define MutexName "Local\Wardkeep.SingleInstance"
#endif
#define AppName "Wardkeep"
#define ExeName "omnitun.exe"

[Setup]
AppId={{8F3A5C2E-6B1D-4E7A-9C40-2D5B7E9A1F36}
AppName={#AppName}
AppVersion={#AppVersionName}
AppPublisher=Wardkeep
AppPublisherURL=https://github.com/NoobforAl/wardkeep
AppSupportURL=https://github.com/NoobforAl/wardkeep/issues
VersionInfoVersion={#AppVersion}.0
VersionInfoProductName={#AppName}
VersionInfoDescription={#AppName} setup
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
; Nothing here needs administrator rights, and none are asked for: {autopf} is then the user's own
; Programs folder and every registry entry goes to HKEY_CURRENT_USER.
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=wardkeep-{#AppVersionName}-windows-x64-setup
SetupIconFile=..\app\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#ExeName}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The file types and links are registered, so Explorer is told.
ChangesAssociations=yes
; A running copy (and the core it started) is asked to close, so its files can be replaced or removed.
; The name is the one main.cpp's single-instance guard holds.
AppMutex={#MutexName}
CloseApplications=yes
RestartApplications=no
#ifdef Signed
SignTool=sign
SignedUninstaller=yes
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "arabic"; MessagesFile: "compiler:Languages\Arabic.isl"
Name: "brazilianportuguese"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"
Name: "french"; MessagesFile: "compiler:Languages\French.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[CustomMessages]
english.StartWithWindows=Start {#AppName} when I sign in to Windows (in the tray)
english.RegisterLinks=Open share links (vless://, vmess://, ...) and VPN config files with {#AppName}
english.DeleteData=Delete your servers and settings too?%n%nChoose No to keep them (%APPDATA%\dev.omnitun\omnitun) for a later install.
arabic.StartWithWindows=تشغيل {#AppName} عند تسجيل الدخول إلى Windows (في منطقة الإشعارات)
arabic.RegisterLinks=فتح الروابط (vless://، vmess://، ...) وملفات إعداد VPN باستخدام {#AppName}
arabic.DeleteData=هل تريد حذف خوادمك وإعداداتك أيضًا؟%n%nاختر لا للاحتفاظ بها (%APPDATA%\dev.omnitun\omnitun) لتثبيت لاحق.
brazilianportuguese.StartWithWindows=Iniciar o {#AppName} ao entrar no Windows (na bandeja)
brazilianportuguese.RegisterLinks=Abrir links (vless://, vmess://, ...) e arquivos de configuração de VPN com o {#AppName}
brazilianportuguese.DeleteData=Remover também seus servidores e configurações?%n%nEscolha Não para mantê-los (%APPDATA%\dev.omnitun\omnitun) para uma instalação futura.
french.StartWithWindows=Lancer {#AppName} à l’ouverture de session Windows (dans la zone de notification)
french.RegisterLinks=Ouvrir les liens (vless://, vmess://, ...) et les fichiers de configuration VPN avec {#AppName}
french.DeleteData=Supprimer aussi vos serveurs et réglages ?%n%nChoisissez Non pour les conserver (%APPDATA%\dev.omnitun\omnitun) pour une prochaine installation.
russian.StartWithWindows=Запускать {#AppName} при входе в Windows (в трей)
russian.RegisterLinks=Открывать ссылки (vless://, vmess://, ...) и файлы настроек VPN в {#AppName}
russian.DeleteData=Удалить также ваши серверы и настройки?%n%nНажмите «Нет», чтобы сохранить их (%APPDATA%\dev.omnitun\omnitun) для следующей установки.
spanish.StartWithWindows=Iniciar {#AppName} al iniciar sesión en Windows (en la bandeja)
spanish.RegisterLinks=Abrir enlaces (vless://, vmess://, ...) y archivos de configuración VPN con {#AppName}
spanish.DeleteData=¿Eliminar también tus servidores y ajustes?%n%nElige No para conservarlos (%APPDATA%\dev.omnitun\omnitun) para una instalación posterior.
turkish.StartWithWindows=Windows'ta oturum açınca {#AppName}'i başlat (tepside)
turkish.RegisterLinks=Bağlantıları (vless://, vmess://, ...) ve VPN yapılandırma dosyalarını {#AppName} ile aç
turkish.DeleteData=Sunucularınız ve ayarlarınız da silinsin mi?%n%nSonraki bir kurulum için saklamak üzere Hayır'ı seçin (%APPDATA%\dev.omnitun\omnitun).

[Tasks]
Name: "links"; Description: "{cm:RegisterLinks}"
Name: "startup"; Description: "{cm:StartWithWindows}"; Flags: unchecked
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; DestName: "LICENSE.txt"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#ExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#ExeName}"; Tasks: desktopicon

[Registry]
; Start with Windows: into the tray, no window (--background).
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "{#AppName}"; ValueData: """{app}\{#ExeName}"" --background"; Flags: uninsdeletevalue; Tasks: startup

; Share links: the system starts Wardkeep with the link as its argument (a second start hands it to the
; open window). A link another program has claimed for the current user is taken over, as with the .reg file.
Root: HKCU; Subkey: "Software\Classes\vless"; ValueType: string; ValueData: "URL:vless link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\vless"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\vless\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\vmess"; ValueType: string; ValueData: "URL:vmess link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\vmess"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\vmess\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\trojan"; ValueType: string; ValueData: "URL:trojan link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\trojan"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\trojan\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\ss"; ValueType: string; ValueData: "URL:ss link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\ss"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\ss\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria2"; ValueType: string; ValueData: "URL:hysteria2 link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria2"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria2\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hy2"; ValueType: string; ValueData: "URL:hy2 link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hy2"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hy2\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria"; ValueType: string; ValueData: "URL:hysteria link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\hysteria\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\tuic"; ValueType: string; ValueData: "URL:tuic link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\tuic"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\tuic\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wireguard"; ValueType: string; ValueData: "URL:wireguard link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wireguard"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wireguard\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\awg"; ValueType: string; ValueData: "URL:awg link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\awg"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\awg\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\anytls"; ValueType: string; ValueData: "URL:anytls link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\anytls"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\anytls\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\nordvpn"; ValueType: string; ValueData: "URL:nordvpn link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\nordvpn"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\nordvpn\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\naive+https"; ValueType: string; ValueData: "URL:naive+https link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\naive+https"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\naive+https\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wardkeep"; ValueType: string; ValueData: "URL:wardkeep link"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wardkeep"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\wardkeep\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links

; The file types: Wardkeep is added to "Open with"; the default program is not changed.
Root: HKCU; Subkey: "Software\Classes\Wardkeep.Config"; ValueType: string; ValueData: "Wardkeep configuration"; Flags: uninsdeletekey; Tasks: links
Root: HKCU; Subkey: "Software\Classes\Wardkeep.Config\DefaultIcon"; ValueType: string; ValueData: "{app}\{#ExeName},0"; Tasks: links
Root: HKCU; Subkey: "Software\Classes\Wardkeep.Config\shell\open\command"; ValueType: string; ValueData: """{app}\{#ExeName}"" ""%1"""; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.ovpn"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.ovpn\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.ovpn\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.conf"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.conf\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.conf\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.json"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.json\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.json\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yaml"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yaml\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yaml\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yml"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yml\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.yml\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.txt"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.txt\OpenWithProgids"; Flags: uninsdeletekeyifempty; Tasks: links
Root: HKCU; Subkey: "Software\Classes\.txt\OpenWithProgids"; ValueType: string; ValueName: "Wardkeep.Config"; ValueData: ""; Flags: uninsdeletevalue; Tasks: links

[Run]
Filename: "{app}\{#ExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Anything the app left in its own folder.
Type: filesandordirs; Name: "{app}"

[Code]
function DeleteDataRequested: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    if CompareText(ParamStr(i), '/DELETEDATA') = 0 then Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Roaming, Settings, Core: String;
  Delete: Boolean;
begin
  if CurUninstallStep <> usPostUninstall then Exit;
  Roaming := ExpandConstant('{userappdata}');
  // The app's servers and settings, and the core's cache and control file.
  Settings := Roaming + '\dev.omnitun';
  Core := Roaming + '\omnitun';
  if not (DirExists(Settings) or DirExists(Core)) then Exit;
  if UninstallSilent then
    Delete := DeleteDataRequested
  else
    Delete := MsgBox(CustomMessage('DeleteData'), mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
  if Delete then
  begin
    DelTree(Settings, True, True, True);
    DelTree(Core, True, True, True);
  end;
end;
