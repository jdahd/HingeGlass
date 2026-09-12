#define AppVersion "0.1.2"
[Setup]
AppId={{91950675-B1C2-4B82-9899-42735156E413}
AppName=HingeGlass Windows Preview
AppVersion={#AppVersion}
AppPublisher=jux
AppPublisherURL=https://github.com/jdahd/HingeGlass
AppSupportURL=https://github.com/jdahd/HingeGlass/issues
DefaultDirName={localappdata}\Programs\HingeGlass
DefaultGroupName=HingeGlass
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.19041
WizardStyle=modern
DisableWelcomePage=no
SetupIconFile=..\HingeGlass.Windows\AppIcon.ico
UninstallDisplayIcon={app}\HingeGlass.exe
WizardImageFile=..\..\Resources\AppIcon.png
WizardSmallImageFile=..\..\Resources\AppIcon.png
WizardImageStretch=yes
OutputDir=..\..\installer-output
OutputBaseFilename=HingeGlass-{#AppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
CloseApplications=yes
RestartApplications=no
VersionInfoDescription=HingeGlass Windows Preview Installer
[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked
[Files]
Source: "..\..\dist\HingeGlass-Windows\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{group}\HingeGlass"; Filename: "{app}\HingeGlass.exe"
Name: "{autodesktop}\HingeGlass"; Filename: "{app}\HingeGlass.exe"; Tasks: desktopicon
[Run]
Filename: "{app}\HingeGlass.exe"; Description: "Open HingeGlass"; Flags: nowait postinstall skipifsilent
[Code]
procedure BrandImage(Image: TBitmapImage);
var LabelText: TNewStaticText;
begin
  Image.Height := Image.Width;
  Image.Top := ScaleY(60);
  LabelText := TNewStaticText.Create(WizardForm);
  LabelText.Parent := Image.Parent;
  LabelText.Left := Image.Left;
  LabelText.Top := Image.Top + Image.Height + ScaleY(18);
  LabelText.Width := Image.Width;
  LabelText.Height := ScaleY(52);
  LabelText.AutoSize := False;
  LabelText.Alignment := taCenter;
  LabelText.Font.Size := 15;
  LabelText.Font.Style := [fsBold];
  LabelText.Caption := 'HingeGlass';
end;
procedure InitializeWizard;
begin
  BrandImage(WizardForm.WizardBitmapImage);
  BrandImage(WizardForm.WizardBitmapImage2);
  WizardForm.WelcomeLabel2.Caption := 'Install HingeGlass for your Windows account.' + #13#10 + #13#10 +
    'This experimental version includes manual visual previews and hinge-angle sensor detection. Live desktop effects are not included yet.';
end;
