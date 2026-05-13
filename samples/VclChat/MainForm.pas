unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.IOUtils, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.FileCtrl,
  LlamaCpp.Llama,
  LlamaCpp.Common.Chat.Types,
  LlamaCpp.CType.Ggml;

type
  TFormMain = class(TForm)
    sbStatus: TStatusBar;
    pnlTop: TPanel;
    lblDir: TLabel;
    edtDir: TEdit;
    btnBrowse: TButton;
    btnReload: TButton;
    pnlLeft: TPanel;
    lblModels: TLabel;
    lbModels: TListBox;
    Splitter1: TSplitter;
    pnlMain: TPanel;
    pnlSettings: TPanel;
    gbSettings: TGroupBox;
    lblSystemPrompt: TLabel;
    memSystemPrompt: TMemo;
    lblGpuLayers: TLabel;
    edtGpuLayers: TEdit;
    lblCtx: TLabel;
    edtCtx: TEdit;
    cbFlashAttn: TCheckBox;
    cbTypeKV: TCheckBox;
    cbOffloadKQV: TCheckBox;
    btnNewChat: TButton;
    btnLoad: TButton;
    pnlInput: TPanel;
    pnlButtons: TPanel;
    btnSend: TButton;
    btnCancel: TButton;
    memInput: TMemo;
    memChat: TMemo;
    Llama1: TLlama;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnReloadClick(Sender: TObject);
    procedure lbModelsDblClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnNewChatClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure memInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Llama1ChatCompletionStream(Sender: TObject;
      const AResponse: TChatCompletionStreamResponse; var AContinue: Boolean);
    procedure Llama1ChatCompletionStreamComplete(Sender: TObject);
    procedure Llama1Log(Sender: TObject; const ALevel: TGgmlLogLevel;
      const AText: string);
  private
    FChatMessages: TArray<TChatCompletionRequestMessage>;
    FModelFiles: TArray<string>;
    FModelLoaded: Boolean;
    FLoading: Boolean;    // model load in progress
    FGenerating: Boolean; // inference in progress
    FCancelFlag: Boolean; // set by Cancel button; checked by stream callback
    FCurrentAnswer: string;
    FFirstTokenTime: TDateTime;
    FTokenCount: Integer;
    FVramUsedMiB: Double; // GPU buffer MiB accumulated from load-time log messages
    FCpuAllocMiB: Double; // CPU buffer MiB accumulated from load-time log messages
    procedure ScanDirectory(const ADir: string);
    procedure AppendChat(const AText: string);
    procedure AppendChatToken(const AToken: string);
    procedure UpdateButtons;
    procedure InitChatHistory;
    procedure LoadModel(const APath: string);
  end;

var
  FormMain: TFormMain;

implementation

uses
  LlamaCpp.Api;

{$R *.dfm}

// ---------------------------------------------------------------------------
// NVML helper — queries live VRAM from nvidia-ml (optional, GPU 0 only)
// ---------------------------------------------------------------------------

type
  TNvmlDevice = Pointer;
  TNvmlMemory = record
    Total: UInt64; // bytes
    Free:  UInt64; // bytes
    Used:  UInt64; // bytes
  end;
  TNvmlInitFn   = function: Integer; cdecl;
  TNvmlGetHndFn = function(Idx: Cardinal; out Dev: TNvmlDevice): Integer; cdecl;
  TNvmlGetMemFn = function(Dev: TNvmlDevice; out Mem: TNvmlMemory): Integer; cdecl;
  TNvmlShutdnFn = function: Integer; cdecl;

function QueryNvmlVramMiB(out AUsedMiB, AFreeMiB: UInt64): Boolean;
var
  LLib:    THandle;
  LInit:   TNvmlInitFn;
  LGetHnd: TNvmlGetHndFn;
  LGetMem: TNvmlGetMemFn;
  LShutdn: TNvmlShutdnFn;
  LDev:    TNvmlDevice;
  LMem:    TNvmlMemory;
begin
  Result   := False;
  AUsedMiB := 0;
  AFreeMiB := 0;
  LLib := Winapi.Windows.LoadLibrary('nvml.dll');
  if LLib = 0 then Exit;
  try
    @LInit   := Winapi.Windows.GetProcAddress(LLib, 'nvmlInit_v2');
    @LGetHnd := Winapi.Windows.GetProcAddress(LLib, 'nvmlDeviceGetHandleByIndex_v2');
    @LGetMem := Winapi.Windows.GetProcAddress(LLib, 'nvmlDeviceGetMemoryInfo');
    @LShutdn := Winapi.Windows.GetProcAddress(LLib, 'nvmlShutdown');
    if Assigned(LInit) and Assigned(LGetHnd) and Assigned(LGetMem) and
       (LInit() = 0) then
    try
      LDev := nil;
      if (LGetHnd(0, LDev) = 0) and (LGetMem(LDev, LMem) = 0) then
      begin
        AUsedMiB := LMem.Used shr 20;
        AFreeMiB := LMem.Free shr 20;
        Result   := True;
      end;
    finally
      if Assigned(LShutdn) then LShutdn();
    end;
  finally
    Winapi.Windows.FreeLibrary(LLib);
  end;
end;

// ---------------------------------------------------------------------------
// Form lifecycle
// ---------------------------------------------------------------------------

procedure TFormMain.FormCreate(Sender: TObject);
begin
  Llama1.OnChatCompletionStream        := Llama1ChatCompletionStream;
  Llama1.OnChatCompletionStreamComplete := Llama1ChatCompletionStreamComplete;
  Llama1.OnLog                          := Llama1Log;

  FModelLoaded := False;
  FLoading     := False;
  FGenerating  := False;
  FCancelFlag  := False;

  UpdateButtons;
end;

procedure TFormMain.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FLoading or FGenerating then
  begin
    CanClose := False;
    ShowMessage('Please wait for the current operation to complete or be cancelled.');
  end;
end;

procedure TFormMain.FormDestroy(Sender: TObject);
begin
  FModelFiles   := nil;
  FChatMessages := nil;
end;

// ---------------------------------------------------------------------------
// Directory scanning
// ---------------------------------------------------------------------------

procedure TFormMain.ScanDirectory(const ADir: string);
var
  LFiles: TArray<string>;
  LBase: string;
  LDisplay: string;
  I: Integer;
begin
  lbModels.Items.BeginUpdate;
  try
    lbModels.Items.Clear;
  finally
    lbModels.Items.EndUpdate;
  end;
  FModelFiles := nil;

  if not TDirectory.Exists(ADir) then
  begin
    sbStatus.Panels[1].Text := 'Directory not found';
    Exit;
  end;

  LBase  := IncludeTrailingPathDelimiter(ADir);
  LFiles := TDirectory.GetFiles(ADir, '*.gguf', TSearchOption.soAllDirectories);
  SetLength(FModelFiles, Length(LFiles));

  lbModels.Items.BeginUpdate;
  try
    for I := 0 to High(LFiles) do
    begin
      FModelFiles[I] := LFiles[I];
      LDisplay := LFiles[I];
      if LDisplay.StartsWith(LBase, True) then
        LDisplay := LDisplay.Substring(Length(LBase));
      lbModels.Items.Add(LDisplay);
    end;
  finally
    lbModels.Items.EndUpdate;
  end;

  sbStatus.Panels[1].Text := Format('%d model(s) found', [Length(LFiles)]);
end;

procedure TFormMain.btnBrowseClick(Sender: TObject);
var
  LDir: string;
begin
  LDir := edtDir.Text;
  if SelectDirectory('Select model directory', '', LDir) then
  begin
    edtDir.Text := LDir;
    ScanDirectory(LDir);
  end;
end;

procedure TFormMain.btnReloadClick(Sender: TObject);
begin
  ScanDirectory(edtDir.Text);
end;

procedure TFormMain.lbModelsDblClick(Sender: TObject);
begin
  if lbModels.ItemIndex >= 0 then
    btnLoadClick(btnLoad);
end;

// ---------------------------------------------------------------------------
// Model loading
// ---------------------------------------------------------------------------

procedure TFormMain.LoadModel(const APath: string);
var
  LGpuLayers: Integer;
  LCtx: Integer;
  LThread: TThread;
begin
  if not TryStrToInt(edtGpuLayers.Text, LGpuLayers) then
    LGpuLayers := -1;
  if not TryStrToInt(edtCtx.Text, LCtx) or (LCtx < 128) then
    LCtx := 4096;

  Llama1.ModelPath            := APath;
  Llama1.Settings.NGpuLayers  := LGpuLayers;
  Llama1.Settings.NCtx        := LCtx;
  Llama1.Settings.NBatch      := Min(LCtx, 512);
  Llama1.Settings.NUBatch     := Min(LCtx, 512);
  Llama1.Settings.FlashAttn   := cbFlashAttn.Checked;
  Llama1.Settings.OffloadKQV  := cbOffloadKQV.Checked;

  if cbTypeKV.Checked then
  begin
    Llama1.Settings.TypeK := TGGMLType.GGML_TYPE_Q8_0;
    Llama1.Settings.TypeV := TGGMLType.GGML_TYPE_Q8_0;
  end else begin
    Llama1.Settings.TypeK := TGGMLType.GGML_TYPE_F16;
    Llama1.Settings.TypeV := TGGMLType.GGML_TYPE_F16;
  end;

  FLoading        := True;
  FModelLoaded    := False;
  btnLoad.Caption := 'Loading...';
  UpdateButtons;

  sbStatus.Panels[0].Text := 'Loading: ' + TPath.GetFileName(APath);
  sbStatus.Panels[1].Text := 'Loading model...';
  sbStatus.Panels[2].Text := '';
  sbStatus.Panels[3].Text := '';
  FVramUsedMiB            := 0;
  FCpuAllocMiB            := 0;

  LThread := TThread.CreateAnonymousThread(procedure
  var
    LErr: string;
  begin
    LErr := '';
    try
      Llama1.Init;
    except
      on E: Exception do
        LErr := E.Message;
    end;

    TThread.Queue(nil, procedure
    var
      LVramUsed, LVramFree: UInt64;
    begin
      FLoading := False;

      if LErr.IsEmpty then
      begin
        FModelLoaded      := True;
        btnLoad.Caption   := 'Reload';
        sbStatus.Panels[0].Text := TPath.GetFileNameWithoutExtension(APath);
        sbStatus.Panels[1].Text := 'Ready';
        if QueryNvmlVramMiB(LVramUsed, LVramFree) then
          sbStatus.Panels[3].Text :=
            Format('VRAM: %d MiB used, %d MiB free', [Int64(LVramUsed), Int64(LVramFree)])
        else if FVramUsedMiB > 0 then
          sbStatus.Panels[3].Text :=
            Format('GPU: %.0f MiB', [FVramUsedMiB])
        else if FCpuAllocMiB > 0 then
          sbStatus.Panels[3].Text :=
            Format('CPU: %.0f MiB', [FCpuAllocMiB]);
        InitChatHistory;
        memChat.Clear;
        AppendChat('=== ' + TPath.GetFileName(APath) + ' ===');
        AppendChat('System: ' + memSystemPrompt.Lines.Text.Trim);
        AppendChat('');
      end else begin
        btnLoad.Caption   := 'Load model';
        sbStatus.Panels[0].Text := 'No model loaded';
        sbStatus.Panels[1].Text := 'Load error';
        ShowMessage('Error loading model:' + sLineBreak + LErr);
      end;

      UpdateButtons;
      if FModelLoaded then
        memInput.SetFocus;
    end);
  end);

  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

procedure TFormMain.btnLoadClick(Sender: TObject);
var
  LPath: string;
begin
  if lbModels.ItemIndex < 0 then
  begin
    ShowMessage('Please select a model from the list first.');
    Exit;
  end;

  LPath := FModelFiles[lbModels.ItemIndex];
  if not TFile.Exists(LPath) then
  begin
    ShowMessage('Model file not found:' + sLineBreak + LPath);
    Exit;
  end;

  LoadModel(LPath);
end;

// ---------------------------------------------------------------------------
// Chat history
// ---------------------------------------------------------------------------

procedure TFormMain.InitChatHistory;
var
  LSystemPrompt: string;
begin
  LSystemPrompt := memSystemPrompt.Lines.Text.Trim;
  if LSystemPrompt.IsEmpty then
    LSystemPrompt := 'You are a helpful assistant.';
  FChatMessages := [TChatCompletionRequestMessage.System(LSystemPrompt)];
end;

procedure TFormMain.btnNewChatClick(Sender: TObject);
begin
  if not FModelLoaded then
    Exit;
  InitChatHistory;
  FCurrentAnswer := '';
  memChat.Clear;
  AppendChat('=== New Chat ===');
  AppendChat('System: ' + memSystemPrompt.Lines.Text.Trim);
  AppendChat('');
  memInput.SetFocus;
end;

// ---------------------------------------------------------------------------
// UI state
// ---------------------------------------------------------------------------

procedure TFormMain.UpdateButtons;
var
  LCanInteract: Boolean;
begin
  LCanInteract := FModelLoaded and not FLoading and not FGenerating;

  btnLoad.Enabled    := not FLoading and not FGenerating;
  btnSend.Enabled    := LCanInteract;
  btnCancel.Enabled  := FGenerating;
  memInput.Enabled   := LCanInteract;
  btnNewChat.Enabled := LCanInteract;
  lbModels.Enabled   := not FLoading and not FGenerating;
  edtDir.Enabled     := not FLoading and not FGenerating;
  btnBrowse.Enabled  := not FLoading and not FGenerating;
  btnReload.Enabled  := not FLoading and not FGenerating;
end;

procedure TFormMain.AppendChat(const AText: string);
begin
  memChat.Lines.Add(AText);
  SendMessage(memChat.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TFormMain.AppendChatToken(const AToken: string);
var
  LParts: TArray<string>;
  LLast: Integer;
  I: Integer;
begin
  if AToken.IsEmpty then
    Exit;

  LParts := AToken.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);

  memChat.Lines.BeginUpdate;
  try
    LLast := memChat.Lines.Count - 1;
    if LLast < 0 then
    begin
      memChat.Lines.Add('');
      LLast := 0;
    end;

    memChat.Lines[LLast] := memChat.Lines[LLast] + LParts[0];

    for I := 1 to High(LParts) do
    begin
      memChat.Lines.Add(LParts[I]);
      Inc(LLast);
    end;
  finally
    memChat.Lines.EndUpdate;
  end;

  SendMessage(memChat.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

// ---------------------------------------------------------------------------
// Sending messages
// ---------------------------------------------------------------------------

procedure TFormMain.btnSendClick(Sender: TObject);
var
  LText: string;
  LSettings: TLlamaChatCompletionSettings;
begin
  LText := Trim(memInput.Text);
  if LText.IsEmpty then
    Exit;
  if not FModelLoaded then
  begin
    ShowMessage('Please load a model first.');
    Exit;
  end;

  FChatMessages := FChatMessages + [TChatCompletionRequestMessage.User(LText)];

  memInput.Clear;
  FCurrentAnswer  := '';
  FTokenCount     := 0;
  FFirstTokenTime := 0;
  FCancelFlag     := False;
  FGenerating     := True;
  UpdateButtons;

  AppendChat('You:');
  AppendChat(LText);
  AppendChat('');
  AppendChat('Assistant:');

  LSettings := TLlamaChatCompletionSettings.Create(FChatMessages);
  Llama1.CreateChatCompletionStream(LSettings);
end;

procedure TFormMain.btnCancelClick(Sender: TObject);
begin
  btnCancel.Enabled := False;
  FCancelFlag       := True;
end;

procedure TFormMain.memInputKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_RETURN) and not (ssShift in Shift) and btnSend.Enabled then
  begin
    Key := 0;
    btnSendClick(btnSend);
  end;
end;

// ---------------------------------------------------------------------------
// TLlama event handlers
// ---------------------------------------------------------------------------

procedure TFormMain.Llama1ChatCompletionStream(Sender: TObject;
  const AResponse: TChatCompletionStreamResponse; var AContinue: Boolean);
var
  LToken: string;
begin
  AContinue := not FCancelFlag;
  if not AContinue then
    Exit;

  if not (Assigned(AResponse.Choices) and (Length(AResponse.Choices) > 0)) then
    Exit;

  LToken := VarToStr(AResponse.Choices[0].Delta.Content);
  if LToken.IsEmpty then
    Exit;

  if FFirstTokenTime = 0 then
    FFirstTokenTime := Now;
  Inc(FTokenCount);

  FCurrentAnswer := FCurrentAnswer + LToken;

  TThread.Queue(nil, procedure
  begin
    AppendChatToken(LToken);
  end);
end;

procedure TFormMain.Llama1ChatCompletionStreamComplete(Sender: TObject);
begin
  TThread.Queue(nil, procedure
  var
    LElapsed: Double;
  begin
    if (FTokenCount > 0) and (FFirstTokenTime > 0) then
    begin
      LElapsed := (Now - FFirstTokenTime) * 86400.0;
      if LElapsed > 0.001 then
        sbStatus.Panels[2].Text := Format('%.1f tok/s', [FTokenCount / LElapsed])
      else
        sbStatus.Panels[2].Text := '';
    end;

    if not FCancelFlag then
      FChatMessages := FChatMessages +
        [TChatCompletionRequestMessage.Assistant(FCurrentAnswer)];

    FCurrentAnswer := '';
    FGenerating    := False;
    FCancelFlag    := False;

    AppendChat('');
    UpdateButtons;
    sbStatus.Panels[1].Text := 'Ready';
    memInput.SetFocus;
  end);
end;

procedure TFormMain.Llama1Log(Sender: TObject; const ALevel: TGgmlLogLevel;
  const AText: string);
var
  LText: string;
  LPos, LNumStart: Integer;
  LNumStr: string;
  LMiB: Double;
  LFS: TFormatSettings;
begin
  LText := AText.Trim;
  if LText.IsEmpty then
    Exit;

  // Accumulate GPU/CPU allocation from llama.cpp load messages (any log level).
  // Patterns: "llm_load_tensors:  CUDA[N] buffer size =  1234.56 MiB"
  //           "llm_load_tensors:        CPU buffer size =   274.83 MiB"
  if Pos('buffer size', LText) > 0 then
  begin
    LPos := Pos('=', LText);
    if LPos > 0 then
    begin
      LNumStart := LPos + 1;
      while (LNumStart <= Length(LText)) and (LText[LNumStart] = ' ') do
        Inc(LNumStart);
      LNumStr := '';
      while (LNumStart <= Length(LText)) and
            CharInSet(LText[LNumStart], ['0'..'9', '.']) do
      begin
        LNumStr := LNumStr + LText[LNumStart];
        Inc(LNumStart);
      end;
      LFS := TFormatSettings.Create;
      LFS.DecimalSeparator := '.';
      if TryStrToFloat(LNumStr, LMiB, LFS) then
      begin
        if Pos('CUDA', LText) > 0 then
          FVramUsedMiB := FVramUsedMiB + LMiB
        else if Pos('CPU', LText) > 0 then
          FCpuAllocMiB := FCpuAllocMiB + LMiB;
      end;
    end;
  end;

  if ALevel < GGML_LOG_LEVEL_WARN then
    Exit;
  TThread.Queue(nil, procedure
  begin
    sbStatus.Panels[1].Text := LText;
  end);
end;

// ---------------------------------------------------------------------------

initialization
  TLlamaCppApis.LoadAll(
    TPath.Combine(
    TPath.Combine(
      TDirectory.GetParent(
      TDirectory.GetParent(
      TDirectory.GetParent(
        TDirectory.GetParent(
          TPath.GetDirectoryName(
            ParamStr(0)))))), 'lib'), 'win_x64_cuda_13'));

finalization
  TLlamaCppApis.UnloadAll;

end.
