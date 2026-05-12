unit LlamaCpp.Evaluator;

interface

uses
  LlamaCpp.Types,
  LlamaCpp.CType.Llama,
  LlamaCpp.Wrapper.LlamaContext,
  LlamaCpp.Wrapper.LlamaBatch,
  LlamaCpp.Common.Types;

type
  TLlamaEvaluator = class(TInterfacedObject, ILlamaEvaluator)
  private
    FContext: TLlamaContext;
    FBatch: TLlamaBatch;
    FContextParams: TLlamaContextParams;
    [weak]
    FLlama: ILlama;
  public
    constructor Create(const ALlama: ILlama);

    procedure Eval(const ATokens: TArray<integer>);
  end;

implementation

uses
  System.Math;

{ TLlamaEvaluator }

constructor TLlamaEvaluator.Create(const ALlama: ILlama);
begin
  FContext := ALlama.Context;
  FBatch := ALlama.Batch;
  FContextParams := ALlama.ContextParams;
  FLlama := ALlama;
end;

procedure TLlamaEvaluator.Eval(const ATokens: TArray<integer>);
var
  I: integer;
  J: integer;
  K: integer;
  LIndex: integer;
  LNPast: integer;
  LNTokens: integer;
  //LRows: integer;
  //LCols: integer;
  LBatch: TArray<integer>;
  LLogits: PLogitArray;
begin
  FContext.KvCacheSeqRm(-1, FLlama.NumberOfTokens, -1);

  // Guard: (-1 div n) = 0 in Delphi (truncation toward zero), so the loop
  // below would execute once with an empty batch and crash llama_decode.
  if Length(ATokens) = 0 then
    Exit;

  for I := 0 to High(ATokens) div FLlama.NumberOfBatches do
  begin
    LBatch := Copy(ATokens, I * FLlama.NumberOfBatches,
      Min(Length(ATokens) - I * FLlama.NumberOfBatches, FLlama.NumberOfBatches));
    LNPast := FLlama.NumberOfTokens;
    LNTokens := Length(LBatch);

    // Speculative decoding requires logits at every batch position for verification.
    // When a draft model is active, override logits_all regardless of settings.
    FBatch.SetBatch(LBatch, LNPast,
      FLlama.Settings.LogitsAll or Assigned(FLlama.DraftModel));
    FContext.Decode(FBatch);

    Move(LBatch[0], FLlama.InputIds[LNPast], LNTokens * SizeOf(integer));

    if FLlama.Settings.LogitsAll then
    begin
      //LRows := LNTokens;
      //LCols := NVocab;
      LLogits := FContext.GetLogits();

      LIndex := 0;
      { TODO : SLOW! Make it better. }
      for J := LNPast to LNPast + LNTokens - 1 do
        for K := Low(FLlama.Scores[J]) to High(FLlama.Scores[J]) do
        begin
          {$R-}
          FLlama.Scores[J][K] := LLogits^[LIndex];
          {$R+}
          Inc(LIndex);
        end;
    end
    else
    begin
      // Handle case where logits_all is False
      // This section is commented out in Python but should be considered here as needed
      // For this case, you would handle updating just the last row or other logic.
    end;

    FLlama.NumberOfTokens := FLlama.NumberOfTokens + LNTokens;
  end;
end;

end.
