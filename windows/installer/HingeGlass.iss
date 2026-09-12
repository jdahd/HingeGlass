#define AppVersion "0.1.4"
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
WizardStyle=modern light polar hidebevels includetitlebar
WizardBackColor=#f3f7fb
WizardImageBackColor=#f3f7fb
WizardSmallImageBackColor=#f3f7fb
WizardSizePercent=120
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
[Messages]
DefaultDialogFontName=Segoe UI
DefaultDialogFontSize=10

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
var StepLabel: TNewStaticText;
procedure BrandImage(Image: TBitmapImage);
var Brand, Edition: TNewStaticText;
begin
  Image.SetBounds(ScaleX(24), ScaleY(76), ScaleX(172), ScaleY(172));
  Brand := TNewStaticText.Create(WizardForm);
  Brand.Parent := Image.Parent;
  Brand.SetBounds(Image.Left, Image.Top + Image.Height + ScaleY(20), Image.Width, ScaleY(32));
  Brand.AutoSize := False;
  Brand.Alignment := taCenter;
  Brand.Font.Size := 17;
  Brand.Font.Style := [fsBold];
  Brand.Caption := 'HingeGlass';
  Edition := TNewStaticText.Create(WizardForm);
  Edition.Parent := Image.Parent;
  Edition.SetBounds(Image.Left, Brand.Top + ScaleY(34), Image.Width, ScaleY(24));
  Edition.AutoSize := False;
  Edition.Alignment := taCenter;
  Edition.Font.Size := 9;
  Edition.Caption := 'WINDOWS PREVIEW';
end;
procedure InitializeWizard;
begin
  WizardForm.Caption := 'HingeGlass';
  BrandImage(WizardForm.WizardBitmapImage);
  BrandImage(WizardForm.WizardBitmapImage2);
  WizardForm.WelcomeLabel1.SetBounds(ScaleX(230), ScaleY(76), WizardForm.WelcomePage.ClientWidth - ScaleX(262), ScaleY(104));
  WizardForm.WelcomeLabel1.Font.Size := 25;
  WizardForm.WelcomeLabel1.Font.Style := [fsBold];
  WizardForm.WelcomeLabel1.Caption := 'A little motion.' + #13#10 + 'A softer view.';
  WizardForm.WelcomeLabel2.SetBounds(ScaleX(230), ScaleY(196), WizardForm.WelcomePage.ClientWidth - ScaleX(262), ScaleY(170));
  WizardForm.WelcomeLabel2.Font.Size := 11;
  WizardForm.WelcomeLabel2.Caption := 'Bring HingeGlass to your Windows PC.' + #13#10 + #13#10 +
    'Explore perspective and blur. Try your own images. See if your laptop can read its lid angle.' + #13#10 + #13#10 +
    'A preview inside the app. Live desktop effects are still in development.';
  WizardForm.PageNameLabel.Font.Size := 14;
  WizardForm.PageNameLabel.Height := ScaleY(26);
  WizardForm.PageDescriptionLabel.Top := WizardForm.PageNameLabel.Top + ScaleY(30);
  WizardForm.PageDescriptionLabel.Height := ScaleY(34);
  WizardForm.MainPanel.Height := ScaleY(86);
  WizardForm.InnerNotebook.Top := ScaleY(94);
  WizardForm.InnerNotebook.Height := WizardForm.InnerPage.ClientHeight - ScaleY(106);
  WizardForm.FinishedHeadingLabel.SetBounds(ScaleX(230), ScaleY(76), WizardForm.FinishedPage.ClientWidth - ScaleX(262), ScaleY(92));
  WizardForm.FinishedHeadingLabel.Font.Size := 25;
  WizardForm.FinishedHeadingLabel.Caption := 'You''re all set.';
  WizardForm.FinishedLabel.SetBounds(ScaleX(230), ScaleY(182), WizardForm.FinishedPage.ClientWidth - ScaleX(262), ScaleY(84));
  WizardForm.FinishedLabel.Caption := 'HingeGlass is ready.' + #13#10 + #13#10 + 'Start with the angle slider, then check your lid sensor.';
  WizardForm.RunList.Left := ScaleX(230);
  WizardForm.RunList.Top := ScaleY(286);
  WizardForm.RunList.Width := WizardForm.FinishedPage.ClientWidth - ScaleX(262);
  StepLabel := TNewStaticText.Create(WizardForm);
  StepLabel.Parent := WizardForm;
  StepLabel.SetBounds(ScaleX(24), WizardForm.NextButton.Top + ScaleY(5), ScaleX(220), ScaleY(24));
  StepLabel.Font.Size := 9;
end;
procedure CurPageChanged(CurPageID: Integer);
begin
  case CurPageID of
    wpWelcome: begin StepLabel.Caption := '01  /  Welcome'; WizardForm.NextButton.Caption := 'Continue'; end;
    wpSelectDir: StepLabel.Caption := '02  /  Choose a home';
    wpSelectTasks: StepLabel.Caption := '03  /  Make it yours';
    wpReady: StepLabel.Caption := '04  /  Ready to install';
    wpInstalling: StepLabel.Caption := 'Installing HingeGlass...';
    wpFinished: begin
      StepLabel.Caption := 'Ready when you are.';
      WizardForm.FinishedLabel.SetBounds(ScaleX(230), ScaleY(182), WizardForm.FinishedPage.ClientWidth - ScaleX(262), ScaleY(84));
      WizardForm.FinishedLabel.Caption := 'HingeGlass is ready.' + #13#10 + #13#10 + 'Start with the angle slider, then check your lid sensor.';
      WizardForm.RunList.SetBounds(ScaleX(230), ScaleY(286), WizardForm.FinishedPage.ClientWidth - ScaleX(262), ScaleY(48));
    end;
  end;
end;
