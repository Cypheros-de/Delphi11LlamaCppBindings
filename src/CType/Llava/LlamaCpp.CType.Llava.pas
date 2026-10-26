unit LlamaCpp.CType.Llava;

// Delphi translation of mtmd.h and mtmd-helper.h (llama.cpp b11900).
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
  PMtmdHelperVideo = Pointer;

  PPMtmdBitmap = ^PMtmdBitmap;

  {$MINENUMSIZE 4}
  TMtmdInputChunkType = (
    MTMD_INPUT_CHUNK_TYPE_TEXT  = 0,
    MTMD_INPUT_CHUNK_TYPE_IMAGE = 1,
    MTMD_INPUT_CHUNK_TYPE_AUDIO = 2
  );
  {$MINENUMSIZE 1}

  // mtmd_input_text — passed by pointer to mtmd_tokenize
  // C layout (Win64, b11900):
  //   const char * text     (+0, 8 bytes)
  //   size_t text_len       (+8, 8 bytes)  length of text in bytes
  //   bool add_special      (+16, 1 byte)
  //   bool parse_special    (+17, 1 byte)
  //   [6 bytes padding]
  //   total: 24 bytes
  PMtmdInputText = ^TMtmdInputText;
  TMtmdInputText = record
    Text: PAnsiChar;
    TextLen: NativeUInt;
    AddSpecial: Boolean;
    ParseSpecial: Boolean;
  end;

  // Progress callback of mtmd_context_params; return false to abort.
  TMtmdProgressCallback = function(AProgress: Single; AUserData: Pointer): Boolean; cdecl;

  // mtmd_context_params — passed by value to mtmd_init_from_file
  // C layout (Win64, b11900):
  //   bool use_gpu           (+0,  1 byte)
  //   [7 bytes padding]
  //   ggml_backend_dev_t device (+8, 8 bytes)  NULL = default device
  //   bool print_timings     (+16, 1 byte)
  //   [3 bytes padding]
  //   int n_threads          (+20, 4 bytes)
  //   const char* image_marker (+24, 8 bytes)  deprecated
  //   const char* media_marker (+32, 8 bytes)
  //   enum flash_attn_type   (+40, 4 bytes)
  //   bool warmup            (+44, 1 byte)
  //   [3 bytes padding]
  //   int image_min_tokens   (+48, 4 bytes)
  //   int image_max_tokens   (+52, 4 bytes)
  //   func ptr cb_eval       (+56, 8 bytes)
  //   void* cb_eval_user_data(+64, 8 bytes)
  //   int32 batch_max_tokens (+72, 4 bytes)
  //   [4 bytes padding]
  //   func ptr progress_callback (+80, 8 bytes)
  //   void* progress_callback_user_data (+88, 8 bytes)
  //   total: 96 bytes
  PMtmdContextParams = ^TMtmdContextParams;
  TMtmdContextParams = record
    UseGpu: Boolean;
    Device: Pointer;
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
    BatchMaxTokens: Int32;    // max output tokens in a batch (soft limit, default 1024)
    ProgressCallback: TMtmdProgressCallback;
    ProgressCallbackUserData: Pointer;
  end;

  // mtmd_helper_video_init_params (mtmd-helper.h)
  // C layout (Win64, b11900):
  //   float fps_target              (+0,  4 bytes)  <= 0 = native fps
  //   [4 bytes padding]
  //   const char* ffmpeg_bin_dir    (+8,  8 bytes)  NULL = search PATH
  //   int64 timestamp_interval_ms   (+16, 8 bytes)  <= 0 = no timestamps
  //   total: 24 bytes
  TMtmdHelperVideoInitParams = record
    FpsTarget: Single;
    FfmpegBinDir: PAnsiChar;
    TimestampIntervalMs: Int64;
  end;

  // mtmd_helper_init_opt — passed by value to mtmd_helper_bitmap_init_from_*
  // C layout (Win64, b11900): video_params (+0, 24 bytes), total: 24 bytes
  TMtmdHelperInitOpt = record
    VideoParams: TMtmdHelperVideoInitParams;
  end;

  // mtmd_helper_bitmap_wrapper — returned by mtmd_helper_bitmap_init_from_*
  // C layout (Win64, b11900):
  //   mtmd_bitmap* bitmap           (+0, 8 bytes)  nil on failure
  //   mtmd_helper_video* video_ctx  (+8, 8 bytes)  only set for video input
  //   total: 16 bytes
  TMtmdHelperBitmapWrapper = record
    Bitmap: PMtmdBitmap;
    VideoCtx: PMtmdHelperVideo;
  end;

implementation

end.
