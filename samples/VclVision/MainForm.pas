unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes, System.IOUtils, System.Math,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.FileCtrl, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage,
  LlamaCpp.Common.Settings,
  LlamaCpp.CType.Ggml,
  LlamaCpp.CType.Llama,
  LlamaCpp.Llama;

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
    lblMmproj: TLabel;
    edtMmproj: TEdit;
    btnBrowseMmproj: TButton;
    btnNewChat: TButton;
    btnLoad: TButton;
    pnlImage: TPanel;
    imgPreview: TImage;
    lblImageInfo: TLabel;
    btnSelectImage: TButton;
    btnClearImage: TButton;
    pnlInput: TPanel;
    pnlButtons: TPanel;
    btnSend: TButton;
    btnCancel: TButton;
    memInput: TMemo;
    memChat: TMemo;
    Llama1: TLlama;
    dlgOpenModel: TOpenDialog;
    dlgOpenImage: TOpenDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormDestroy(Sender: TObject);
    procedure btnBrowseClick(Sender: TObject);
    procedure btnReloadClick(Sender: TObject);
    procedure lbModelsDblClick(Sender: TObject);
    procedure btnBrowseMmprojClick(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
    procedure btnNewChatClick(Sender: TObject);
    procedure btnSelectImageClick(Sender: TObject);
    procedure btnClearImageClick(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure memInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Llama1Log(Sender: TObject; const ALevel: TGgmlLogLevel;
      const AText: string);
  private
    FMtmdCtx: Pointer; // PMtmdContext — opaque pointer to mtmd_context
    FImagePath: string;
    FModelFiles: TArray<string>;
    FModelLoaded: Boolean;
    FLoading: Boolean;
    FGenerating: Boolean;
    FCancelFlag: Boolean;
    FCurrentAnswer: string;
    FFirstTokenTime: TDateTime;
    FTokenCount: Integer;
    procedure ScanDirectory(const ADir: string);
    procedure AppendChat(const AText: string);
    procedure AppendChatToken(const AToken: string);
    procedure UpdateButtons;
    procedure LoadModel(const APath: string);
    procedure UnloadMtmd;
    procedure SetImagePath(const APath: string);
  end;

var
  FormMain: TFormMain;

implementation

uses
  LlamaCpp.Api,
  LlamaCpp.CType.Llava,
  LlamaCpp.Api.Llava;

{$R *.dfm}

// ---------------------------------------------------------------------------
// EOG token strings for common vision-capable models
// ---------------------------------------------------------------------------

function IsEogText(const AText: string): Boolean;
begin
  Result :=
    (AText = '</s>') or
    (AText = '<|im_end|>') or
    (AText = '<|eot_id|>') or
    (AText = '<|endoftext|>') or
    (AText = '<eos>') or
    (AText = '<end_of_turn>') or
    (AText = '<|end|>');
end;

// ---------------------------------------------------------------------------
// Form lifecycle
// ---------------------------------------------------------------------------

procedure TFormMain.FormCreate(Sender: TObject);
var
  LVersion: string;
  LWarnings: TArray<string>;
  I: Integer;
  LMsg: string;
begin
  Llama1.OnLog := Llama1Log;

  FMtmdCtx    := nil;
  FImagePath  := '';
  FModelLoaded := False;
  FLoading    := False;
  FGenerating := False;
  FCancelFlag := False;

  // Show ggml submodule version and vision capability in the status bar.
  // LibraryVersion returns the ggml SemVer (e.g. "0.11.0"), not the llama.cpp b#### tag.
  LVersion := TLlamaCppApis.LibraryVersion;
  if TLlamaCppApis.VisionAvailable then
    sbStatus.Panels[1].Text := 'ggml ' + LVersion + ' · Vision OK'
  else
    sbStatus.Panels[1].Text := 'ggml ' + LVersion + ' · Vision unavailable';

  // Warn about any critical API gaps (too-old DLLs, incomplete mtmd)
  LWarnings := TLlamaCppApis.Warnings;
  if Length(LWarnings) > 0 then
  begin
    LMsg := '';
    for I := 0 to High(LWarnings) do
      LMsg := LMsg + '• ' + LWarnings[I] + sLineBreak;
    ShowMessage(
      'DLL compatibility issues found:' + sLineBreak + sLineBreak +
      LMsg.TrimRight);
  end;

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
  UnloadMtmd;
  FModelFiles := nil;
end;

// ---------------------------------------------------------------------------
// mtmd context management
// ---------------------------------------------------------------------------

procedure TFormMain.UnloadMtmd;
var
  LSavedMask: TArithmeticExceptionMask;
begin
  if FMtmdCtx <> nil then
  begin
    LSavedMask := GetExceptionMask;
    SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
      exOverflow, exUnderflow, exPrecision]);
    try
      if Assigned(TLlavaApi.Instance.mtmd_free) then
        TLlavaApi.Instance.mtmd_free(FMtmdCtx);
    finally
      SetExceptionMask(LSavedMask);
    end;
    FMtmdCtx := nil;
  end;
end;

// ---------------------------------------------------------------------------
// Directory / model scanning
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

procedure TFormMain.btnBrowseMmprojClick(Sender: TObject);
begin
  dlgOpenModel.Title      := 'Select mmproj file';
  dlgOpenModel.InitialDir := edtDir.Text;
  if dlgOpenModel.Execute then
    edtMmproj.Text := dlgOpenModel.FileName;
end;

// ---------------------------------------------------------------------------
// Model loading
// ---------------------------------------------------------------------------

procedure TFormMain.LoadModel(const APath: string);
var
  LGpuLayers: Integer;
  LCtx: Integer;
  LMmprojPath: string;
  LThread: TThread;
begin
  if not TryStrToInt(edtGpuLayers.Text, LGpuLayers) then
    LGpuLayers := -1;
  if not TryStrToInt(edtCtx.Text, LCtx) or (LCtx < 128) then
    LCtx := 4096;

  LMmprojPath := Trim(edtMmproj.Text);

  if LMmprojPath.IsEmpty then
  begin
    ShowMessage('Please specify an mmproj file first.');
    Exit;
  end;
  if not TFile.Exists(LMmprojPath) then
  begin
    ShowMessage('mmproj file not found:' + sLineBreak + LMmprojPath);
    Exit;
  end;
  if not Assigned(TLlavaApi.Instance.mtmd_init_from_file) then
  begin
    ShowMessage('mtmd.dll not loaded or too old.' + sLineBreak +
      'Please copy mtmd.dll (llama.cpp b9050+) to the DLL directory.');
    Exit;
  end;

  Llama1.ModelPath           := APath;
  Llama1.Settings.NGpuLayers := LGpuLayers;
  Llama1.Settings.NCtx       := LCtx;
  Llama1.Settings.NBatch     := Min(LCtx, 512);
  Llama1.Settings.NUBatch    := Min(LCtx, 512);
  Llama1.Settings.FlashAttn  := cbFlashAttn.Checked;
  Llama1.Settings.OffloadKQV := cbOffloadKQV.Checked;

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

  LThread := TThread.CreateAnonymousThread(procedure
  var
    LErr: string;
    LNewMtmdCtx: PMtmdContext;
    LParams: TMtmdContextParams;
    LSavedMask: TArithmeticExceptionMask;
    LMmprojPathA: AnsiString;
  begin
    LErr        := '';
    LNewMtmdCtx := nil;
    try
      // Load main LLM
      Llama1.Init;

      // Build mtmd context
      LMmprojPathA := AnsiString(LMmprojPath);
      LSavedMask   := GetExceptionMask;
      SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
        exOverflow, exUnderflow, exPrecision]);
      try
        LParams := TLlavaApi.Instance.mtmd_context_params_default();
        LParams.NThreads := 0;  // 0 = use llama.cpp default
        LParams.Warmup   := True;
        // Flash attention type matches the context setting
        if cbFlashAttn.Checked then
          LParams.FlashAttnType := LLAMA_FLASH_ATTN_TYPE_ENABLED
        else
          LParams.FlashAttnType := LLAMA_FLASH_ATTN_TYPE_DISABLED;

        LNewMtmdCtx := TLlavaApi.Instance.mtmd_init_from_file(
          PAnsiChar(LMmprojPathA), Llama1.LlamaModel, LParams);
      finally
        SetExceptionMask(LSavedMask);
      end;

      if LNewMtmdCtx = nil then
        raise Exception.Create('Failed to create mtmd context.' +
          sLineBreak + 'Make sure the mmproj and model match.');

      if Assigned(TLlavaApi.Instance.mtmd_support_vision) then
        if not TLlavaApi.Instance.mtmd_support_vision(LNewMtmdCtx) then
          raise Exception.Create('The selected mmproj does not support image input.');
    except
      on E: Exception do
        LErr := E.Message;
    end;

    TThread.Queue(nil, procedure
    begin
      FLoading := False;

      if LErr.IsEmpty then
      begin
        UnloadMtmd;
        FMtmdCtx         := LNewMtmdCtx;
        FModelLoaded     := True;
        btnLoad.Caption  := 'Reload';
        sbStatus.Panels[0].Text := TPath.GetFileNameWithoutExtension(APath);
        sbStatus.Panels[1].Text := 'Ready';
        memChat.Clear;
        AppendChat('=== ' + TPath.GetFileName(APath) + ' ===');
        AppendChat('System: ' + memSystemPrompt.Lines.Text.Trim);
        AppendChat('');
      end else begin
        if LNewMtmdCtx <> nil then
        begin
          LSavedMask := GetExceptionMask;
          SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
            exOverflow, exUnderflow, exPrecision]);
          try
            TLlavaApi.Instance.mtmd_free(LNewMtmdCtx);
          finally
            SetExceptionMask(LSavedMask);
          end;
        end;
        btnLoad.Caption         := 'Load model';
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
// Image selection
// ---------------------------------------------------------------------------

procedure TFormMain.SetImagePath(const APath: string);
begin
  FImagePath := APath;
  if APath.IsEmpty then
  begin
    lblImageInfo.Caption   := 'No image selected';
    imgPreview.Picture.Assign(nil);
    btnClearImage.Enabled  := False;
  end else begin
    lblImageInfo.Caption := TPath.GetFileName(APath);
    try
      imgPreview.Picture.LoadFromFile(APath);
    except
      on E: Exception do
      begin
        lblImageInfo.Caption := 'Preview unavailable: ' + E.Message;
        imgPreview.Picture.Assign(nil);
      end;
    end;
    btnClearImage.Enabled := True;
  end;
end;

procedure TFormMain.btnSelectImageClick(Sender: TObject);
begin
  if dlgOpenImage.Execute then
    SetImagePath(dlgOpenImage.FileName);
end;

procedure TFormMain.btnClearImageClick(Sender: TObject);
begin
  SetImagePath('');
end;

procedure TFormMain.btnNewChatClick(Sender: TObject);
begin
  if not FModelLoaded then
    Exit;
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

  btnLoad.Enabled         := not FLoading and not FGenerating;
  btnSend.Enabled         := LCanInteract;
  btnCancel.Enabled       := FGenerating;
  memInput.Enabled        := LCanInteract;
  btnNewChat.Enabled      := LCanInteract;
  btnSelectImage.Enabled  := LCanInteract;
  btnClearImage.Enabled   := LCanInteract and not FImagePath.IsEmpty;
  lbModels.Enabled        := not FLoading and not FGenerating;
  edtDir.Enabled          := not FLoading and not FGenerating;
  btnBrowse.Enabled       := not FLoading and not FGenerating;
  btnReload.Enabled       := not FLoading and not FGenerating;
  edtMmproj.Enabled       := not FLoading and not FGenerating;
  btnBrowseMmproj.Enabled := not FLoading and not FGenerating;
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
// Inference
// ---------------------------------------------------------------------------

procedure TFormMain.btnSendClick(Sender: TObject);
var
  LQuestion: string;
  LSystemPrompt: string;
  LCapturedImagePath: string;
  LNBatch: Integer;
  LThread: TThread;
begin
  LQuestion := Trim(memInput.Text);
  if LQuestion.IsEmpty then
    Exit;
  if not FModelLoaded then
  begin
    ShowMessage('Please load a model first.');
    Exit;
  end;
  if (not FImagePath.IsEmpty) and (FMtmdCtx = nil) then
  begin
    ShowMessage('mtmd context unavailable. Please reload the model.');
    Exit;
  end;

  LSystemPrompt      := memSystemPrompt.Lines.Text.Trim;
  LCapturedImagePath := FImagePath;
  LNBatch            := Llama1.Settings.NBatch;

  memInput.Clear;
  FCurrentAnswer  := '';
  FTokenCount     := 0;
  FFirstTokenTime := 0;
  FCancelFlag     := False;
  FGenerating     := True;
  UpdateButtons;

  AppendChat('User:');
  if not LCapturedImagePath.IsEmpty then
    AppendChat('[Image: ' + TPath.GetFileName(LCapturedImagePath) + ']');
  AppendChat(LQuestion);
  AppendChat('');
  AppendChat('Assistant:');

  sbStatus.Panels[1].Text := 'Generating...';
  sbStatus.Panels[2].Text := '';

  LThread := TThread.CreateAnonymousThread(procedure
  var
    LErr: string;
    LBitmap: PMtmdBitmap;
    LChunks: PMtmdInputChunks;
    LInputText: TMtmdInputText;
    LInputTextUtf8: UTF8String;
    LImagePathA: AnsiString;
    LMarkerStr: string;
    LNPast: TLlamaPos;
    LRetVal: Int32;
    LSavedMask: TArithmeticExceptionMask;
    LSamplerSettings: TLlamaSamplerSettings;
    LPreBytes: TBytes;
    LPreTokens: TArray<Integer>;
  begin
    LErr     := '';
    LBitmap  := nil;
    LChunks  := nil;
    try
      // Reset KV cache for this single-shot generation
      Llama1.NumberOfTokens := 0;

      if not LCapturedImagePath.IsEmpty then
      begin
        // Flush KV cache: Eval([]) triggers KvCacheSeqRm(-1, 0, -1) without decoding
        Llama1.Eval([]);

        // --- Vision path: use mtmd API for text + image ---
        LSavedMask := GetExceptionMask;
        SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
          exOverflow, exUnderflow, exPrecision]);
        try
          // Load image as bitmap
          LImagePathA := AnsiString(LCapturedImagePath);
          LBitmap := TLlavaApi.Instance.mtmd_helper_bitmap_init_from_file(
            FMtmdCtx, PAnsiChar(LImagePathA));
        finally
          SetExceptionMask(LSavedMask);
        end;

        if LBitmap = nil then
          raise Exception.Create('Failed to load image: ' +
            TPath.GetFileName(LCapturedImagePath));

        // Get the default media marker ("<__media__>")
        if Assigned(TLlavaApi.Instance.mtmd_default_marker) then
          LMarkerStr := string(AnsiString(TLlavaApi.Instance.mtmd_default_marker()))
        else
          LMarkerStr := '<__media__>';

        // Build prompt: system + image marker + question + assistant tag
        // UTF8String ensures correct encoding for non-ASCII characters
        if LSystemPrompt.IsEmpty then
          LInputTextUtf8 := UTF8String('USER: ' + LMarkerStr +
            #10 + LQuestion + #10 + 'ASSISTANT:')
        else
          LInputTextUtf8 := UTF8String('SYSTEM: ' + LSystemPrompt +
            #10 + 'USER: ' + LMarkerStr +
            #10 + LQuestion + #10 + 'ASSISTANT:');

        LInputText.Text         := PAnsiChar(LInputTextUtf8);
        LInputText.AddSpecial   := True;
        LInputText.ParseSpecial := True;

        // Tokenize text + image together
        LSavedMask := GetExceptionMask;
        SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
          exOverflow, exUnderflow, exPrecision]);
        try
          LChunks := TLlavaApi.Instance.mtmd_input_chunks_init();
          if LChunks = nil then
            raise Exception.Create('mtmd_input_chunks_init failed');

          LRetVal := TLlavaApi.Instance.mtmd_tokenize(
            FMtmdCtx, LChunks, @LInputText, @LBitmap, 1);
        finally
          SetExceptionMask(LSavedMask);
        end;

        if LRetVal <> 0 then
          raise Exception.CreateFmt(
            'mtmd_tokenize failed (code %d). ' +
            'Check image marker in prompt.', [LRetVal]);

        // Evaluate all chunks (text + image embeddings) into the KV cache
        LNPast  := 0;
        LSavedMask := GetExceptionMask;
        SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
          exOverflow, exUnderflow, exPrecision]);
        try
          LRetVal := TLlavaApi.Instance.mtmd_helper_eval_chunks(
            FMtmdCtx,
            Llama1.LlamaContext,
            LChunks,
            0,          // n_past: start at position 0
            0,          // seq_id: sequence 0
            LNBatch,    // n_batch
            True,       // logits_last: needed so Generate can sample the first response token
            @LNPast);   // receives updated position count
        finally
          SetExceptionMask(LSavedMask);
        end;

        if LRetVal <> 0 then
          raise Exception.CreateFmt(
            'mtmd_helper_eval_chunks failed (code %d).', [LRetVal]);

        // Sync position into the Llama wrapper
        Llama1.NumberOfTokens := LNPast;

        // Generate: no extra tokens needed, all input is already in the KV cache
        LSamplerSettings := TLlamaSamplerSettings.Create(
          40, 0.95, 0.05, 1.0, 0.8, 1.1, 0.0, 0.0);

        Llama1.Generate([],
          LSamplerSettings,
          function(const AToken: Integer; var AContinue: Boolean): TArray<Integer>
          var
            LPiece: TBytes;
            LText: string;
            LCurrToken: string;
          begin
            Result    := nil;
            AContinue := not FCancelFlag;
            if not AContinue then
              Exit;

            LPiece := Llama1.Detokenize([AToken], nil, True);
            LText  := TEncoding.UTF8.GetString(LPiece);

            if IsEogText(LText) then
            begin
              AContinue := False;
              Exit;
            end;

            if FFirstTokenTime = 0 then
              FFirstTokenTime := Now;
            Inc(FTokenCount);

            FCurrentAnswer := FCurrentAnswer + LText;

            LCurrToken := LText;
            TThread.Queue(nil, procedure
            begin
              AppendChatToken(LCurrToken);
            end);
          end,
          False  // AReset = False: KV cache already contains the full input
        );

      end else begin
        // --- Text-only path (no image selected) ---
        if LSystemPrompt.IsEmpty then
          LPreBytes := TEncoding.UTF8.GetBytes('USER: ' + LQuestion +
            #10 + 'ASSISTANT:')
        else
          LPreBytes := TEncoding.UTF8.GetBytes('SYSTEM: ' + LSystemPrompt +
            #10 + 'USER: ' + LQuestion + #10 + 'ASSISTANT:');

        LPreTokens := Llama1.Tokenize(LPreBytes, True, True);
        Llama1.Eval(LPreTokens);

        LSamplerSettings := TLlamaSamplerSettings.Create(
          40, 0.95, 0.05, 1.0, 0.8, 1.1, 0.0, 0.0);

        Llama1.Generate([],
          LSamplerSettings,
          function(const AToken: Integer; var AContinue: Boolean): TArray<Integer>
          var
            LPiece: TBytes;
            LText: string;
            LCurrToken: string;
          begin
            Result    := nil;
            AContinue := not FCancelFlag;
            if not AContinue then
              Exit;

            LPiece := Llama1.Detokenize([AToken], nil, True);
            LText  := TEncoding.UTF8.GetString(LPiece);

            if IsEogText(LText) then
            begin
              AContinue := False;
              Exit;
            end;

            if FFirstTokenTime = 0 then
              FFirstTokenTime := Now;
            Inc(FTokenCount);

            FCurrentAnswer := FCurrentAnswer + LText;

            LCurrToken := LText;
            TThread.Queue(nil, procedure
            begin
              AppendChatToken(LCurrToken);
            end);
          end,
          False  // AReset = False
        );
      end;

    except
      on E: Exception do
        LErr := E.Message;
    end;

    // Cleanup mtmd objects (always, even on error)
    if LBitmap <> nil then
    begin
      LSavedMask := GetExceptionMask;
      SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
        exOverflow, exUnderflow, exPrecision]);
      try
        if Assigned(TLlavaApi.Instance.mtmd_bitmap_free) then
          TLlavaApi.Instance.mtmd_bitmap_free(LBitmap);
      finally
        SetExceptionMask(LSavedMask);
      end;
    end;

    if LChunks <> nil then
    begin
      LSavedMask := GetExceptionMask;
      SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
        exOverflow, exUnderflow, exPrecision]);
      try
        if Assigned(TLlavaApi.Instance.mtmd_input_chunks_free) then
          TLlavaApi.Instance.mtmd_input_chunks_free(LChunks);
      finally
        SetExceptionMask(LSavedMask);
      end;
    end;

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

      FCurrentAnswer := '';
      FGenerating    := False;
      FCancelFlag    := False;

      if LErr <> '' then
        ShowMessage('Generation error:' + sLineBreak + LErr);

      AppendChat('');
      UpdateButtons;
      sbStatus.Panels[1].Text := 'Ready';
      memInput.SetFocus;
    end);
  end);

  LThread.FreeOnTerminate := True;
  LThread.Start;
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

procedure TFormMain.Llama1Log(Sender: TObject; const ALevel: TGgmlLogLevel;
  const AText: string);
var
  LText: string;
begin
  if ALevel < GGML_LOG_LEVEL_WARN then
    Exit;
  LText := AText.Trim;
  if LText.IsEmpty then
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
