unit LlamaCpp.Common.Chat.Formatter.Jinja2;

interface

uses
  System.SysUtils,
  System.Variants,
  System.Generics.Collections,
  LlamaCpp.Common.Types,
  LlamaCpp.Common.Settings,
  LlamaCpp.Common.Chat.Types,
  LlamaCpp.Common.Chat.Format;

type
  TJinja2ChatFormatter = class(TInterfacedObject, ILlamaChatFormater)
  private
    // llama_chat_apply_template expects and returns UTF-8; AnsiString would
    // convert through the ANSI code page and lose e.g. Cyrillic or CJK text.
    FTemplate: UTF8String;
    FStopStrings: TArray<string>;
    FAddGenerationPrompt: boolean;
    function Format(const ASettings: TLlamaChatCompletionSettings)
    : TChatFormatterResponse;
  public
    constructor Create(
      const ATemplate: string;
      const AStopStrings: TArray<string>;
      const ABOSToken: string;
      const AAddGenerationPrompt: boolean = true;
      const AStopTokenIds: TArray<integer> = nil);

    function ToChatHandler(): ILlamaChatCompletionHandler;
  end;

implementation

uses
  LlamaCpp.Api.Llama,
  LlamaCpp.CType.Llama,
  LlamaCpp.Common.Chat.Formatter.Adapter;

{ TJinja2ChatFormatter }

constructor TJinja2ChatFormatter.Create(const ATemplate: string;
  const AStopStrings: TArray<string>; const ABOSToken: string;
  const AAddGenerationPrompt: boolean; const AStopTokenIds: TArray<integer>);
const
  // Unique sentinel placed as the assistant content in the probe conversation.
  // Everything that follows it in the rendered template is the EOT marker.
  CProbeMarker: AnsiString = 'JINJA2_EOT_PROBE_SENTINEL_X7Z9Q';
var
  LTmpl: PAnsiChar;
  LProbeMsgs: array [0..1] of TLlamaChatMessage;
  LProbeUserRole: AnsiString;
  LProbeUserContent: AnsiString;
  LProbeAssistRole: AnsiString;
  LBufSize: Integer;
  LBuf: TArray<AnsiChar>;
  LFullText: string;
  LProbeStr: string;
  LProbePos: Integer;
  LEotMarker: string;
  I: Integer;
  LFound: Boolean;
begin
  FTemplate            := UTF8String(ATemplate);
  FStopStrings         := AStopStrings;
  FAddGenerationPrompt := AAddGenerationPrompt;

  // Probe the template to find the EOT marker that follows an assistant turn.
  // This covers models where llama_vocab_eot() returns -1 but the Jinja2
  // template uses a specific token (e.g. <|im_end|>) to close each turn.
  LProbeUserRole    := 'user';
  LProbeUserContent := 'test';
  LProbeAssistRole  := 'assistant';

  LProbeMsgs[0].Role    := PAnsiChar(LProbeUserRole);
  LProbeMsgs[0].Content := PAnsiChar(LProbeUserContent);
  LProbeMsgs[1].Role    := PAnsiChar(LProbeAssistRole);
  LProbeMsgs[1].Content := PAnsiChar(CProbeMarker);

  if FTemplate <> '' then
    LTmpl := PAnsiChar(FTemplate)
  else
    LTmpl := nil;

  LBufSize := TLlamaApi.Instance.llama_chat_apply_template(
    LTmpl, @LProbeMsgs[0], 2, False, nil, 0);

  if LBufSize > 0 then
  begin
    SetLength(LBuf, LBufSize + 1);
    LBuf[LBufSize] := #0;
    TLlamaApi.Instance.llama_chat_apply_template(
      LTmpl, @LProbeMsgs[0], 2, False, @LBuf[0], LBufSize);

    LFullText := UTF8ToString(PAnsiChar(@LBuf[0]));
    LProbeStr := string(CProbeMarker);
    LProbePos := Pos(LProbeStr, LFullText);

    if LProbePos > 0 then
    begin
      // Extract everything after the sentinel — that is the EOT marker
      // (e.g. "<|im_end|>").  Trim trailing whitespace/newlines because
      // some templates add a newline between turns that is not part of
      // the EOT token itself.
      LEotMarker := Copy(LFullText, LProbePos + Length(LProbeStr), MaxInt);
      LEotMarker := LEotMarker.TrimRight;

      if not LEotMarker.IsEmpty then
      begin
        LFound := False;
        for I := 0 to High(FStopStrings) do
          if FStopStrings[I] = LEotMarker then
          begin
            LFound := True;
            Break;
          end;
        if not LFound then
          FStopStrings := FStopStrings + [LEotMarker];
      end;
    end;
  end;
end;

function TJinja2ChatFormatter.Format(
  const ASettings: TLlamaChatCompletionSettings): TChatFormatterResponse;
var
  LMessages: TArray<TChatCompletionRequestMessage>;
  LRoles: TArray<UTF8String>;
  LContents: TArray<UTF8String>;
  LChatMsgs: TArray<TLlamaChatMessage>;
  LMsg: TChatCompletionRequestMessage;
  LCount: NativeUInt;
  LTmpl: PAnsiChar;
  LBufSize: Integer;
  LBuf: TArray<AnsiChar>;
  LPrompt: string;
  I: Integer;
begin
  LMessages := ASettings.Messages;
  LCount    := Length(LMessages);

  SetLength(LRoles,    LCount);
  SetLength(LContents, LCount);
  SetLength(LChatMsgs, LCount);

  for I := 0 to Integer(LCount) - 1 do
  begin
    LMsg         := LMessages[I];
    LRoles[I]    := UTF8String(LMsg.Role);
    LContents[I] := UTF8String(VarToStr(LMsg.Content));
    LChatMsgs[I].Role    := PAnsiChar(LRoles[I]);
    LChatMsgs[I].Content := PAnsiChar(LContents[I]);
  end;

  if FTemplate <> '' then
    LTmpl := PAnsiChar(FTemplate)
  else
    LTmpl := nil;

  // First pass: measure required buffer size
  LBufSize := TLlamaApi.Instance.llama_chat_apply_template(
    LTmpl, @LChatMsgs[0], LCount, FAddGenerationPrompt, nil, 0);

  if LBufSize <= 0 then
    raise ENotImplemented.Create(
      'llama_chat_apply_template failed (returned ' +
      IntToStr(LBufSize) + ').');

  SetLength(LBuf, LBufSize + 1);
  LBuf[LBufSize] := #0;

  // Second pass: fill buffer
  TLlamaApi.Instance.llama_chat_apply_template(
    LTmpl, @LChatMsgs[0], LCount, FAddGenerationPrompt,
    @LBuf[0], LBufSize);

  LPrompt := UTF8ToString(PAnsiChar(@LBuf[0]));

  Result := TChatFormatterResponse.Create(LPrompt);
  Result.AddedSpecial := True;
  Result.Stop := FStopStrings;
end;

function TJinja2ChatFormatter.ToChatHandler: ILlamaChatCompletionHandler;
begin
  Result := TChatFormaterAdapter.ToChatCompletionHandler(Self);
end;

end.
