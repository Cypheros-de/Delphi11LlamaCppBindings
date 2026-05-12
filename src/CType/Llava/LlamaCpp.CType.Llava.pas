unit LlamaCpp.CType.Llava;

// Delphi translation of mtmd.h and mtmd-helper.h (llama.cpp b9050+).
// All mtmd_context, mtmd_bitmap, mtmd_input_chunk, mtmd_input_chunks and
// mtmd_image_tokens are opaque structs; they are represented as plain Pointer.

interface

uses
  LlamaCpp.CType.Llama,
  LlamaCpp.CType.Ggml.Backend;

type
  // Opaque handles — never dereference these in Pascal
  PMtmdContext    = Pointer;
  PMtmdBitmap     = Pointer;
  PMtmdInputChunk = Pointer;
  PMtmdInputChunks = Pointer;
  PMtmdImageTokens = Pointer;

  PPMtmdBitmap = ^PMtmdBitmap;

  {$MINENUMSIZE 4}
  TMtmdInputChunkType = (
    MTMD_INPUT_CHUNK_TYPE_TEXT  = 0,
    MTMD_INPUT_CHUNK_TYPE_IMAGE = 1,
    MTMD_INPUT_CHUNK_TYPE_AUDIO = 2
  );
  {$MINENUMSIZE 1}

  // mtmd_input_text — passed by pointer to mtmd_tokenize
  // C layout (Win64):
  //   const char * text     (+0, 8 bytes)
  //   bool add_special      (+8, 1 byte)
  //   bool parse_special    (+9, 1 byte)
  //   [6 bytes padding]
  //   total: 16 bytes
  PMtmdInputText = ^TMtmdInputText;
  TMtmdInputText = record
    Text: PAnsiChar;
    AddSpecial: Boolean;
    ParseSpecial: Boolean;
  end;

  // mtmd_context_params — passed by value to mtmd_init_from_file
  // C layout (Win64):
  //   bool use_gpu           (+0,  1 byte)
  //   bool print_timings     (+1,  1 byte)
  //   [2 bytes padding]
  //   int n_threads          (+4,  4 bytes)
  //   const char* image_marker (+8, 8 bytes)  deprecated
  //   const char* media_marker (+16, 8 bytes)
  //   enum flash_attn_type   (+24, 4 bytes)
  //   bool warmup            (+28, 1 byte)
  //   [3 bytes padding]
  //   int image_min_tokens   (+32, 4 bytes)
  //   int image_max_tokens   (+36, 4 bytes)
  //   func ptr cb_eval       (+40, 8 bytes)
  //   void* cb_eval_user_data(+48, 8 bytes)
  //   total: 56 bytes
  PMtmdContextParams = ^TMtmdContextParams;
  TMtmdContextParams = record
    UseGpu: Boolean;
    PrintTimings: Boolean;
    NThreads: Int32;
    ImageMarker: PAnsiChar;   // deprecated, prefer MediaMarker
    MediaMarker: PAnsiChar;
    FlashAttnType: TLlamaFlashAttnType;
    Warmup: Boolean;
    ImageMinTokens: Int32;
    ImageMaxTokens: Int32;
    CbEval: TGgmlBackendSchedEvalCallback;
    CbEvalUserData: Pointer;
  end;

implementation

end.
