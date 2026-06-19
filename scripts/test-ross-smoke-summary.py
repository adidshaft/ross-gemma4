#!/usr/bin/env python3
import unittest

from ross_smoke_summary import (
    MissingBenchmarkMatrixError,
    benchmark_summary_line,
    failure_summary_line,
    parse_fields,
    runtime_identity_artifact_error,
    runtime_identity_availability_error,
    runtime_identity_draft_artifact_error,
    benchmark_matrix_shape_error,
    benchmark_stage_metric_error,
    benchmark_stage_draft_error,
)


class RossSmokeSummaryTests(unittest.TestCase):
    def test_benchmark_summary_includes_runtime_matrix_and_stage_metrics(self):
        identity = parse_fields(
            "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider "
            "requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime "
            "model_format=gguf artifact_path_type=file artifact_path=gemma-2b.gguf "
            "acceleration=standard draft_tokens=nil draft_model=nil draft_model_path_type=nil "
            "draft_status=no_draft_configured context_tokens=4096 gpu_offload=n_gpu_layers:0 "
            "fallback=none available=true error=nil"
        )
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=full "
            "cases=english_source_bound_document_qa,bengali_source_bound_document_qa,english_open_no_document_query "
            "stages=source:document_qa:en:source_refs_required:max_tokens=192,"
            "bengali:document_qa:bn:source_refs_required:max_tokens=192,"
            "general:open_query:en:no_source_refs:max_tokens=192"
        )
        pass_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime profile=full elapsed=12.34s "
            "source_input_tokens=207 source_output_tokens=118 source_token_speed=9.00 "
            "source_first_token_ms=17392 source_measured_tokens=false "
            "bengali_input_tokens=328 bengali_output_tokens=121 bengali_token_speed=8.84 "
            "bengali_first_token_ms=24339 bengali_measured_tokens=false "
            "general_input_tokens=190 general_output_tokens=192 general_token_speed=8.57 "
            "general_first_token_ms=14781 general_measured_tokens=false"
        )

        summary = benchmark_summary_line(identity, pass_fields, matrix)

        self.assertIn("runtime=gemma_local_runtime", summary)
        self.assertIn("provider=AlphaLlamaCppProvider", summary)
        self.assertIn("artifact_path=gemma-2b.gguf", summary)
        self.assertIn("fallback=none", summary)
        self.assertIn("available=true", summary)
        self.assertIn("matrix_profile=full", summary)
        self.assertIn(
            "matrix_cases=english_source_bound_document_qa,bengali_source_bound_document_qa,english_open_no_document_query",
            summary,
        )
        self.assertIn("draft_model_path_type=nil", summary)
        self.assertIn("matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192", summary)
        self.assertIn("source_token_speed=9.00", summary)
        self.assertIn("bengali_token_speed=8.84", summary)
        self.assertIn("general_token_speed=8.57", summary)

    def test_missing_benchmark_matrix_is_rejected(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "missing_benchmark_matrix"):
            benchmark_summary_line({}, {}, {})

    def test_incomplete_benchmark_matrix_is_rejected(self):
        incomplete_matrix = {
            "profile": "quick",
            "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
        }

        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "missing_benchmark_matrix_cases"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                {"runtime": "gemma_local_runtime", "profile": "quick"},
                incomplete_matrix,
            )

    def test_mismatched_benchmark_profile_is_rejected(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_profile_mismatch"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                {"runtime": "gemma_local_runtime", "profile": "quick"},
                {
                    "profile": "full",
                    "cases": "english_source_bound_document_qa",
                    "stages": "source:document_qa",
                },
            )

    def test_missing_pass_profile_is_rejected(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "missing_benchmark_pass_profile"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                {"runtime": "gemma_local_runtime"},
                {
                    "profile": "quick",
                    "cases": "english_source_bound_document_qa",
                    "stages": "source:document_qa",
                },
            )

    def test_missing_identity_is_rejected_for_benchmark_summary(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "missing_runtime_identity"):
            benchmark_summary_line(
                {},
                {"runtime": "gemma_local_runtime", "profile": "quick"},
                {
                    "profile": "quick",
                    "cases": "english_source_bound_document_qa",
                    "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
                },
            )

    def test_benchmark_summary_rejects_pass_runtime_mismatch(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_runtime_mismatch"):
            benchmark_summary_line(
                {"actual_runtime": "mlx_swift_lm", "requested_runtime": "mlx_swift_lm"},
                {
                    "runtime": "gemma_local_runtime",
                    "profile": "quick",
                    "source_input_tokens": "120",
                    "source_output_tokens": "32",
                    "source_token_speed": "11.0",
                    "source_first_token_ms": "900",
                    "source_measured_tokens": "false",
                },
                {
                    "profile": "quick",
                    "cases": "english_source_bound_document_qa",
                    "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
                },
            )

    def test_benchmark_summary_rejects_requested_runtime_mismatch(self):
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_requested_runtime_mismatch"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime", "requested_runtime": "mlx_swift_lm"},
                {
                    "runtime": "gemma_local_runtime",
                    "profile": "quick",
                    "source_input_tokens": "120",
                    "source_output_tokens": "32",
                    "source_token_speed": "11.0",
                    "source_first_token_ms": "900",
                    "source_measured_tokens": "false",
                },
                {
                    "profile": "quick",
                    "cases": "english_source_bound_document_qa",
                    "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
                },
            )

    def test_present_identity_with_missing_optional_fields_reports_nil(self):
        summary = benchmark_summary_line(
            {"actual_runtime": "gemma_local_runtime"},
            {
                "runtime": "gemma_local_runtime",
                "profile": "quick",
                "source_input_tokens": "120",
                "source_output_tokens": "32",
                "source_token_speed": "11.0",
                "source_first_token_ms": "900",
                "source_measured_tokens": "false",
            },
            {
                "profile": "quick",
                "cases": "english_source_bound_document_qa",
                "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
            },
        )

        self.assertIn("runtime=gemma_local_runtime", summary)
        self.assertIn("requested_runtime=nil", summary)
        self.assertIn("matrix_cases=english_source_bound_document_qa", summary)
        self.assertIn("matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192", summary)

    def test_benchmark_summary_rejects_missing_stage_metrics(self):
        matrix = {
            "profile": "quick",
            "cases": "english_source_bound_document_qa",
            "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
        }
        pass_fields = {"runtime": "gemma_local_runtime", "profile": "quick"}

        self.assertEqual(
            benchmark_stage_metric_error(pass_fields, matrix),
            "source_input_tokens=nil",
        )
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_stage_metrics_missing"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                pass_fields,
                matrix,
            )

    def test_benchmark_summary_rejects_matrix_case_stage_mismatch(self):
        matrix = {
            "profile": "quick",
            "cases": "english_source_bound_document_qa,english_open_no_document_query",
            "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
        }
        pass_fields = {
            "runtime": "gemma_local_runtime",
            "profile": "quick",
            "source_input_tokens": "120",
            "source_output_tokens": "32",
            "source_token_speed": "11.0",
            "source_first_token_ms": "900",
            "source_measured_tokens": "false",
        }

        self.assertEqual(benchmark_matrix_shape_error(matrix), "cases=2 stages=1")
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_matrix_shape_mismatch"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                pass_fields,
                matrix,
            )

    def test_benchmark_summary_rejects_duplicate_matrix_stages(self):
        matrix = {
            "profile": "quick",
            "cases": "english_source_bound_document_qa,english_open_no_document_query",
            "stages": "source:document_qa:en:source_refs_required:max_tokens=192,"
            "source:open_query:en:no_source_refs:max_tokens=192",
        }
        pass_fields = {
            "runtime": "gemma_local_runtime",
            "profile": "quick",
            "source_input_tokens": "120",
            "source_output_tokens": "32",
            "source_token_speed": "11.0",
            "source_first_token_ms": "900",
            "source_measured_tokens": "false",
        }

        self.assertEqual(benchmark_matrix_shape_error(matrix), "duplicate_stages=source,source")
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_matrix_shape_mismatch"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                pass_fields,
                matrix,
            )

    def test_benchmark_summary_rejects_token_speed_without_output_tokens(self):
        matrix = {
            "profile": "quick",
            "cases": "english_source_bound_document_qa",
            "stages": "source:document_qa:en:source_refs_required:max_tokens=192",
        }
        pass_fields = {
            "runtime": "gemma_local_runtime",
            "profile": "quick",
            "source_input_tokens": "120",
            "source_output_tokens": "nil",
            "source_token_speed": "11.0",
            "source_first_token_ms": "900",
            "source_measured_tokens": "false",
        }

        self.assertEqual(
            benchmark_stage_metric_error(pass_fields, matrix),
            "source_output_tokens=nil",
        )
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_stage_metrics_missing"):
            benchmark_summary_line(
                {"actual_runtime": "gemma_local_runtime"},
                pass_fields,
                matrix,
            )

    def test_runtime_identity_artifact_rules_reject_wrong_lane_shapes(self):
        self.assertIsNone(
            runtime_identity_artifact_error(
                {"model_format": "local_model_artifact", "artifact_path_type": "file"},
                "gemma_local_runtime",
            )
        )
        self.assertEqual(
            runtime_identity_artifact_error(
                {"model_format": "local_model_artifact", "artifact_path_type": "file"},
                "mlx_swift_lm",
            ),
            "model_format=local_model_artifact",
        )
        self.assertEqual(
            runtime_identity_artifact_error(
                {"model_format": "mlx_directory", "artifact_path_type": "file"},
                "mlx_swift_lm",
            ),
            "artifact_path_type=file",
        )
        self.assertIsNone(
            runtime_identity_artifact_error(
                {"model_format": "system_model", "artifact_path_type": "system"},
                "apple_foundation_models",
            )
        )
        self.assertEqual(
            runtime_identity_artifact_error(
                {"model_format": "system_model", "artifact_path_type": "file"},
                "apple_foundation_models",
            ),
            "system_model_path_type=file",
        )
        self.assertEqual(
            runtime_identity_artifact_error(
                {"model_format": "coreml_model", "artifact_path_type": "system"},
                "apple_foundation_models",
            ),
            "adapter_path_type=system",
        )

    def test_runtime_identity_availability_rules_reject_fallback_numbers(self):
        self.assertIsNone(
            runtime_identity_availability_error(
                {"available": "true", "fallback": "none"}
            )
        )
        self.assertEqual(
            runtime_identity_availability_error(
                {"available": "false", "fallback": "none"}
            ),
            "available=false",
        )
        self.assertEqual(
            runtime_identity_availability_error(
                {"available": "true", "fallback": "deterministic_dev"}
            ),
            "fallback=deterministic_dev",
        )
        self.assertEqual(
            runtime_identity_availability_error({"fallback": "none"}),
            "available=nil",
        )
        self.assertEqual(
            runtime_identity_availability_error({"available": "true"}),
            "fallback=nil",
        )

    def test_runtime_identity_draft_artifact_rules_are_lane_aware(self):
        active_mtp = {
            "acceleration": "draftModelSpeculative",
            "draft_tokens": "2",
            "draft_model": "mtp.gguf",
            "draft_model_path_type": "file",
            "draft_status": "active",
        }
        active_mlx = {
            **active_mtp,
            "draft_model": "mlx-draft",
            "draft_model_path_type": "directory",
        }

        self.assertIsNone(runtime_identity_draft_artifact_error(active_mtp, "gemma_local_runtime"))
        self.assertIsNone(runtime_identity_draft_artifact_error(active_mlx, "mlx_swift_lm"))
        self.assertEqual(
            runtime_identity_draft_artifact_error(active_mtp, "mlx_swift_lm"),
            "draft_model_path_type=file",
        )
        self.assertEqual(
            runtime_identity_draft_artifact_error(active_mlx, "gemma_local_runtime"),
            "draft_model_path_type=directory",
        )
        self.assertEqual(
            runtime_identity_draft_artifact_error(
                {**active_mtp, "draft_model": "mtp.bin"},
                "gemma_local_runtime",
            ),
            "draft_model_format=mtp.bin",
        )
        self.assertEqual(
            runtime_identity_draft_artifact_error(
                {**active_mtp, "draft_status": "validator_rejected"},
                "gemma_local_runtime",
            ),
            "draft_status=validator_rejected",
        )

    def test_benchmark_summary_rejects_active_draft_identity_when_stage_runs_standard(self):
        identity = parse_fields(
            "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider "
            "requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime "
            "model_format=gguf artifact_path_type=file artifact_path=gemma-4-e4b.gguf "
            "acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp.gguf "
            "draft_model_path_type=file draft_status=active context_tokens=4096 "
            "gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil"
        )
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=mtp_quick "
            "cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token "
            "stages=source:document_qa:en:source_refs_required:max_tokens=64,"
            "general:open_query:en:no_source_refs:max_tokens=64"
        )
        pass_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime profile=mtp_quick elapsed=10.00s "
            "source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 "
            "source_first_token_ms=900 source_measured_tokens=true "
            "source_acceleration=draftModelSpeculative source_draft_tokens=2 source_draft_model=mtp.gguf "
            "general_input_tokens=80 general_output_tokens=16 general_token_speed=10.5 "
            "general_first_token_ms=850 general_measured_tokens=true "
            "general_acceleration=standard general_draft_tokens=nil general_draft_model=nil"
        )

        self.assertEqual(
            benchmark_stage_draft_error(identity, pass_fields, matrix),
            "general_acceleration=standard",
        )
        with self.assertRaisesRegex(MissingBenchmarkMatrixError, "benchmark_draft_stage_mismatch"):
            benchmark_summary_line(identity, pass_fields, matrix)

    def test_benchmark_summary_accepts_active_draft_identity_when_all_stages_match(self):
        identity = parse_fields(
            "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider "
            "requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime "
            "model_format=gguf artifact_path_type=file artifact_path=gemma-4-e4b.gguf "
            "acceleration=draftModelSpeculative draft_tokens=2 draft_model=mtp.gguf "
            "draft_model_path_type=file draft_status=active context_tokens=4096 "
            "gpu_offload=n_gpu_layers:0 fallback=none available=true error=nil"
        )
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=mtp_quick "
            "cases=english_source_bound_document_qa_low_token,english_open_no_document_query_low_token "
            "stages=source:document_qa:en:source_refs_required:max_tokens=64,"
            "general:open_query:en:no_source_refs:max_tokens=64"
        )
        pass_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_PASS runtime=gemma_local_runtime profile=mtp_quick elapsed=10.00s "
            "source_input_tokens=120 source_output_tokens=32 source_token_speed=11.0 "
            "source_first_token_ms=900 source_measured_tokens=true "
            "source_acceleration=draftModelSpeculative source_draft_tokens=2 source_draft_model=mtp.gguf "
            "general_input_tokens=80 general_output_tokens=16 general_token_speed=10.5 "
            "general_first_token_ms=850 general_measured_tokens=true "
            "general_acceleration=draftModelSpeculative general_draft_tokens=2 general_draft_model=mtp.gguf"
        )

        summary = benchmark_summary_line(identity, pass_fields, matrix)

        self.assertIn("acceleration=draftModelSpeculative", summary)
        self.assertIn("source_acceleration=draftModelSpeculative", summary)
        self.assertIn("general_draft_model=mtp.gguf", summary)

    def test_failure_summary_preserves_identity_errors_and_stage_metrics(self):
        identity = parse_fields(
            "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider "
            "requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime "
            "model_format=local_model_artifact artifact_path_type=file acceleration=standard "
            "draft_tokens=nil draft_model=nil draft_model_path_type=nil draft_status=no_draft_configured"
        )
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=full "
            "stages=source:document_qa:en:source_refs_required:max_tokens=192,"
            "tamil:document_qa:ta:source_refs_required:max_tokens=192"
        )
        fail_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=gemma_local_runtime profile=full elapsed=66.49s "
            "source_error=nil tamil_error=nil source_grounded=true tamil_grounded=false "
            "source_refs_kept=true tamil_refs_kept=true source_native_model=true tamil_native_model=true "
            "source_input_tokens=207 source_output_tokens=118 source_token_speed=7.78 "
            "source_acceleration=draftModelSpeculative source_draft_tokens=2 source_draft_model=mtp.gguf "
            "tamil_input_tokens=310 tamil_output_tokens=59 tamil_token_speed=7.53 "
            "tamil_acceleration=standard tamil_draft_tokens=nil tamil_draft_model=nil"
        )

        summary = failure_summary_line(identity, fail_fields, matrix)

        self.assertIn("ROSS_SMOKE_FAILURE_SUMMARY", summary)
        self.assertIn("runtime=gemma_local_runtime", summary)
        self.assertIn("fail_runtime=gemma_local_runtime", summary)
        self.assertIn("draft_status=no_draft_configured", summary)
        self.assertIn("draft_model_path_type=nil", summary)
        self.assertIn("matrix_profile=full", summary)
        self.assertIn("matrix_cases=nil", summary)
        self.assertIn("matrix_shape_error=cases=0", summary)
        self.assertIn("tamil_grounded=false", summary)
        self.assertIn("tamil_token_speed=7.53", summary)
        self.assertIn("source_acceleration=draftModelSpeculative", summary)
        self.assertIn("source_draft_model=mtp.gguf", summary)
        self.assertIn("tamil_acceleration=standard", summary)
        self.assertIn("tamil_draft_model=nil", summary)

    def test_failure_summary_survives_missing_runtime_identity(self):
        fail_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=mlx_swift_lm profile=quick "
            "stage=runtime_health error=missing_runtime_identity elapsed=2.4s"
        )

        summary = failure_summary_line(None, fail_fields, None)

        self.assertIn("ROSS_SMOKE_FAILURE_SUMMARY", summary)
        self.assertIn("runtime=nil", summary)
        self.assertIn("fail_runtime=mlx_swift_lm", summary)
        self.assertIn("requested_runtime=nil", summary)
        self.assertIn("draft_status=nil", summary)
        self.assertIn("profile=quick", summary)
        self.assertIn("stage=runtime_health", summary)
        self.assertIn("error=missing_runtime_identity", summary)

    def test_failure_summary_preserves_matrix_shape_error(self):
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=quick "
            "cases=english_source_bound_document_qa,english_open_no_document_query "
            "stages=source:document_qa:en:source_refs_required:max_tokens=192"
        )
        fail_fields = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_FAIL runtime=apple_foundation_models profile=quick "
            "stage=provider_health error=unsupported_runtime_on_platform elapsed=1.7s"
        )

        summary = failure_summary_line(
            {"actual_runtime": "apple_foundation_models", "requested_runtime": "apple_foundation_models"},
            fail_fields,
            matrix,
        )

        self.assertIn("runtime=apple_foundation_models", summary)
        self.assertIn("fail_runtime=apple_foundation_models", summary)
        self.assertIn("matrix_shape_error=cases=2", summary)


if __name__ == "__main__":
    unittest.main()
