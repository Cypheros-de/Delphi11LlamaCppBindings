unit LlamaCpp.Api;

interface

uses
  System.SysUtils
{$IFDEF MSWINDOWS}
    , Winapi.Windows
{$ENDIF MSWINDOWS};

type
  TLlamaCppLibraryLoader = class
  strict private
    FLibAddr: THandle;
  protected
    function GetProcAddress(const AHandle: THandle;
      const AProcName: string): pointer;
    procedure DoLoadLibrary(const ALibAddr: THandle); virtual; abstract;
  public
    procedure Load(const ALibraryPath: string);
    procedure Unload();
  end;

  TLlamaCppApis = class
  public
    class procedure LoadAll(ALibDir: string = '');
    class procedure UnloadAll();

    // ggml submodule version from ggml-base.dll (e.g. "0.11.0") or "(unknown)".
    // Note: this is the ggml SemVer tag, NOT the llama.cpp "b####" build number.
    // The llama.cpp build number is not exported by any DLL function.
    class function LibraryVersion: string;

    // True when all required mtmd functions are present (vision inference ready).
    class function VisionAvailable: Boolean;

    // Returns one entry per critical API gap found after LoadAll.
    // Empty = all required functions resolved successfully.
    class function Warnings: TArray<string>;
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  LlamaCpp.Api.Ggml,
  LlamaCpp.Api.Llava,
  LlamaCpp.Api.Llama;

{ TLlamaCppLibraryLoader }

procedure TLlamaCppLibraryLoader.Load(const ALibraryPath: string);
begin
  if not TFile.Exists(ALibraryPath) then
    raise Exception.CreateFmt('Library "%s" not found.', [ALibraryPath]);

{$IFDEF MSWINDOWS}
  FLibAddr := Winapi.Windows.LoadLibraryEx(PWideChar(WideString(ALibraryPath)),
    0, LOAD_WITH_ALTERED_SEARCH_PATH);
{$ELSE}
  FLibAddr := System.SysUtils.LoadLibrary(PWideChar(WideString(ALibraryPath)));
{$ENDIF MSWINDOWS}
  if FLibAddr = 0 then
    raise Exception.CreateFmt('Unable to load llama library. %s', [SysErrorMessage(GetLastError)]);
  DoLoadLibrary(FLibAddr);
end;

procedure TLlamaCppLibraryLoader.Unload;
begin
{$IFDEF MSWINDOWS}
  Winapi.Windows.FreeLibrary(FLibAddr);
{$ELSE}
  System.SysUtils.FreeLibrary(FLibAddr);
{$ENDIF MSWINDOWS}
end;

function TLlamaCppLibraryLoader.GetProcAddress(const AHandle: THandle;
  const AProcName: string): pointer;
begin
{$IFDEF MSWINDOWS}
  Result := Winapi.Windows.GetProcAddress(AHandle,
    PWideChar(WideString(AProcName)));
{$ELSE}
  Result := System.SysUtils.GetProcAddress(AHandle,
    PWideChar(WideString(AProcName)));
{$ENDIF MSWINDOWS}
end;

{$IFDEF MSWINDOWS}
type
  TGgmlVersionFn = function: PAnsiChar; cdecl;
{$ENDIF MSWINDOWS}

{ TLlamaCppApis }

class function TLlamaCppApis.LibraryVersion: string;
var
{$IFDEF MSWINDOWS}
  LHandle: HMODULE;
  LVersionFn: TGgmlVersionFn;
{$ENDIF MSWINDOWS}
begin
{$IFDEF MSWINDOWS}
  // ggml-base.dll is pulled into the process by ggml_backend_load_all_from_path;
  // ggml_version() returns the ggml submodule SemVer (e.g. "0.11.0"),
  // which is distinct from the llama.cpp "b####" build number.
  LHandle := GetModuleHandle('ggml-base.dll');
  if LHandle <> 0 then
  begin
    @LVersionFn := Winapi.Windows.GetProcAddress(LHandle, 'ggml_version');
    if Assigned(LVersionFn) then
    begin
      Result := string(AnsiString(LVersionFn()));
      Exit;
    end;
  end;
{$ENDIF MSWINDOWS}
  Result := '(unknown)';
end;

class function TLlamaCppApis.VisionAvailable: Boolean;
begin
  // mtmd_helper_init_opt_default marks the b11900 signature of
  // mtmd_helper_bitmap_init_from_file; older DLLs use an incompatible one.
  Result := Assigned(TLlavaApi.Instance.mtmd_init_from_file) and
            Assigned(TLlavaApi.Instance.mtmd_helper_eval_chunks) and
            Assigned(TLlavaApi.Instance.mtmd_helper_init_opt_default);
end;

class function TLlamaCppApis.Warnings: TArray<string>;
begin
  Result := nil;

  // Core llama.dll — fatal if any of these are missing
  if not Assigned(TLlamaApi.Instance.llama_model_load_from_file) then
    Result := Result + ['llama.dll: llama_model_load_from_file missing (requires b4500+)'];
  if not Assigned(TLlamaApi.Instance.llama_init_from_model) then
    Result := Result + ['llama.dll: llama_init_from_model missing (requires b4500+)'];
  if not Assigned(TLlamaApi.Instance.llama_get_memory) then
    Result := Result + ['llama.dll: llama_get_memory missing (requires b8000+)'];

  // mtmd.dll — only report when it IS loaded but an expected function is absent
  if Assigned(TLlavaApi.Instance.mtmd_init_from_file) and
     not Assigned(TLlavaApi.Instance.mtmd_helper_eval_chunks) then
    Result := Result + ['mtmd.dll: mtmd_helper_eval_chunks missing (requires b9050+)'];
  if Assigned(TLlavaApi.Instance.mtmd_init_from_file) and
     not Assigned(TLlavaApi.Instance.mtmd_helper_init_opt_default) then
    Result := Result + ['mtmd.dll: mtmd_helper_init_opt_default missing — ' +
      'mtmd_helper_bitmap_init_from_file has an incompatible signature (requires b11900+)'];
end;

class procedure TLlamaCppApis.LoadAll(ALibDir: string);
const
{$IFDEF MSWINDOWS}
  LIB_LLAMA = 'llama.dll';
  LIB_GGML = 'ggml.dll';
  LIB_MTMD = 'mtmd.dll';
{$ELSEIF DEFINED(OSX64)}
  LIB_LLAMA = 'libllama.dylib';
  LIB_GGML = 'libggml.dylib';
  LIB_MTMD = 'libmtmd.dylib';
{$ELSE}
  LIB_LLAMA = 'libllama.so';
  LIB_GGML = 'libggml.so';
  LIB_MTMD = 'libmtmd.so';
{$ENDIF MSWINDOWS}
var
  LSavedMask: TArithmeticExceptionMask;
begin
  if ALibDir.IsEmpty() then
    ALibDir := TPath.Combine(
      PWideChar(WideString(TPath.GetDirectoryName(ParamStr(0)))),
      'llamacpp');
{$IFDEF MSWINDOWS}
  SetDllDirectory(PWideChar(WideString(ALibDir)));
{$ENDIF MSWINDOWS}
  // Mask all FP exceptions while loading: native DLLs expect C default (all masked),
  // but Delphi's FPU state may have some exceptions unmasked at this call site.
  LSavedMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  try
    // ggml must be loaded first so backends can be discovered before llama loads
    TGgmlApi.Instance.Load(TPath.Combine(ALibDir, LIB_GGML));
    if Assigned(TGgmlApi.Instance.ggml_backend_load_all_from_path) then
      TGgmlApi.Instance.ggml_backend_load_all_from_path(
        PAnsiChar(UTF8Encode(ALibDir)));
    TLlamaApi.Instance.Load(TPath.Combine(ALibDir, LIB_LLAMA));
    // mtmd is optional — only needed for multimodal models
    if TFile.Exists(TPath.Combine(ALibDir, LIB_MTMD)) then
      TLlavaApi.Instance.Load(TPath.Combine(ALibDir, LIB_MTMD));
  finally
    SetExceptionMask(LSavedMask);
  end;
end;

class procedure TLlamaCppApis.UnloadAll;
begin
  TLlamaApi.Instance.Unload();
  TLlavaApi.Instance.Unload();
  TGgmlApi.Instance.Unload();
end;

end.
