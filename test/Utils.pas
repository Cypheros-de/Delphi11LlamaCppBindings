unit Utils;

interface

uses
  System.SysUtils;

type
  TTestUtils = class
  public
    class function GetLibPath(): string;
    class function GetLogsFolder(): string;
    class function IntArrayToStr(const AArr: TArray<Integer>): string; static;
    class function SingleArrayToStr(const AArr: TArray<Single>): string; static;
  end;

implementation

uses
  System.IOUtils;

{ TTestUtils }

class function TTestUtils.GetLibPath: string;
begin
  Result := TPath.Combine(
    TPath.Combine(
      TDirectory.GetParent(
      TDirectory.GetParent(
        TDirectory.GetParent(
          TPath.GetDirectoryName(
            ParamStr(0))))), 'lib'), 'win_x64_cuda_13');
end;

class function TTestUtils.GetLogsFolder: string;
begin
  Result := TPath.Combine(TPath.Combine(TPath.Combine(
    TPath.GetDocumentsPath(), 'LlamaCppDelphi'), 'Tests'), 'Logs');
end;

class function TTestUtils.IntArrayToStr(const AArr: TArray<Integer>): string;
var
  I: Integer;
begin
  Result := '[';
  for I := 0 to High(AArr) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + IntToStr(AArr[I]);
  end;
  Result := Result + ']';
end;

class function TTestUtils.SingleArrayToStr(const AArr: TArray<Single>): string;
var
  I: Integer;
begin
  Result := '[';
  for I := 0 to High(AArr) do
  begin
    if I > 0 then
      Result := Result + ', ';
    Result := Result + FloatToStr(AArr[I]);
  end;
  Result := Result + ']';
end;

end.
