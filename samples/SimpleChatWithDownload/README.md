# SimpleChatWithDownload

A FireMonkey (FMX) sample application that demonstrates local LLM inference with
automatic model download from HuggingFace. The model runs entirely on your machine —
no internet connection is required after the initial download.

This sample is part of the **llama-cpp-delphi** bindings, updated for llama.cpp b9090.

---

## Features

- **Interactive chat interface** — streaming token output in a scrollable chat view
- **Automatic model download** — downloads GGUF models directly from HuggingFace;
  a progress dialog tracks the download
- **Cross-platform (FMX)** — Windows (CUDA or CPU) and Mac Silicon (MPS or CPU)
- **Context length control** — configurable via the settings panel
- **Seed toggle** — enable a fixed seed for reproducible responses, or leave random
  for natural variety

---

## Platform notes

### Windows (CUDA)

Copy the DLL set from `lib/win_x64_cuda_13/` next to the executable, or point
`TLlama.LibPath` to the folder at runtime. The DLLs include:

- `ggml-base.dll`, `ggml.dll` — core ggml runtime
- `ggml-cpu-*.dll` — CPU backend variants (auto-selected by llama.cpp)
- `ggml-cuda.dll` — CUDA 13 backend (requires CUDA runtime on the system)
- `llama.dll` — main llama.cpp library

If `ggml-cuda.dll` is present and a supported GPU is detected, GPU inference is
used automatically. Set `NGpuLayers := -1` to offload all layers.

### Windows (CPU only)

Include all DLLs except `ggml-cuda.dll`, or set `NGpuLayers := 0`.

### Mac Silicon

Build and deploy via PAServer. The FMX target for macOS links against the
`.dylib` files in the Mac-specific `lib/` folder. GPU inference uses the
Metal/MPS backend automatically when available.

---

## Getting started

### Prerequisites

1. **Delphi 11+** (Alexandria or newer) with FireMonkey (FMX) installed
2. For model download: internet access during the first run
3. For CUDA inference on Windows: NVIDIA driver and CUDA 13 runtime

### Build and run

1. Install the llama-cpp-delphi packages:
   
   - `packages/d11+/LlamaCpp.dproj` → **Compile** → **Install**
   - `packages/d11+/dclLlamaCpp.dproj` → **Compile** → **Install**

2. Open `samples/SimpleChatWithDownload/SimpleChatWithDownload.dproj`

3. Select your target platform (Windows 64-bit or macOS)

4. Build and run

### First run

1. Open the **Settings** panel (hamburger menu or settings button)
2. Select a model from the list
3. Click the download button — the model is saved to your system's Downloads folder
4. Adjust context length and seed options as needed
5. Close the settings panel and start chatting

---

## Recommended models

| Model                           | Download size | Notes                                           |
| ------------------------------- | ------------- | ----------------------------------------------- |
| Qwen3-8B-Q4_K_M                 | ~5 GB         | Multilingual, fast, works well on CPU too       |
| Mistral-7B-Instruct-v0.3-Q4_K_M | ~4 GB         | Reliable English, low VRAM                      |
| LLaMA-3.1-8B-Instruct-Q4_K_M    | ~5 GB         | Good general purpose                            |
| Qwen3-27B-Q4_K_M                | ~16 GB        | High quality, requires 16 GB VRAM with FA+Q8 KV |

Any GGUF-format model hosted on HuggingFace can be used by entering its URL manually.

---

## Sampling defaults

The bindings use the following defaults (matching Ollama and llama.cpp):

| Parameter      | Value                |
| -------------- | -------------------- |
| Temperature    | 0.8                  |
| Top-P          | 0.95                 |
| Top-K          | 40                   |
| Min-P          | 0.05                 |
| Repeat penalty | 1.1 (last 64 tokens) |

These can be overridden per-request via `TLlamaChatCompletionSettings`.

---

## Credits

Original sample: **llama-cpp-delphi** by Embarcadero
https://github.com/Embarcadero/llama-cpp-delphi

llama.cpp: **ggml-org/llama.cpp**
https://github.com/ggml-org/llama.cpp
