# Real Model QA Results

## 2026-06-19 physical iPhone current-build GGUF checkpoint

- Branch: `main`
- Platform: physical iPhone (`Aman's iPhone`, `iPhone 15 Pro`, `iPhone16,1`, UDID `3803F5B6-1666-56D3-A71A-62F131F6CE3B`)
- Whether the physical app was rebuilt before smoke: Yes.
- Build command:
  - `xcodebuild -project ios/Ross.xcodeproj -scheme Ross -configuration Debug -destination 'id=3803F5B6-1666-56D3-A71A-62F131F6CE3B' -derivedDataPath ios/build-device build`
- Install command:
  - `xcrun devicectl device install app --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B ios/build-device/Build/Products/Debug-iphoneos/Ross.app`
- Runtime mode requested: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Artifact kind: `gguf`
- Whether model files were committed: No
- Smoke command:
  - `scripts/ios-device-gguf-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --bundle-id com.ross.ios --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf --tier quickStart --pack-id gemma-2-2b-it-Q4_K_M-device-proof --stage-timeout 45`
- Result: passed after reinstalling the current app build.
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=10240 gpu_offload=n_gpu_layers:32,offload_kqv:true,op_offload:true fallback=none available=true error=nil`
- Benchmark matrix:
  - `english_source_bound_document_qa`
  - `bengali_source_bound_document_qa`
  - `hindi_source_bound_document_qa`
  - `tamil_source_bound_document_qa`
  - `telugu_source_bound_document_qa`
  - `english_open_no_document_query`
- Full-profile pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=full elapsed=20.04s source_raw_chars=337 source_parsed_chars=321 bengali_output_chars=275 hindi_output_chars=157 tamil_output_chars=168 telugu_output_chars=75 general_output_chars=558 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=105 source_token_speed=14.65 source_first_token_ms=790 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=192 bengali_token_speed=13.45 bengali_first_token_ms=2096 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=192 hindi_token_speed=14.41 hindi_first_token_ms=1714 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=54 tamil_token_speed=10.36 tamil_first_token_ms=2307 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=60 telugu_token_speed=9.11 telugu_first_token_ms=3042 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil general_input_tokens=190 general_output_tokens=190 general_token_speed=14.89 general_first_token_ms=1197 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=10240 gpu_offload=n_gpu_layers:32,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=full matrix_profile=full matrix_cases=english_source_bound_document_qa,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=96,telugu:document_qa:te:source_refs_required:max_tokens=96,general:open_query:en:no_source_refs:max_tokens=192 elapsed=20.04s source_case=english_source_bound_document_qa source_task=document_qa source_language=en source_source_refs_policy=source_refs_required source_max_tokens=192 source_input_tokens=207 source_output_tokens=105 source_token_speed=14.65 source_first_token_ms=790 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_raw_chars=337 source_parsed_chars=321 source_refs=1 source_native_model=true general_case=english_open_no_document_query general_task=open_query general_language=en general_source_refs_policy=no_source_refs general_max_tokens=192 general_input_tokens=190 general_output_tokens=190 general_token_speed=14.89 general_first_token_ms=1197 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_output_chars=558 general_native_model=true bengali_case=bengali_source_bound_document_qa bengali_task=document_qa bengali_language=bn bengali_source_refs_policy=source_refs_required bengali_max_tokens=192 bengali_input_tokens=328 bengali_output_tokens=192 bengali_token_speed=13.45 bengali_first_token_ms=2096 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil bengali_output_chars=275 bengali_source_refs=1 bengali_native_model=true hindi_case=hindi_source_bound_document_qa hindi_task=document_qa hindi_language=hi hindi_source_refs_policy=source_refs_required hindi_max_tokens=192 hindi_input_tokens=278 hindi_output_tokens=192 hindi_token_speed=14.41 hindi_first_token_ms=1714 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil hindi_output_chars=157 hindi_source_refs=1 hindi_native_model=true tamil_case=tamil_source_bound_document_qa tamil_task=document_qa tamil_language=ta tamil_source_refs_policy=source_refs_required tamil_max_tokens=96 tamil_input_tokens=382 tamil_output_tokens=54 tamil_token_speed=10.36 tamil_first_token_ms=2307 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil tamil_output_chars=168 tamil_source_refs=1 tamil_native_model=true telugu_case=telugu_source_bound_document_qa telugu_task=document_qa telugu_language=te telugu_source_refs_policy=source_refs_required telugu_max_tokens=96 telugu_input_tokens=433 telugu_output_tokens=60 telugu_token_speed=9.11 telugu_first_token_ms=3042 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil telugu_output_chars=75 telugu_source_refs=1 telugu_native_model=true`
- Token speed summary:
  - source: `105 output`, `14.65 tok/s`, first token `790 ms`
  - general: `190 output`, `14.89 tok/s`, first token `1197 ms`
  - Bengali: `192 output`, `13.45 tok/s`, first token `2096 ms`
  - Hindi: `192 output`, `14.41 tok/s`, first token `1714 ms`
  - Tamil: `54 output`, `10.36 tok/s`, first token `2307 ms`
  - Telugu: `60 output`, `9.11 tok/s`, first token `3042 ms`
- Memory footprint observed:
  - provider ready: about `phys_footprint_mb=1112`
  - maximum observed during the full matrix: about `phys_footprint_mb=1151`
  - no memory pressure, crash, or runtime fallback was observed in the valid current-build GGUF run
- Installed-pack preflight results on the same current app container:
  - list-only showed manifest-backed packs for `gemma-4-12b-it-UD-Q4_K_XL-device-proof`, `gemma-2-2b-it-Q4_K_M-device-proof`, and `gemma-4-e4b-q4`
  - the real E4B+MTP installed-pack smoke failed before inference because `Library/Application Support/RossAlpha/model-packs/quick_start/gemma-4-E4B-it-UD-Q4_K_XL.gguf` was missing from the app container
  - the seeded 2B installed-pack preflight also had stale manifest state before the direct helper reseeded the current app container
- Artifact inventory at checkpoint:
  - GGUF present: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
  - MTP draft present: `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf`
  - MLX missing: `no_directory_with_config_tokenizer_and_safetensors`
  - CoreAI/CoreML adapter missing: `no_mlmodel_or_mlmodelc_adapter_found`
  - no installed CoreAI/system-model manifest was observed in the physical-device pack list
- Guardrail note:
  - an initial old-app direct GGUF run emitted a smoke pass but failed the helper guard with `ROSS_SMOKE_GUARD_FAIL reason=missing_runtime_identity`; that old-app run is intentionally not counted as benchmark evidence
- Current interpretation:
  - current-build physical-device GGUF inference is working on iPhone 15 Pro for the 2B full varied document/query matrix
  - hidden response metrics are emitted in the smoke summary: input tokens, output tokens, token speed, first-token latency, acceleration, draft fields, and native-model markers
  - installed real E4B+MTP is not currently usable on this phone because the primary E4B artifact is missing from the app container
  - MLX is not benchmark-proven because no usable MLX artifact is present
  - CoreAI/CoreML is not benchmark-proven on the physical phone because no installed system-model/CoreAI pack was observed

## 2026-06-19 iOS simulator GGUF full varied benchmark pause checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Runtime mode requested: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Artifact kind: `gguf`
- Whether model files were committed: No
- Whether physical iPhone was used: No
- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf --artifact-kind gguf --tier quickStart --pack-id simulator-2b-checkpoint-varied-doc-query --smoke-profile full --stage-timeout 90 --disable-draft`
- Result: passed.
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true error=nil`
- Benchmark matrix:
  - `english_source_bound_document_qa`
  - `bengali_source_bound_document_qa`
  - `hindi_source_bound_document_qa`
  - `tamil_source_bound_document_qa`
  - `telugu_source_bound_document_qa`
  - `english_open_no_document_query`
- Full-profile pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=full elapsed=127.14s source_raw_chars=467 source_parsed_chars=202 bengali_output_chars=135 hindi_output_chars=270 tamil_output_chars=345 telugu_output_chars=102 general_output_chars=442 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=118 source_token_speed=4.22 source_first_token_ms=32729 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=4.66 bengali_first_token_ms=45703 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=3.91 hindi_first_token_ms=33982 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=4.24 tamil_first_token_ms=50769 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=5.21 telugu_first_token_ms=64427 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=4.59 general_first_token_ms=25288 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured draft_error_detail=no_draft_configured runtime_error_detail=nil context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=full matrix_profile=full matrix_cases=english_source_bound_document_qa,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=96,telugu:document_qa:te:source_refs_required:max_tokens=96,general:open_query:en:no_source_refs:max_tokens=192 elapsed=127.14s source_case=english_source_bound_document_qa source_task=document_qa source_language=en source_source_refs_policy=source_refs_required source_max_tokens=192 source_input_tokens=207 source_output_tokens=118 source_token_speed=4.22 source_first_token_ms=32729 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_raw_chars=467 source_parsed_chars=202 source_refs=1 source_native_model=true general_case=english_open_no_document_query general_task=open_query general_language=en general_source_refs_policy=no_source_refs general_max_tokens=192 general_input_tokens=190 general_output_tokens=192 general_token_speed=4.59 general_first_token_ms=25288 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_output_chars=442 general_native_model=true bengali_case=bengali_source_bound_document_qa bengali_task=document_qa bengali_language=bn bengali_source_refs_policy=source_refs_required bengali_max_tokens=192 bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=4.66 bengali_first_token_ms=45703 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil bengali_output_chars=135 bengali_source_refs=1 bengali_native_model=true hindi_case=hindi_source_bound_document_qa hindi_task=document_qa hindi_language=hi hindi_source_refs_policy=source_refs_required hindi_max_tokens=192 hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=3.91 hindi_first_token_ms=33982 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil hindi_output_chars=270 hindi_source_refs=1 hindi_native_model=true tamil_case=tamil_source_bound_document_qa tamil_task=document_qa tamil_language=ta tamil_source_refs_policy=source_refs_required tamil_max_tokens=96 tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=4.24 tamil_first_token_ms=50769 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil tamil_output_chars=345 tamil_source_refs=1 tamil_native_model=true telugu_case=telugu_source_bound_document_qa telugu_task=document_qa telugu_language=te telugu_source_refs_policy=source_refs_required telugu_max_tokens=96 telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=5.21 telugu_first_token_ms=64427 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil telugu_output_chars=102 telugu_source_refs=1 telugu_native_model=true`
- Memory footprint observed:
  - launch: `resident_mb=244`, `phys_footprint_mb=30`
  - provider ready: `resident_mb=2597`, `phys_footprint_mb=3150`
  - final Telugu completion: `resident_mb=1810`, `phys_footprint_mb=3262`
- Artifact inventory at checkpoint:
  - GGUF present: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
  - MTP draft present: `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf`
  - MLX missing: `no_directory_with_config_tokenizer_and_safetensors`
  - CoreAI/CoreML adapter missing: `no_mlmodel_or_mlmodelc_adapter_found`
  - CoreAI system model remains `unknown` until OS/runtime generation smoke succeeds
- Observed behavior:
  - the simulator app ran a real GGUF provider with explicit `fallback=none`
  - all source-bound document stages retained at least one source reference
  - all six stages reported native-model output and structured token metrics
  - speed on this run was lower than earlier warmed simulator numbers, but the run is still a valid full-profile pass
- Current interpretation:
  - this is a clean pause checkpoint for the 2B GGUF simulator baseline, including varied document/query handling and token speed metrics
  - MLX, CoreAI/CoreML adapter, MTP performance, and physical-device performance are not proven by this checkpoint

## 2026-06-19 iOS simulator rebuilt-app CoreAI/Foundation system checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Whether the simulator app was rebuilt before smoke: Yes, via XcodeBuildMCP using scheme `Ross`
- Runtime mode requested: `apple_foundation_models` through the `coreml` smoke alias
- Artifact path/kind requested: `system-model` with `artifactKind=system_model`
- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime coreml --model system-model --artifact-kind system_model --tier quickStart --pack-id simulator-coreai-system-identity --smoke-profile quick --stage-timeout 5 --launch-timeout 90`
- Result: failed generation; no benchmark pass claimed.
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaFoundationModelsLocalProvider requested_runtime=apple_foundation_models actual_runtime=apple_foundation_models pack_runtime=apple_foundation_models model_format=system_model artifact_path_type=system artifact_path=system-model acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=not_supported draft_error_detail=nil runtime_error_detail=nil context_tokens=8192 gpu_offload=system_managed fallback=none available=true error=nil`
- Failure summary:
  - `ROSS_SMOKE_FAILURE_SUMMARY provider=AlphaFoundationModelsLocalProvider runtime=apple_foundation_models requested_runtime=apple_foundation_models pack_runtime=apple_foundation_models model_format=system_model artifact_path_type=system artifact_path=system-model acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=not_supported draft_error_detail=nil runtime_error_detail=nil context_tokens=8192 gpu_offload=system_managed fallback=none available=true identity_error=nil fail_runtime=apple_foundation_models profile=quick matrix_profile=quick matrix_cases=english_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192 matrix_shape_error=nil stage=nil error=nil elapsed=4.00s source_input_tokens=nil source_output_tokens=nil source_token_speed=nil source_first_token_ms=nil source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil source_raw_chars=0 source_refs=1 source_warning_count=1 source_grounded=false source_refs_kept=true source_native_model=true source_error=coreai_generation_failed general_input_tokens=nil general_output_tokens=nil general_token_speed=nil general_first_token_ms=nil general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil general_output_chars=0 general_warning_count=1 general_native_model=true general_error=coreai_generation_failed`
- Observed behavior:
  - the rebuilt simulator app selected the real Apple Foundation/CoreAI lane, not GGUF: `provider=AlphaFoundationModelsLocalProvider`, `actual_runtime=apple_foundation_models`, `fallback=none`
  - the system-model sentinel was recognized as `artifact_path_type=system`
  - both quick-profile stages failed with `coreai_generation_failed` before token metrics were available
- Current interpretation:
  - CoreAI/Foundation routing and identity guardrails are proven on the rebuilt simulator app
  - CoreAI/Foundation generation is not benchmark-proven because no `ROSS_SMOKE_BENCHMARK_SUMMARY` was emitted
  - physical-device morning validation is still required before claiming CoreAI/CoreML performance

## 2026-06-19 iOS simulator rebuilt-app MTP 2k-context checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Whether the simulator app was rebuilt before smoke: Yes, via XcodeBuildMCP using scheme `Ross`
- Runtime mode requested: `gemma_local_runtime` with MTP draft acceleration required
- Main model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf`
- Draft model artifact used: `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf`
- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --artifact-kind gguf --tier caseAssociate --pack-id simulator-12b-mtp-2k-rebuilt --smoke-profile mtp_quick --stage-timeout 5 --launch-timeout 220 --draft-model /Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf --draft-tokens 2 --require-draft-acceleration`
- Result: failed by bounded source-stage timeout; no benchmark pass claimed.
- Runtime context evidence from rebuilt app:
  - `llama_context: n_ctx         = 2048`
  - `llama_context: n_batch       = 256`
  - `llama_context: n_ubatch      = 128`
- Failure summary:
  - `ROSS_SMOKE_FAILURE_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-4-12b-it-UD-Q4_K_XL.gguf acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp-gemma-4-12b-it.gguf draft_model_path_type=file draft_status=active draft_error_detail=configured_acceleration=draftModelSpeculative runtime_error_detail=nil context_tokens=2048 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil fail_runtime=gemma_local_runtime profile=mtp_quick matrix_profile=mtp_quick matrix_cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token matrix_stages=source:document_qa:en:source_refs_required:max_tokens=24,general:open_query:en:no_source_refs:max_tokens=24 matrix_shape_error=nil stage=nil error=nil elapsed=5.34s source_error=smoke_stage_timeout_source general_error=skipped_after_source_failure source_grounded=false source_refs_kept=false source_native_model=true general_native_model=true source_warning_count=1 general_warning_count=1 source_input_tokens=nil source_output_tokens=nil source_token_speed=nil source_first_token_ms=nil source_measured_tokens=false source_acceleration=nil source_draft_tokens=nil source_draft_model=nil general_input_tokens=nil general_output_tokens=nil general_token_speed=nil general_first_token_ms=nil general_measured_tokens=false general_acceleration=nil general_draft_tokens=nil general_draft_model=nil`
- Observed behavior:
  - this rebuilt simulator app honored the then-current `mtp_quick` cap: the context was `2048`, prompt batch was `256`, physical batch was `128`, and the two-stage matrix kept `max_tokens=24`; the current repo proof lane is now tighter at `context_tokens=1024`, prompt batch `256`, and physical batch `64`
  - runtime identity reached active draft acceleration before generation: `acceleration=draftModelSpeculative`, `draft_tokens=2`, `draft_model=mtp-gemma-4-12b-it.gguf`, and `draft_status=active`
  - the source stage timed out at the intentionally tiny `5s` timeout before token metrics were available; the general stage was skipped after source failure
  - simulator memory footprint at the timeout was `resident_mb=6298` and `phys_footprint_mb=2247`
- Current interpretation:
  - MTP routing, draft artifact loading, and active draft identity were proven on that rebuilt simulator app; the current smoke profile is lower again at `context_tokens=1024`, so new results must not be compared as if they came from the older 2k-context profile
  - this is still not benchmark-pass evidence because generation timed out and no `ROSS_SMOKE_BENCHMARK_SUMMARY` was emitted
  - physical-device morning validation is still required before claiming MTP performance

### 2026-06-20 1024-context simulator MTP degenerate-output checkpoint

- Platform: iOS Simulator (`iPhone 15 Pro`, `A5BDAF71-43EE-4566-A9A5-D1BC7B1FCC5F`)
- Runtime mode requested: `gemma_local_runtime` with MTP draft acceleration required
- Main model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf`
- Draft model artifact used: `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf`
- Smoke commands:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --draft-model /Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf --draft-tokens 2 --require-draft-acceleration --smoke-profile mtp_quick --simulator A5BDAF71-43EE-4566-A9A5-D1BC7B1FCC5F --bundle-id com.ross.ios --tier caseAssociate --stage-timeout 120 --launch-timeout 900`
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --draft-model /Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf --draft-tokens 1 --require-draft-acceleration --smoke-profile mtp_quick --simulator A5BDAF71-43EE-4566-A9A5-D1BC7B1FCC5F --bundle-id com.ross.ios --tier caseAssociate --stage-timeout 120 --launch-timeout 900`
- Result: both runs activated MTP and failed closed as degenerate output; no benchmark pass claimed.
- Runtime context evidence:
  - main context: `n_ctx=1024`, `n_batch=256`, `n_ubatch=64`
  - draft context loaded from `mtp-gemma-4-12b-it.gguf`
- Failure summary highlights:
  - `draft_tokens=2`: `draft_status=active`, `source_acceleration=draftModelSpeculative`, `source_draft_model=mtp-gemma-4-12b-it.gguf`, `source_error=draft_output_degenerate`, `source_output=<|channel>11111111111`, `source_token_speed=1.83`, `source_first_token_ms=91834`
  - `draft_tokens=1`: `draft_status=active`, `source_acceleration=draftModelSpeculative`, `source_draft_model=mtp-gemma-4-12b-it.gguf`, `source_error=draft_output_degenerate`, `source_output=<|channel>11111111111`, `source_token_speed=1.64`, `source_first_token_ms=96106`
- Current interpretation:
  - the 12B MTP pair can initialize and report active draft acceleration under the current 1024-context simulator profile
  - lowering draft tokens from `2` to `1` did not fix the control-token degeneration
  - these runs prove activation plus fail-closed behavior only; they must not be used as MTP performance evidence

### 2026-06-20 E4B simulator MTP zero-acceptance checkpoint

- Platform: iOS Simulator (`iPhone 15 Pro`, `A5BDAF71-43EE-4566-A9A5-D1BC7B1FCC5F`)
- Runtime mode requested: `gemma_local_runtime` with MTP draft acceleration required
- Main model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-E4B-it-UD-Q4_K_XL.gguf`
- Draft model artifact used: `/Users/amanpandey/model-artifacts/mtp-gemma-4-E4B-it.gguf`
- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/model-artifacts/gemma-4-E4B-it-UD-Q4_K_XL.gguf --draft-model /Users/amanpandey/model-artifacts/mtp-gemma-4-E4B-it.gguf --draft-tokens 2 --require-draft-acceleration --smoke-profile mtp_quick --physical-memory-bytes 8589934592 --stage-timeout 90 --launch-timeout 300`
- Result: failed closed; no benchmark pass claimed.
- Runtime context evidence:
  - `context_tokens=1024`
  - main context: `n_ctx=1024`, `n_batch=256`, `n_ubatch=64`
  - draft context: `n_ctx=1024`, `n_batch=32`, `n_ubatch=32`
- Failure summary highlights:
  - `draft_status=active`, `acceleration=draftModelSpeculative`, `draft_tokens=2`, `draft_model=mtp-gemma-4-E4B-it.gguf`
  - `source_input_tokens=198`, `source_output_tokens=12`, `source_token_speed=7.20`, `source_first_token_ms=21956`
  - `general_input_tokens=170`, `general_output_tokens=12`, `general_token_speed=7.08`, `general_first_token_ms=20027`
  - `source_draft_attempted=22`, `source_draft_accepted=0`
  - `general_draft_attempted=22`, `general_draft_accepted=0`
  - `failure_mtp_proof_status=draft_stage_invalid`, `failure_mtp_proof_error=source_draft_accepted=0`
- Current interpretation:
  - the E4B GGUF+MTP pair loads and reports active draft acceleration under the low-context simulator profile
  - the draft path did not provide useful accepted speculative tokens in this run, so it is not an MTP performance proof
  - app-side smoke pass gating now also rejects required-draft stages with zero accepted tokens before a pass marker can be emitted

### 2026-06-19 bounded 90-second rerun

- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --artifact-kind gguf --tier caseAssociate --pack-id simulator-12b-mtp-checkpoint --smoke-profile mtp_quick --stage-timeout 90 --launch-timeout 360 --draft-model /Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf --draft-tokens 2 --require-draft-acceleration`
- Result: failed by bounded source-stage timeout; no benchmark pass claimed.
- Runtime context evidence from the rerun:
  - `llama_context: n_ctx         = 2048`
  - `llama_context: n_batch       = 256`
  - `llama_context: n_ubatch      = 128`
  - draft context: `n_ctx=2048`, `n_batch=32`, `n_ubatch=32`
- Failure summary:
  - `ROSS_SMOKE_FAILURE_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=gguf artifact_path_type=file artifact_path=gemma-4-12b-it-UD-Q4_K_XL.gguf acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp-gemma-4-12b-it.gguf draft_model_path_type=file draft_status=active draft_error_detail=configured_acceleration=draftModelSpeculative runtime_error_detail=nil context_tokens=2048 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil fail_runtime=gemma_local_runtime profile=mtp_quick matrix_profile=mtp_quick matrix_cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token matrix_stages=source:document_qa:en:source_refs_required:max_tokens=24,general:open_query:en:no_source_refs:max_tokens=24 matrix_shape_error=nil stage=nil error=nil elapsed=95.82s source_input_tokens=nil source_output_tokens=nil source_token_speed=nil source_first_token_ms=nil source_measured_tokens=false source_acceleration=nil source_draft_tokens=nil source_draft_model=nil source_raw_chars=0 source_refs=0 source_warning_count=1 source_grounded=false source_refs_kept=false source_native_model=true source_error=smoke_stage_timeout_source general_input_tokens=nil general_output_tokens=nil general_token_speed=nil general_first_token_ms=nil general_measured_tokens=false general_acceleration=nil general_draft_tokens=nil general_draft_model=nil general_output_chars=0 general_warning_count=1 general_native_model=true general_error=skipped_after_source_failure`
- Observed behavior:
  - the main 12B GGUF and 12B MTP draft artifacts both loaded in simulator without falling back to GGUF-standard identity
  - the source stage started generation with `prompt_tokens=198` and `max_new_tokens=24`
  - simulator memory at timeout was `resident_mb=1615` and `phys_footprint_mb=8358`
  - no per-stage token counts or token speed were emitted, so this remains identity/routing evidence only

## 2026-06-19 iOS simulator MTP draft checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Runtime mode requested: `gemma_local_runtime` with MTP draft acceleration required
- Main model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf`
- Draft model artifact used: `/Users/amanpandey/model-artifacts/mtp-gemma-4-12b-it.gguf`
- Draft bytes observed locally: `465109248`
- Draft SHA-256 observed locally: `145db9094bc0f85f1701e255a2ed216dcc9800fc8bc8631ad00905b456bd451b`
- Smoke command:
  - `scripts/ios-simulator-local-model-smoke.sh --runtime gguf --tier caseAssociate --model "$HOME/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf" --draft-model "$HOME/model-artifacts/mtp-gemma-4-12b-it.gguf" --draft-tokens 2 --smoke-profile mtp_quick --stage-timeout 90 --launch-timeout 420 --require-draft-acceleration`
- Result: failed on the open-query stage, no full benchmark claimed.
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-4-12b-it-UD-Q4_K_XL.gguf acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp-gemma-4-12b-it.gguf draft_model_path_type=file draft_status=active context_tokens=4096 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true error=nil`
- Failure summary:
  - `ROSS_SMOKE_FAILURE_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-4-12b-it-UD-Q4_K_XL.gguf acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp-gemma-4-12b-it.gguf draft_model_path_type=file draft_status=active context_tokens=4096 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil fail_runtime=gemma_local_runtime profile=mtp_quick matrix_profile=mtp_quick matrix_cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token matrix_stages=source:document_qa:en:source_refs_required:max_tokens=8,general:open_query:en:no_source_refs:max_tokens=8 matrix_shape_error=nil stage=nil error=nil elapsed=187.89s source_error=nil general_error=smoke_stage_timeout_general source_grounded=false source_refs_kept=true source_native_model=true general_native_model=true source_warning_count=0 general_warning_count=1 source_input_tokens=207 source_output_tokens=16 source_token_speed=1.45 source_first_token_ms=82386 source_measured_tokens=false source_acceleration=draftModelSpeculative source_draft_tokens=2 source_draft_model=mtp-gemma-4-12b-it.gguf general_input_tokens=nil general_output_tokens=nil general_token_speed=nil general_first_token_ms=nil general_measured_tokens=false general_acceleration=nil general_draft_tokens=nil general_draft_model=nil`
- Observed behavior:
  - the prior simulator run aborted in `LlamaContext.deinit` while freeing draft batch memory; after removing the manual draft token-buffer deallocation and freeing contexts before models, the rerun loaded the 12B main GGUF and MTP draft GGUF without the previous abort
  - At that checkpoint, new `mtp_quick` runs used a smoke-only `2048` context cap with `256` prompt batch and `128` physical batch for the main model; the current repo proof lane is tighter at `context_tokens=1024`, prompt batch `256`, and physical batch `64`.
  - A later simulator-only rerun with the 1024-context profile exposed an unsafe intermediate cap: `prompt_tokens=198` exceeded the `128` prompt batch and llama.cpp asserted before any terminal smoke marker. The current 1024-context profile keeps physical batch at `64` but raises prompt batch to `256` so the source-bound MTP smoke prompt can be decoded without violating `n_tokens_all <= n_batch`.
  - the source-bound document QA stage completed with active draft acceleration and reported `source_input_tokens=207`, `source_output_tokens=16`, `source_token_speed=1.45`, and `source_first_token_ms=82386`
  - the open-query stage timed out on Simulator CPU, so the helper emitted `ROSS_SMOKE_FAILURE_SUMMARY` instead of `ROSS_SMOKE_BENCHMARK_SUMMARY`
- Current interpretation:
  - the 12B draft artifact is locally present, the repo catalog checksums match the downloaded byte SHA, and MTP activation is proven by runtime identity
  - Simulator CPU execution is too slow for the full two-stage 12B MTP benchmark at this timeout; only the completed source-stage token speed should be treated as diagnostic evidence
  - a valid future MTP benchmark still requires `ROSS_RUNTIME_IDENTITY acceleration=draftModelSpeculative draft_status=active` plus a guarded `ROSS_SMOKE_BENCHMARK_SUMMARY`

## 2026-06-19 iOS simulator GGUF benchmark checkpoint

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `E36AB177-2287-4112-8225-339048142D11`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Whether model files were committed: No
- Whether the simulator app was rebuilt before smoke: Yes
- Runtime identity marker:
  - `ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime pack_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true error=nil`
- Quick profile result: passed.
- Quick profile pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=quick elapsed=66.81s source_raw_chars=467 source_parsed_chars=202 general_output_chars=442 source_refs=1 source_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=118 source_token_speed=8.93 source_first_token_ms=14483 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=7.86 general_first_token_ms=14796 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Quick benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=quick matrix_profile=quick matrix_cases=english_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,general:open_query:en:no_source_refs:max_tokens=192 elapsed=66.81s source_input_tokens=207 source_output_tokens=118 source_token_speed=8.93 source_first_token_ms=14483 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=7.86 general_first_token_ms=14796 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Full variety profile result: passed after tightening Tamil/Telugu source anchors and capping those stages at 96 output tokens.
- Full variety pass marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime requested_runtime=gemma_local_runtime tier=quick_start profile=full elapsed=55.73s source_raw_chars=467 source_parsed_chars=202 bengali_output_chars=135 hindi_output_chars=270 tamil_output_chars=345 telugu_output_chars=102 general_output_chars=442 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true source_input_tokens=207 source_output_tokens=118 source_token_speed=10.69 source_first_token_ms=13122 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=7.95 bengali_first_token_ms=22669 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=9.37 hindi_first_token_ms=20394 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=8.36 tamil_first_token_ms=27727 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=9.13 telugu_first_token_ms=32645 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=10.30 general_first_token_ms=12831 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil`
- Full variety benchmark summary:
  - `ROSS_SMOKE_BENCHMARK_SUMMARY provider=AlphaLlamaCppProvider runtime=gemma_local_runtime requested_runtime=gemma_local_runtime model_format=local_model_artifact artifact_path_type=file artifact_path=gemma-2-2b-it-Q4_K_M.gguf acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured context_tokens=14336 gpu_offload=n_gpu_layers:99,offload_kqv:true,op_offload:true fallback=none available=true identity_error=nil profile=full matrix_profile=full matrix_cases=english_source_bound_document_qa,bengali_source_bound_document_qa,hindi_source_bound_document_qa,tamil_source_bound_document_qa,telugu_source_bound_document_qa,english_open_no_document_query matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192,bengali:document_qa:bn:source_refs_required:max_tokens=192,hindi:document_qa:hi:source_refs_required:max_tokens=192,tamil:document_qa:ta:source_refs_required:max_tokens=96,telugu:document_qa:te:source_refs_required:max_tokens=96,general:open_query:en:no_source_refs:max_tokens=192 elapsed=55.73s source_input_tokens=207 source_output_tokens=118 source_token_speed=10.69 source_first_token_ms=13122 source_measured_tokens=false source_acceleration=standard source_draft_tokens=nil source_draft_model=nil general_input_tokens=190 general_output_tokens=192 general_token_speed=10.30 general_first_token_ms=12831 general_measured_tokens=false general_acceleration=standard general_draft_tokens=nil general_draft_model=nil bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=7.95 bengali_first_token_ms=22669 bengali_measured_tokens=false bengali_acceleration=standard bengali_draft_tokens=nil bengali_draft_model=nil hindi_input_tokens=278 hindi_output_tokens=134 hindi_token_speed=9.37 hindi_first_token_ms=20394 hindi_measured_tokens=false hindi_acceleration=standard hindi_draft_tokens=nil hindi_draft_model=nil tamil_input_tokens=382 tamil_output_tokens=96 tamil_token_speed=8.36 tamil_first_token_ms=27727 tamil_measured_tokens=false tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil telugu_input_tokens=433 telugu_output_tokens=96 telugu_token_speed=9.13 telugu_first_token_ms=32645 telugu_measured_tokens=false telugu_acceleration=standard telugu_draft_tokens=nil telugu_draft_model=nil`
- Observed behavior:
  - the fresh simulator build launches successfully
  - GGUF runtime identity is explicit and confirms no fallback
  - quick document-grounded handling and a general query both pass with native-model outputs
  - the fuller run exercises source, general, Bengali, Hindi, Tamil, and Telugu stages
  - every full-profile stage completed without provider errors and reported native-model output
  - Tamil and Telugu now retain source refs, satisfy grounding checks, and report bounded 96-token speed metrics
- Current interpretation:
  - simulator GGUF execution, hidden benchmark fields, token counts, token speed, first-token latency, and source-reference retention are working for this local 2B GGUF baseline
  - the full simulator GGUF variety bundle is green for source, Bengali, Hindi, Tamil, Telugu, and general query handling
  - this run does not prove MLX, CoreAI/CoreML, MTP, or physical-device performance

## 2026-06-18 physical iPhone intended 12B GGUF attempt

- Branch: `main`
- Platform: physical iPhone (`Aman's iPhone`, `iPhone16,1`, iOS `27.0`)
- Runtime mode: `gemma_local_runtime`
- Intended visible tier under test: `Case Associate`
- Model artifact used: `/Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf`
- Model bytes observed locally: `7366421920`
- Model SHA-256 observed locally: `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
- Repo metadata SHA-256 recorded before follow-up reconciliation: `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637`
- Live HEAD nuance observed on June 18, 2026:
  - the Hugging Face resolver still advertised `content-length: 7366421920`
  - `x-linked-etag` matched the local file hash `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
  - the final CDN `etag` still showed `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637`
- Follow-up reconciliation completed on June 18, 2026:
  - Ross production metadata was updated to pin the downloaded GGUF bytes hash `ee33ab5be8e07aca1c269fc645eaed5f3298e089d52db29415839d8f29957020`
  - the prior `2f76adb77c0cbce35bf0f14c8a9d57f5a8c08528acf2edf3684b1eb38b075637` value is now treated as the CDN/Xet reconstruction hash observed in `etag`, not as the downloaded file checksum contract
- Smoke helper: `/Users/amanpandey/projects/ross-gemma4/scripts/ios-device-gguf-smoke.sh`
- Smoke command:
  - `scripts/ios-device-gguf-smoke.sh --device 3803F5B6-1666-56D3-A71A-62F131F6CE3B --model /Users/amanpandey/model-artifacts/gemma-4-12b-it-UD-Q4_K_XL.gguf --tier caseAssociate --stage-timeout 120`
- Whether model files were committed: No
- Whether the intended 12B GGUF reached the physical device: Yes
- Whether generation passed on the physical device: No
- Observed device/runtime details:
  - the app resolved and opened the intended `Gemma-4-12B-It` GGUF from the physical app container on device
  - the smoke run reported `System physical memory: 7 GB`
  - Metal reported `recommendedMaxWorkingSetSize  =  5726.63 MB`
  - the active GPU path was `Apple A17 Pro GPU`
- Failure signature:
  - `llama_model_load: error loading model: mmap failed: Cannot allocate memory`
  - `ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=gemma_local_runtime tier=quick_start elapsed=98.53s source_error=inference_failed bengali_error=inference_failed hindi_error=inference_failed tamil_error=inference_failed telugu_error=inference_failed general_error=inference_failed ... source_native_model=true ... general_native_model=true`
- Observed physical-device behavior:
  - the helper successfully seeded the full 12B artifact plus manifest into `Library/Application Support/RossAlpha/model-packs/caseAssociate/`
  - Ross resolved the seeded debug pack, constructed the GGUF provider path, and repeatedly attempted real model loading for each smoke stage
  - every stage failed before generation because the model could not be memory-mapped on this 7 GB-class iPhone
  - the fail marker still reported `tier=quick_start` even though the seeded artifact lived under the `caseAssociate` slot, so the smoke tier label should not be treated as the authored pack slot in this run
- What this proves:
  - the intended Case Associate 12B artifact is reachable from the current cabled-device helper and the app can begin real on-device load on Aman's iPhone
  - the current `gemma-4-12b-it-UD-Q4_K_XL.gguf` footprint does not fit this physical iPhone's available memory budget
- What is still not proven:
  - successful physical-device generation for the intended 12B artifact on a 12 GB+ iPhone class target
  - physical iPhone download/resume/verify/activate of the production 12B artifact on a device that can run it
  - the longer-bundle comparison loop across GGUF, MLX, and CoreAI on a device that can actually run the intended 12B pack

## 2026-06-18 physical iPhone GGUF smoke via cabled-device helper

- Branch: `main`
- Platform: physical iPhone (`Aman's iPhone`, `iPhone16,1`, iOS `27.0`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Smoke helper: `/Users/amanpandey/projects/ross-gemma4/scripts/ios-device-gguf-smoke.sh`
- Smoke command:
  - `scripts/ios-device-gguf-smoke.sh --device 00008130-000C74820130001C --model /Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf --tier quickStart --stage-timeout 45`
- Whether model files were committed: No
- Whether real GGUF inference ran on the physical device: Yes
- Latest proof marker:
  - `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=88.34s source_raw_chars=337 source_parsed_chars=321 bengali_output_chars=275 hindi_output_chars=157 tamil_output_chars=400 telugu_output_chars=185 general_output_chars=558 source_refs=1 bengali_source_refs=1 hindi_source_refs=1 tamil_source_refs=1 telugu_source_refs=1 source_native_model=true bengali_native_model=true hindi_native_model=true tamil_native_model=true telugu_native_model=true general_native_model=true`
- Observed physical-device behavior:
  - the helper seeded the GGUF artifact into the app container and resolved the absolute on-device model path automatically
  - the app created a real llama.cpp context on the A17 Pro GPU and completed every smoke stage on device
  - English source grounding, Bengali Bangla-script output, Hindi Devanagari output, Tamil output, Telugu output, and the general cautious answer all passed in the same run
- What is still not proven:
  - the intended `Case Associate` 12B GGUF artifact on this physical iPhone
  - physical iPhone download/resume/verify/activate of the current multi-GB production GGUF artifacts
  - the longer-bundle comparison loop across GGUF, MLX, and CoreAI on this device

## 2026-06-02 iOS simulator GGUF smoke

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Whether model files were committed: No
- Whether real GGUF inference ran: Yes, in simulator, through `--local-model-smoke`
- Proof marker: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start`
- What passed:
  - English source-grounded answer about Article 417 citation verification
  - Bengali Bangla-script source-grounded answer
  - Hindi Devanagari source-grounded answer
  - general cautious answer without tagged sources
- Native model-vs-fallback marker: not recorded in this run. Later smoke logs include `bengali_native_model` and `hindi_native_model`; require those to be `true` before claiming native multilingual model behavior rather than product-safe source fallback behavior.
- What is still not proven:
  - physical iPhone download/resume/verify/activate of a multi-GB GGUF
  - physical-device imported PDF/image/text Ask flow and performance
  - separate embedding-model retrieval

## 2026-06-02 stricter iOS simulator GGUF smoke rerun

- Branch: `main`
- Platform: iOS Simulator (`iPhone 17`, `DCE8EAA3-A325-4FA9-A37B-C2653ECEDA6D`)
- Runtime mode: `gemma_local_runtime`
- Model artifact used: `/Users/amanpandey/projects/ross-gemma4/artifacts/gemma-2-2b-it-Q4_K_M.gguf`
- Model SHA-256 observed locally: `e0aee85060f168f0f2d8473d7ea41ce2f3230c1bc1374847505ea599288a7787`
- Smoke command shape: `xcrun simctl launch --terminate-running-process --console ... com.ross.ios --local-model-smoke` with `SIMCTL_CHILD_ROSS_*` environment variables and `ROSS_LOCAL_MODEL_SMOKE_STAGE_TIMEOUT_SECONDS=45`
- Result: passed.
- Latest proof marker after Bengali prompt tightening: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=89.36s source_raw_chars=339 source_parsed_chars=167 bengali_output_chars=151 hindi_output_chars=143 general_output_chars=283 source_native_model=true bengali_native_model=true hindi_native_model=true general_native_model=true`
- Earlier stricter marker before prompt tightening: `ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime tier=quick_start elapsed=91.00s ... source_native_model=true bengali_native_model=false hindi_native_model=true general_native_model=true`
- Observed behavior:
  - the smoke runner used the explicit environment-provided debug pack directly instead of loading persisted app state first
  - the simulator process loaded the GGUF metadata, constructed the llama.cpp context, and completed all four smoke stages
  - the app was manually terminated after the pass marker with `xcrun simctl terminate`
- Harness improvement made during this pass:
  - `--local-model-smoke` now emits flushed stage markers to stderr around debug-pack selection, provider resolution, and each provider call
  - each provider stage is guarded by a configurable timeout and returns a fail output if generation times out
  - direct environment-supplied GGUF smoke skips heavyweight persisted-state runtime-health loading before provider execution
  - Bengali and Hindi matter-answer prompts now include concrete native-script source-word anchors
- Current interpretation:
  - real GGUF simulator inference is proven for English source grounding, Bengali Bangla-script output, Hindi Devanagari output, and general cautious output
  - the latest run proves native Bengali and Hindi model output on simulator; no language-preserving fallback was used in that run
  - physical iPhone proof remains required before claiming downloaded-model performance or reliability over user-imported files

## 2026-04-24 Gemma 4 metadata update

- Branch: `gemma-4-gguf-model-strategy`
- Quick Start metadata: Gemma 4 E2B Q4
- Case Associate metadata: Gemma 4 E4B Q4
- Senior Drafting Support metadata: Gemma 4 26B-A4B Q4
- Retrieval metadata: separate Matter Search embedding model
- Backend default: tiny deterministic artifacts
- Backend production metadata mode: Gemma 4 metadata only, no real download session
- Whether model files were committed: No
- Whether real Gemma 4 Q4 inference ran: Not in this historical April pass. A later June 2 simulator GGUF smoke did run.
- Whether separate embedding-model retrieval ran: Not yet
- Exact next proof step: implement and test the Matter Search embedding install/retrieval path, then run hardware Q4 inference proof.

## 2026-04-23 iPhone and Android model-path update

- Branch: `alpha-lawyer-usable-app`
- iPhone model source: iOS on-device private assistant when available
- iPhone model download status then: no separate OGemma 4 or Hugging Face model was downloaded in that pass
- Android model source: backend-served compatible MediaPipe `.task` artifact when explicitly configured outside the repo
- Whether model files were committed: No
- Whether iPhone setup was manually tapped on Aman's device in this update: Not yet
- Whether Android real `mediapipe_llm` inference ran on a physical Android device: Not yet
- What was validated instead:
  - iOS Swift tests passed for `system_model` runtime health without a downloaded path
  - Android unit tests passed for preserving `.task` filenames during backend artifact install
  - Android Ask Ross now routes matter Q&A through the installed local runtime when available, with deterministic local fallback
  - Android dock command tests still pass for task creation, date saving, and export generation
- Remaining blocker:
  - a real Android `.task` artifact and physical Android device are still required before claiming Android real-model execution
  - Aman's iPhone still needs a manual setup check before claiming the iOS on-device assistant is available on that exact phone

## 2026-04-19 Android physical-device proof attempt

- Date: 2026-04-19
- Branch: `alpha-android-real-proof`
- Commit observed during validation: `e10c7f4`
- Platform: Android physical-device proof attempt with repo-wide validation
- Device model: Not available. No physical Android device was connected.
- Android version: Not available. No physical Android device was connected.
- Runtime mode: Not run. Requested proof target remains `mediapipe_llm`.
- Model artifact kind: developer-provided local `.task` artifact
- Model artifact source: Not provided in this session
- Model checksum status: Not configured in this session
- Whether model file was committed: No
- Whether inference actually ran: No
- Whether deterministic fallback was used: Not applicable for a physical-device proof run because no Android extraction was executed on-device
- Runtime health result: Not observed on a physical Android device
- Fixture used: none for a real-device Android run
- Extraction mode: `Case Associate`
- Duration: not recorded because no real-device inference ran
- Fields found: not recorded because no real-device inference ran
- Fields verified: not recorded because no real-device inference ran
- Fields needing review: not recorded because no real-device inference ran
- Unsupported accepted count: not recorded because no real-device inference ran
- Schema valid: not recorded because no real-device inference ran
- Source refs present: not recorded because no real-device inference ran
- Export generated: not recorded because no real-device inference ran
- Privacy ledger checked: not checked on a physical Android device in this session
- Logs checked for raw prompt/source: not checked on a physical Android device in this session
- Network checked for model calls: not checked on a physical Android device in this session
- Exact blocker:
  - no physical Android device connected
  - no developer-provided compatible `.task` model artifact configured or supplied
- What was validated instead:
  - `scripts/dev/android-real-inference-smoke.sh` cleanly skipped with `Skipping: no physical Android device is connected.`
  - `adb devices -l` returned no attached devices
  - no `ROSS_ENABLE_REAL_LOCAL_INFERENCE`, `ROSS_LOCAL_RUNTIME`, or `ROSS_LOCAL_MODEL_*` environment variables were configured in this session
  - Android baseline validation passed: `./gradlew :app:testDebugUnitTest :app:assembleDebug`
  - Rust, backend, privacy-guard, and iOS validation suites passed after a small iOS runtime-health safety fix
  - backend live smoke passed for:
    - `GET /model-catalog`
    - `POST /model-download/session`
    - `GET /dev-artifacts/:artifactId` with `Range`
    - `POST /public-law/search`
  - optional backend external-model metadata and serving smoke passed with a safe temporary file outside the repo, and the backend did not expose the local file path
- Failures/blockers:
  - Android real local inference was not run, so there is still no proof yet that `mediapipe_llm` executed on a physical device for Ross
- Next exact manual step:
  - connect one physical Android device
  - supply one compatible developer-provided `.task` model artifact outside the repo
  - set:
    - `ROSS_ENABLE_REAL_LOCAL_INFERENCE=1`
    - `ROSS_LOCAL_RUNTIME=mediapipe_llm`
    - `ROSS_LOCAL_MODEL_PATH=<app-readable device path>`
    - `ROSS_LOCAL_MODEL_PUSH_SOURCE=<absolute source path outside the repo>` when using the smoke helper
    - optional `ROSS_LOCAL_MODEL_CHECKSUM=<sha256>`
  - rerun `/Users/amanpandey/projects/ross/scripts/dev/android-real-inference-smoke.sh`
  - install and launch the Android debug APK
  - confirm `Settings > Private AI > Technical details` shows real runtime available with fallback inactive
  - run `Run local inference smoke`
  - complete one synthetic `Case Associate` extraction, verify source-backed fields, confirm unsupported accepted count stays `0`, generate one export, inspect the Privacy Ledger, inspect `adb logcat`, and record the observed result here without pasting prompt text, source text, or model output
