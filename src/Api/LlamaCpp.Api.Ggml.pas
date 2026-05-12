unit LlamaCpp.Api.Ggml;

interface

uses
  System.SysUtils,
  LlamaCpp.Api;

type
  TGgmlApiAccess = class(TLlamaCppLibraryLoader)
  public type
    TGgmlBackendLoadAllFromPath = procedure(const ADir: PAnsiChar); cdecl;
  protected
    procedure DoLoadLibrary(const ALibAddr: THandle); override;
  public
    ggml_backend_load_all_from_path: TGgmlBackendLoadAllFromPath;
  end;

  TGgmlApi = class(TGgmlApiAccess)
  private
    class var FInstance: TGgmlApi;
  public
    class constructor Create();
    class destructor Destroy();

    class property Instance: TGgmlApi read FInstance;
  end;

implementation

{ TGgmlApiAccess }

procedure TGgmlApiAccess.DoLoadLibrary(const ALibAddr: THandle);
begin
  inherited;
  @ggml_backend_load_all_from_path := GetProcAddress(ALibAddr, 'ggml_backend_load_all_from_path');
end;

{ TGgmlApi }

class constructor TGgmlApi.Create;
begin
  FInstance := TGgmlApi.Create();
end;

class destructor TGgmlApi.Destroy;
begin
  FInstance.Free();
end;

end.
