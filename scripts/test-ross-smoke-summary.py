#!/usr/bin/env python3
import unittest

from ross_smoke_summary import benchmark_summary_line, parse_fields


class RossSmokeSummaryTests(unittest.TestCase):
    def test_benchmark_summary_includes_runtime_matrix_and_stage_metrics(self):
        identity = parse_fields(
            "ROSS_RUNTIME_IDENTITY provider=AlphaLlamaCppProvider "
            "requested_runtime=gemma_local_runtime actual_runtime=gemma_local_runtime "
            "model_format=gguf artifact_path_type=file acceleration=standard "
            "draft_tokens=nil draft_model=nil draft_status=no_draft_configured"
        )
        matrix = parse_fields(
            "ROSS_LOCAL_MODEL_SMOKE_BENCHMARK_MATRIX profile=full "
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
        self.assertIn("matrix_profile=full", summary)
        self.assertIn("matrix_stages=source:document_qa:en:source_refs_required:max_tokens=192", summary)
        self.assertIn("source_token_speed=9.00", summary)
        self.assertIn("bengali_token_speed=8.84", summary)
        self.assertIn("general_token_speed=8.57", summary)

    def test_empty_fields_are_reported_as_nil(self):
        summary = benchmark_summary_line({}, {}, {})

        self.assertIn("runtime=nil", summary)
        self.assertIn("matrix_stages=nil", summary)


if __name__ == "__main__":
    unittest.main()
