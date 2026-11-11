; Inno Setup Script для ECLIPSE VPN Windows
; Требуется Inno Setup 6.2+

#define MyAppName "ECLIPSE VPN"
#define MyAppVersion "0.2.2"
#define MyAppPublisher "ECLIPSE"
#define MyAppURL "https://github.com/pomah7878-bot/ECLIPSE_VPN"
#define MyAppExeName "eclipse_vpn_windows.exe"

[Setup]
; Основные параметры
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; Директории
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes

; Выходной файл
OutputDir=installer
OutputBaseFilename=ECLIPSE_VPN_Setup_{#MyAppVersion}

; Сжатие
Compression=lzma2
SolidCompression=yes

; Права
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

; Дизайн
WizardStyle=modern
WizardSizePercent=100

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Запускать при старте Windows"; GroupDescription: "Автозапуск:"; Flags: unchecked

[Files]
; Основное приложение
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs

; sing-box VPN-ядро
Source: "sing-box\sing-box.exe"; DestDir: "{app}"; Flags: ignoreversion

; wintun.dll — драйвер TUN для Windows
Source: "wintun\wintun.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
; Меню Пуск
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"

; Рабочий стол
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

; Автозапуск
Name: "{commonstartup}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: autostart

[Run]
; Запуск после установки
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Очистка данных при удалении
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{localappdata}\{#MyAppName}"

[Code]
// Проверка .NET и Visual C++ Redistributable
function InitializeSetup(): Boolean;
var
  ErrorCode: Integer;
begin
  // Проверяем Visual C++ Redistributable 2015-2022
  if not RegKeyExists(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64') then
  begin
    if MsgBox('Для работы приложения требуется Visual C++ Redistributable 2015-2022 x64.' + #13#10 +
              'Скачать сейчас?', mbConfirmation, MB_YESNO) = IDYES then
    begin
      ShellExec('open', 'https://aka.ms/vs/17/release/vc_redist.x64.exe', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
    end;
  end;
  
  Result := True;
end;

// Создание правила в фаерволе Windows
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    // Разрешаем приложение в фаерволе
    Exec('netsh', 'advfirewall firewall add rule name="ECLIPSE VPN" dir=in action=allow program="' + ExpandConstant('{app}\{#MyAppExeName}') + '" enable=yes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
    Exec('netsh', 'advfirewall firewall add rule name="ECLIPSE VPN sing-box" dir=in action=allow program="' + ExpandConstant('{app}\sing-box.exe') + '" enable=yes', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  end;
end;