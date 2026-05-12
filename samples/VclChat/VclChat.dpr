program VclChat;
uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {FormMain};

{$R *.res}
begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'VCL Chat';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
