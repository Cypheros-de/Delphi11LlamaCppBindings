# llama-cpp-delphi — Update auf llama.cpp b9050

## Projektkontext

Dieses Verzeichnis enthält angepasste Delphi-Bindings für **llama.cpp**, basierend auf dem
Repository [Embarcadero/llama-cpp-delphi](https://github.com/Embarcadero/llama-cpp-delphi).

**Ausgangsstand der Bindings:** llama.cpp Build **b3** (Januar 2025).
**Zielversion:** llama.cpp Build **b9050** (aktuell).

Der Delphi-Code wurde zudem so angepasst, dass er auch unter **Delphi 10+**
(älter als Delphi 12) kompiliert. Diese Anpassungen müssen erhalten bleiben.

## Verzeichnisstruktur

Erwartete Struktur (bitte beim ersten Lauf mit `ls` / `view` verifizieren —
Pfade können abweichen):

- `src/` — Pascal-Header-Übersetzungen und High-Level-Wrapper
  (z.B. `LlamaCpp.Api.*.pas`, `LlamaCpp.Wrapper.*.pas`,
  `LlamaCpp.CommonFunctions.pas`)
- `packages/` — Delphi-Package-Projekte (`.dproj`, `.dpk`)
- `samples/` oder `test/` — Testanwendung(en)
- `bin/` oder `dlls/` — vorkompilierte llama.cpp-DLLs (CPU, CUDA, Vulkan, ...)
- ggf. `vendor/` — Submodule oder mitgelieferte Drittkomponenten

Sollte die Struktur abweichen, **passe dieses Dokument bitte nicht an** —
dokumentiere den tatsächlichen Aufbau am Anfang deines ersten Plans.

## Sprache

Antworte mir auf **Deutsch**. Code-Kommentare, Bezeichner und Commit-Messages
auf **Englisch**, damit das Projekt für Upstream-Beiträge tauglich bleibt.

## Was zu tun ist (Big Picture)

Die llama.cpp-API hat zwischen b3 und b9050 mehrere Breaking Changes durchlaufen.
Folgende Bereiche sind betroffen — Reihenfolge entspricht der empfohlenen
Bearbeitungsreihenfolge:

1. **DLL-/Backend-Loader** — llama.cpp lädt seit ~b4500 Backends als separate
   Shared Libraries (`ggml.dll`, `ggml-base.dll`, `ggml-cpu.dll`, `ggml-cuda.dll`, ...).
   Vor dem ersten Modell-Load muss `ggml_backend_load_all_from_path(dir)`
   aufgerufen werden. Ohne diesen Schritt funktioniert insbesondere CUDA nicht mehr.
2. **Record-Layouts** — `llama_model_params`, `llama_context_params`,
   `llama_sampler_chain_params` haben neue Felder, geänderte Reihenfolge,
   und teils geänderte Typen (z.B. `bool flash_attn` → `enum llama_flash_attn_type`).
   Diese Records müssen **1:1** mit der C-Struktur übereinstimmen, sonst gibt es
   Heisenbugs (Crash erst beim Decode). Im Zweifel komplett neu schreiben anhand
   der aktuellen `llama.h`, nicht patchen.
3. **Funktionsnamen** — `llama_load_model_from_file` → `llama_model_load_from_file`,
   `llama_free_model` → `llama_model_free`, `llama_new_context_with_model` →
   `llama_init_from_model`.
4. **Vocab als eigenes Objekt** (größter struktureller Bruch) — `llama_vocab` ist
   jetzt eine eigene opake Struktur. `llama_model_get_vocab(model)` liefert sie.
   Praktisch alle Tokenizer-/Token-Funktionen nehmen jetzt `vocab` statt `model`:
   `llama_n_vocab` → `llama_vocab_n_tokens`, `llama_token_bos` → `llama_vocab_bos`,
   `llama_tokenize(model, ...)` → `llama_tokenize(vocab, ...)`, usw.
5. **KV-Cache → Memory-API** — `llama_kv_cache_*` und das Übergangs-`llama_kv_self_*`
   sind beide deprecated/entfernt. Neue API: `llama_get_memory(ctx)` liefert
   `llama_memory_t`, dann `llama_memory_clear/seq_rm/seq_cp/seq_keep/seq_add/seq_div/seq_pos_max`.
6. **Sampler** — Chain-API stabil, aber: `llama_sampler_init_grammar` und
   `llama_sampler_init_infill` nehmen jetzt `vocab` statt `model`. Neue Sampler
   wie `xtc`, `top_n_sigma`, erweiterte `dry`-Signatur. `penalties` stark vereinfacht.
7. **Batch** — `llama_batch_get_one` hat zwei Parameter weniger
   (`pos_0` und `seq_id` entfallen, werden automatisch getrackt).
8. **Chat-Template** — `llama_chat_apply_template` ohne `model`-Argument;
   neues `llama_model_chat_template(model, name)` liefert das eingebaute Template.

Eine vollständige Mapping-Tabelle alt → neu existiert separat. Wenn du beim Bearbeiten
unsicher bist, frag nach oder konsultiere die aktuelle `llama.h` aus
`https://github.com/ggml-org/llama.cpp/blob/master/include/llama.h`.

## Vorgehen — wie ich arbeiten möchte

**Inkrementell, in kleinen verifizierbaren Schritten.** Mach **nicht** alle
Änderungen auf einmal. Erwartetes Vorgehen:

1. Beim ersten Lauf: Verschaffe dir Überblick (`ls -R src/`, lies `.dproj`-Dateien,
   identifiziere alle `external 'llama' name '...'`-Stellen). Erstelle einen
   schriftlichen Plan und warte auf mein Go.
2. Pro Schritt: erkläre, **was** du änderst und **warum**. Mach die Änderung,
   stoppe und warte auf Feedback, bevor du den nächsten Schritt machst.
3. Wenn ein Schritt mehrere Dateien betrifft, liste die Dateien vorher auf.
4. Compiliere/teste **nicht** automatisch — ich habe Delphi nicht in der CLI verfügbar.
   Ich teste manuell in der IDE und melde Fehler zurück.

## Inhaltliche Regeln

- **Pascal-Stil bewahren.** Bestehende Code-Konventionen (Naming, Einrückung,
  Header-Kommentare, `{$IFDEF}`-Stil) übernehmen. Nicht "modernisieren", außer
  ich frage explizit danach.
- **Delphi 10+-Kompatibilität bewahren.** Keine Sprachfeatures verwenden, die
  erst ab Delphi 11 oder 12 verfügbar sind (z.B. neue Inline-Vars in Sonderformen,
  bestimmte Generics-Erweiterungen, neue RTL-Funktionen). Im Zweifelsfall fragen.
  Wenn du `{$IF CompilerVersion >= ...}`-Switches siehst, sind die bewusst gesetzt.
- **Keine Funktionalität umbenennen, nur weil sich der C-Name geändert hat.**
  Pascal-seitig kann `TLlama.LoadModel` weiterhin so heißen, auch wenn intern
  `llama_model_load_from_file` aufgerufen wird. Die Pascal-API für den Anwender
  soll möglichst stabil bleiben.
- **Records mit korrektem Alignment.** llama.cpp-Strukturen verwenden in der Regel
  Standard-C-Alignment. In Pascal heißt das in der Regel kein `packed record`,
  sondern ein normaler `record`-Typ. Verifiziere im Zweifel mit `SizeOf`-Test
  gegen die C-Header — Mismatch ist die häufigste Crash-Ursache.
- **Externe Funktionsdeklarationen vollständig.** Calling Convention `cdecl`,
  korrekte Library-Konstante (vermutlich `LLAMA_LIB` oder ähnlich — bitte den
  bestehenden Stil übernehmen), exakter `name`-String wie in der C-Signatur.
- **Deprecated Funktionen nicht beibehalten.** Wenn die alte API in b9050 gar
  nicht mehr existiert, bringt es nichts, sie als Fallback drin zu lassen.
  Sauber durch die neue ersetzen.

## Was du **nicht** ohne Rückfrage tun sollst

- Die Pascal-API der Wrapper-Klassen umbauen oder Methoden umbenennen.
- DLLs hinzufügen, ersetzen oder umbenennen — die liegen vorkompiliert hier
  und ich tausche sie selbst, falls nötig.
- `.dproj`/`.dpk`-Dateien tiefgreifend verändern (Compiler-Optionen, Suchpfade,
  Plattform-Targets). Reine Datei-Hinzufügungen zur Unit-Liste sind okay.
- Code in `vendor/` anpassen — das ist Drittcode (vermutlich llama.cpp-Submodul).
- Die Sample-Anwendung als "Test-Suite" nutzen und massiv umbauen. Sie soll
  als minimaler Smoke-Test dienen; größere Eingriffe vorher absprechen.
- Annahmen über CUDA-Versionen treffen ("baut bestimmt mit 12.4"). Frag mich.

## Hinweise zur llama.cpp-Backend-Architektur (für DLL-Loader-Arbeit)

- Vor dem ersten `llama_model_load_from_file` muss `ggml_backend_load_all()`
  oder besser `ggml_backend_load_all_from_path(dir)` aufgerufen werden.
- Das Verzeichnis muss enthalten: `ggml-base.dll`, `ggml-cpu.dll`, und je nach
  Build z.B. `ggml-cuda.dll`, `ggml-vulkan.dll`. CUDA-Runtime-DLLs
  (`cudart64_12.dll`, `cublas64_12.dll`, `cublasLt64_12.dll`) müssen findbar sein.
- `llama_backend_init()` (ohne Argumente in aktuellen Versionen) wird **nach**
  dem Backend-Loading aufgerufen.
- Beim Cleanup: `llama_backend_free()` am Ende.

## Nützliche Referenzen (zum Nachschlagen, nicht automatisch fetchen)

- `https://github.com/ggml-org/llama.cpp/blob/master/include/llama.h` — aktueller Header
- `https://github.com/ggml-org/llama.cpp/blob/master/include/llama-cpp.h` — C++-Helfer
- llama.cpp-Releases unter `https://github.com/ggml-org/llama.cpp/releases` — Build-Zip-Dateien

## Wenn du unsicher bist

Frag lieber einmal zu viel als einmal zu wenig. Insbesondere bei:

- Record-Feld-Reihenfolge (kann ich anhand der aktuellen `llama.h` verifizieren)
- Calling Convention oder Pointer-/Reference-Semantik
- Speicher-Ownership (wer gibt was wann frei?)
- Allem, was die Pascal-API gegenüber dem Anwender verändern würde

## Status-Tracking

Nach jedem abgeschlossenen Schritt: kurze Zusammenfassung was geändert wurde,
welche Dateien angefasst wurden, und was als Nächstes ansteht. Idealerweise
in einer Form, die ich auch in eine Commit-Message übernehmen könnte.
