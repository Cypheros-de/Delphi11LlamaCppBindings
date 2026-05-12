unit LlamaCpp.Api.Llava;

// Delphi bindings for mtmd.dll (llama.cpp b9050+).
// Corresponds to mtmd.h and mtmd-helper.h in the llama.cpp source tree.

interface

uses
  System.SysUtils,
  LlamaCpp.Api,
  LlamaCpp.CType.Llava,
  LlamaCpp.CType.Llama;

type
  TLlavaApiAccess = class(TLlamaCppLibraryLoader)
  public type
    // mtmd_context_params_default()
    TMtmdContextParamsDefault = function(): TMtmdContextParams; cdecl;

    // mtmd_init_from_file(mmproj_fname, text_model, ctx_params) -> ctx or nil
    TMtmdInitFromFile = function(const AFileName: PAnsiChar;
      const ATextModel: PLlamaModel;
      const ACtxParams: TMtmdContextParams): PMtmdContext; cdecl;

    // mtmd_free(ctx)
    TMtmdFree = procedure(ACtx: PMtmdContext); cdecl;

    // mtmd_support_vision(ctx) -> bool
    TMtmdSupportVision = function(ACtx: PMtmdContext): Boolean; cdecl;

    // mtmd_default_marker() -> const char*  (returns "<__media__>")
    TMtmdDefaultMarker = function(): PAnsiChar; cdecl;

    // mtmd_bitmap_init(nx, ny, data) -> bitmap or nil
    TMtmdBitmapInit = function(ANx: UInt32; ANy: UInt32;
      const AData: PByte): PMtmdBitmap; cdecl;

    // mtmd_bitmap_free(bitmap)
    TMtmdBitmapFree = procedure(ABitmap: PMtmdBitmap); cdecl;

    // mtmd_bitmap_get_nx / _ny / _get_n_bytes
    TMtmdBitmapGetNx = function(ABitmap: PMtmdBitmap): UInt32; cdecl;
    TMtmdBitmapGetNy = function(ABitmap: PMtmdBitmap): UInt32; cdecl;
    TMtmdBitmapGetNBytes = function(ABitmap: PMtmdBitmap): NativeUInt; cdecl;

    // mtmd_input_chunks_init() -> chunks
    TMtmdInputChunksInit = function(): PMtmdInputChunks; cdecl;

    // mtmd_input_chunks_size(chunks) -> count
    TMtmdInputChunksSize = function(AChunks: PMtmdInputChunks): NativeUInt; cdecl;

    // mtmd_input_chunks_get(chunks, idx) -> chunk (not freed separately)
    TMtmdInputChunksGet = function(AChunks: PMtmdInputChunks;
      AIdx: NativeUInt): PMtmdInputChunk; cdecl;

    // mtmd_input_chunks_free(chunks)
    TMtmdInputChunksFree = procedure(AChunks: PMtmdInputChunks); cdecl;

    // mtmd_input_chunk_get_type(chunk) -> chunk type
    TMtmdInputChunkGetType = function(AChunk: PMtmdInputChunk)
      : TMtmdInputChunkType; cdecl;

    // mtmd_input_chunk_get_tokens_text(chunk, n_tokens_output) -> token array
    TMtmdInputChunkGetTokensText = function(AChunk: PMtmdInputChunk;
      ANTokensOutput: PNativeUInt): PLLamaToken; cdecl;

    // mtmd_input_chunk_get_n_tokens(chunk) -> count
    TMtmdInputChunkGetNTokens = function(AChunk: PMtmdInputChunk)
      : NativeUInt; cdecl;

    // mtmd_input_chunk_get_n_pos(chunk) -> n_pos (may differ from n_tokens for M-RoPE)
    TMtmdInputChunkGetNPos = function(AChunk: PMtmdInputChunk)
      : TLlamaPos; cdecl;

    // mtmd_tokenize(ctx, output, text, bitmaps, n_bitmaps) -> 0 ok / 1 count mismatch / 2 preprocess error
    TMtmdTokenize = function(ACtx: PMtmdContext;
      AOutput: PMtmdInputChunks;
      const AText: PMtmdInputText;
      const ABitmaps: PPMtmdBitmap;
      ANBitmaps: NativeUInt): Int32; cdecl;

    // mtmd_helper_bitmap_init_from_file(ctx, fname) -> bitmap or nil
    TMtmdHelperBitmapInitFromFile = function(ACtx: PMtmdContext;
      const AFileName: PAnsiChar): PMtmdBitmap; cdecl;

    // mtmd_helper_get_n_tokens(chunks) -> total token count
    TMtmdHelperGetNTokens = function(AChunks: PMtmdInputChunks)
      : NativeUInt; cdecl;

    // mtmd_helper_get_n_pos(chunks) -> total position count (may differ for M-RoPE)
    TMtmdHelperGetNPos = function(AChunks: PMtmdInputChunks)
      : TLlamaPos; cdecl;

    // mtmd_helper_eval_chunks(ctx, lctx, chunks, n_past, seq_id, n_batch, logits_last, new_n_past) -> 0 ok
    TMtmdHelperEvalChunks = function(ACtx: PMtmdContext;
      ALCtx: PLlamaContext;
      AChunks: PMtmdInputChunks;
      ANPast: TLlamaPos;
      ASeqId: TLlamaSeqId;
      ANBatch: Int32;
      ALogitsLast: Boolean;
      ANewNPast: PLlamaPos): Int32; cdecl;

  protected
    procedure DoLoadLibrary(const ALibAddr: THandle); override;
  public
    mtmd_context_params_default: TMtmdContextParamsDefault;
    mtmd_init_from_file: TMtmdInitFromFile;
    mtmd_free: TMtmdFree;
    mtmd_support_vision: TMtmdSupportVision;
    mtmd_default_marker: TMtmdDefaultMarker;
    mtmd_bitmap_init: TMtmdBitmapInit;
    mtmd_bitmap_free: TMtmdBitmapFree;
    mtmd_bitmap_get_nx: TMtmdBitmapGetNx;
    mtmd_bitmap_get_ny: TMtmdBitmapGetNy;
    mtmd_bitmap_get_n_bytes: TMtmdBitmapGetNBytes;
    mtmd_input_chunks_init: TMtmdInputChunksInit;
    mtmd_input_chunks_size: TMtmdInputChunksSize;
    mtmd_input_chunks_get: TMtmdInputChunksGet;
    mtmd_input_chunks_free: TMtmdInputChunksFree;
    mtmd_input_chunk_get_type: TMtmdInputChunkGetType;
    mtmd_input_chunk_get_tokens_text: TMtmdInputChunkGetTokensText;
    mtmd_input_chunk_get_n_tokens: TMtmdInputChunkGetNTokens;
    mtmd_input_chunk_get_n_pos: TMtmdInputChunkGetNPos;
    mtmd_tokenize: TMtmdTokenize;
    mtmd_helper_bitmap_init_from_file: TMtmdHelperBitmapInitFromFile;
    mtmd_helper_get_n_tokens: TMtmdHelperGetNTokens;
    mtmd_helper_get_n_pos: TMtmdHelperGetNPos;
    mtmd_helper_eval_chunks: TMtmdHelperEvalChunks;
  end;

  TLlavaApi = class(TLlavaApiAccess)
  private
    class var FInstance: TLlavaApi;
  public
    class constructor Create();
    class destructor Destroy();

    class property Instance: TLlavaApi read FInstance;
  end;

implementation

{ TLlavaApiAccess }

procedure TLlavaApiAccess.DoLoadLibrary(const ALibAddr: THandle);
begin
  inherited;
  @mtmd_context_params_default := GetProcAddress(ALibAddr,
    'mtmd_context_params_default');
  @mtmd_init_from_file := GetProcAddress(ALibAddr, 'mtmd_init_from_file');
  @mtmd_free := GetProcAddress(ALibAddr, 'mtmd_free');
  @mtmd_support_vision := GetProcAddress(ALibAddr, 'mtmd_support_vision');
  @mtmd_default_marker := GetProcAddress(ALibAddr, 'mtmd_default_marker');
  @mtmd_bitmap_init := GetProcAddress(ALibAddr, 'mtmd_bitmap_init');
  @mtmd_bitmap_free := GetProcAddress(ALibAddr, 'mtmd_bitmap_free');
  @mtmd_bitmap_get_nx := GetProcAddress(ALibAddr, 'mtmd_bitmap_get_nx');
  @mtmd_bitmap_get_ny := GetProcAddress(ALibAddr, 'mtmd_bitmap_get_ny');
  @mtmd_bitmap_get_n_bytes := GetProcAddress(ALibAddr, 'mtmd_bitmap_get_n_bytes');
  @mtmd_input_chunks_init := GetProcAddress(ALibAddr, 'mtmd_input_chunks_init');
  @mtmd_input_chunks_size := GetProcAddress(ALibAddr, 'mtmd_input_chunks_size');
  @mtmd_input_chunks_get := GetProcAddress(ALibAddr, 'mtmd_input_chunks_get');
  @mtmd_input_chunks_free := GetProcAddress(ALibAddr, 'mtmd_input_chunks_free');
  @mtmd_input_chunk_get_type := GetProcAddress(ALibAddr,
    'mtmd_input_chunk_get_type');
  @mtmd_input_chunk_get_tokens_text := GetProcAddress(ALibAddr,
    'mtmd_input_chunk_get_tokens_text');
  @mtmd_input_chunk_get_n_tokens := GetProcAddress(ALibAddr,
    'mtmd_input_chunk_get_n_tokens');
  @mtmd_input_chunk_get_n_pos := GetProcAddress(ALibAddr,
    'mtmd_input_chunk_get_n_pos');
  @mtmd_tokenize := GetProcAddress(ALibAddr, 'mtmd_tokenize');
  @mtmd_helper_bitmap_init_from_file := GetProcAddress(ALibAddr,
    'mtmd_helper_bitmap_init_from_file');
  @mtmd_helper_get_n_tokens := GetProcAddress(ALibAddr,
    'mtmd_helper_get_n_tokens');
  @mtmd_helper_get_n_pos := GetProcAddress(ALibAddr, 'mtmd_helper_get_n_pos');
  @mtmd_helper_eval_chunks := GetProcAddress(ALibAddr,
    'mtmd_helper_eval_chunks');
end;

{ TLlavaApi }

class constructor TLlavaApi.Create;
begin
  FInstance := TLlavaAPI.Create();
end;

class destructor TLlavaApi.Destroy;
begin
  FInstance.Free();
end;

end.
