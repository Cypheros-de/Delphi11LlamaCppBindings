unit LlamaCpp.Common.Cache.Ram;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  LlamaCpp.Common.Cache.Base,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.State;

type
  TLlamaRAMCache = class(TBaseLlamaCache)
  private
    const DEFAULT_CAPACITY = {$IFDEF WIN32}1_073_741_824{$ELSE}Int64(2) shl 30{$ENDIF WIN32};
  private
    FCache: TList<TPair<TArray<Integer>, TLlamaState>>;
    function FindIndex(const AKey: TArray<Integer>): Integer;
  public
    constructor Create(ACapacityBytes: NativeInt = DEFAULT_CAPACITY);
    destructor Destroy; override;

    function GetCacheSize: Int64; override;
    function FindLongestPrefixKey(const AKey: TArray<Integer>): TArray<integer>; override;
    function GetItem(const AKey: TArray<Integer>): TLlamaState; override;
    function Contains(const AKey: TArray<Integer>): Boolean; override;
    procedure SetItem(const AKey: TArray<Integer>; const AValue: TLlamaState); override;
  end;

implementation

{ TLlamaRAMCache }

constructor TLlamaRAMCache.Create(ACapacityBytes: NativeInt);
begin
  inherited Create(ACapacityBytes);
  FCache := TList<TPair<TArray<Integer>, TLlamaState>>.Create();
end;

destructor TLlamaRAMCache.Destroy;
var
  I: Integer;
begin
  for I := 0 to FCache.Count - 1 do
    FCache[I].Value.Free();
  FCache.Free;
  inherited;
end;

// FindIndex uses reference equality: FindLongestPrefixKey returns the stored
// key reference, so pointer comparison is correct and avoids a content scan.
function TLlamaRAMCache.FindIndex(const AKey: TArray<Integer>): Integer;
var
  I: Integer;
begin
  for I := 0 to FCache.Count - 1 do
    if Pointer(FCache[I].Key) = Pointer(AKey) then
      Exit(I);
  Result := -1;
end;

function TLlamaRAMCache.GetCacheSize: Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FCache.Count - 1 do
    Result := Result + FCache[I].Value.GetSize();
end;

function TLlamaRAMCache.FindLongestPrefixKey(const AKey: TArray<Integer>): TArray<integer>;
var
  I: Integer;
  LPrefixLen: Integer;
  LMaxPrefixLen: Integer;
begin
  Result := nil;
  LMaxPrefixLen := 0;

  for I := 0 to FCache.Count - 1 do
  begin
    LPrefixLen := LongestTokenPrefix(FCache[I].Key, AKey);
    if LPrefixLen > LMaxPrefixLen then
    begin
      LMaxPrefixLen := LPrefixLen;
      Result := FCache[I].Key;
    end;
  end;
end;

function TLlamaRAMCache.Contains(const AKey: TArray<Integer>): Boolean;
begin
  Result := Assigned(FindLongestPrefixKey(AKey));
end;

function TLlamaRAMCache.GetItem(const AKey: TArray<Integer>): TLlamaState;
var
  LFoundKey: TArray<integer>;
  LIdx: Integer;
begin
  LFoundKey := FindLongestPrefixKey(AKey);

  if not Assigned(LFoundKey) then
    raise Exception.Create('Key not found');

  LIdx := FindIndex(LFoundKey);
  Result := FCache[LIdx].Value;
  FCache.Delete(LIdx);
end;

procedure TLlamaRAMCache.SetItem(const AKey: TArray<Integer>;
  const AValue: TLlamaState);
var
  LIdx: Integer;
  LClone: TLlamaState;
begin
  LClone := AValue.Clone();
  LIdx := FindIndex(AKey);
  if LIdx >= 0 then
  begin
    FCache[LIdx].Value.Free();
    FCache[LIdx] := TPair<TArray<Integer>, TLlamaState>.Create(AKey, LClone);
  end
  else
    FCache.Add(TPair<TArray<Integer>, TLlamaState>.Create(AKey, LClone));

  while GetCacheSize() > CapacityBytes do
  begin
    FCache[0].Value.Free();
    FCache.Delete(0);
  end;
end;

end.
