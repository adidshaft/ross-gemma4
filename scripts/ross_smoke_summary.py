#!/usr/bin/env python3
"""Shared parser helpers for Ross local-model smoke benchmark logs."""

STAGES = ["source", "general", "bengali", "hindi", "tamil", "telugu"]
METRICS = [
    "input_tokens",
    "output_tokens",
    "token_speed",
    "first_token_ms",
    "measured_tokens",
]

RUNTIME_ARTIFACT_RULES = {
    "gemma_local_runtime": {
        "formats": {"local_model_artifact", "gguf", "gguf_model"},
        "path_types": {"file"},
    },
    "mlx_swift_lm": {
        "formats": {"mlx_directory"},
        "path_types": {"directory"},
    },
    "apple_foundation_models": {
        "formats": {"system_model", "foundation_adapter", "coreai_adapter", "coreml_model"},
        "path_types": {"system", "file", "directory"},
    },
}


class MissingBenchmarkMatrixError(ValueError):
    """Raised when a pass marker lacks the benchmark matrix marker."""


def parse_fields(line, skip_prefix=True):
    fields = {}
    chunks = line.split()[1:] if skip_prefix else line.split()
    for chunk in chunks:
        if "=" not in chunk:
            continue
        key, value = chunk.split("=", 1)
        fields[key] = value
    return fields


def summary_value(fields, key):
    value = fields.get(key)
    return value if value not in (None, "") else "nil"


def runtime_identity_artifact_error(identity, expected_runtime):
    rules = RUNTIME_ARTIFACT_RULES.get(expected_runtime)
    if not rules:
        return None

    model_format = identity.get("model_format")
    artifact_path_type = identity.get("artifact_path_type")
    if model_format not in rules["formats"]:
        return f"model_format={summary_value(identity, 'model_format')}"
    if artifact_path_type not in rules["path_types"]:
        return f"artifact_path_type={summary_value(identity, 'artifact_path_type')}"
    if expected_runtime == "apple_foundation_models":
        if model_format == "system_model" and artifact_path_type != "system":
            return f"system_model_path_type={summary_value(identity, 'artifact_path_type')}"
        if model_format != "system_model" and artifact_path_type == "system":
            return f"adapter_path_type={summary_value(identity, 'artifact_path_type')}"
    return None


def runtime_identity_draft_artifact_error(identity, expected_runtime):
    if identity.get("acceleration") != "draftModelSpeculative":
        return None
    if identity.get("draft_status") != "active":
        return f"draft_status={summary_value(identity, 'draft_status')}"
    if identity.get("draft_tokens") in (None, "nil"):
        return f"draft_tokens={summary_value(identity, 'draft_tokens')}"
    if identity.get("draft_model") in (None, "nil"):
        return f"draft_model={summary_value(identity, 'draft_model')}"

    draft_path_type = identity.get("draft_model_path_type")
    expected_path_types = {
        "gemma_local_runtime": {"file"},
        "mlx_swift_lm": {"directory"},
    }.get(expected_runtime)
    if not expected_path_types:
        return None
    if draft_path_type not in expected_path_types:
        return f"draft_model_path_type={summary_value(identity, 'draft_model_path_type')}"
    return None


def benchmark_summary_fields(identity, pass_fields, matrix_fields):
    if not matrix_fields:
        raise MissingBenchmarkMatrixError("missing_benchmark_matrix")
    for required_key in ("profile", "cases", "stages"):
        if not matrix_fields.get(required_key):
            raise MissingBenchmarkMatrixError(f"missing_benchmark_matrix_{required_key}")

    summary = {
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_status": summary_value(identity, "draft_status"),
        "profile": summary_value(pass_fields, "profile"),
        "matrix_profile": summary_value(matrix_fields, "profile"),
        "matrix_cases": summary_value(matrix_fields, "cases"),
        "matrix_stages": summary_value(matrix_fields, "stages"),
        "elapsed": summary_value(pass_fields, "elapsed"),
    }
    for stage in STAGES:
        for metric in METRICS:
            key = f"{stage}_{metric}"
            if key in pass_fields:
                summary[key] = pass_fields[key]
    return summary


def benchmark_summary_line(identity, pass_fields, matrix_fields):
    summary = benchmark_summary_fields(identity, pass_fields, matrix_fields)
    return "ROSS_SMOKE_BENCHMARK_SUMMARY " + " ".join(
        f"{key}={value}" for key, value in summary.items()
    )


def failure_summary_fields(identity, fail_fields, matrix_fields=None):
    summary = {
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_status": summary_value(identity, "draft_status"),
        "profile": summary_value(fail_fields, "profile"),
        "matrix_profile": summary_value(matrix_fields or {}, "profile"),
        "matrix_cases": summary_value(matrix_fields or {}, "cases"),
        "matrix_stages": summary_value(matrix_fields or {}, "stages"),
        "stage": summary_value(fail_fields, "stage"),
        "error": summary_value(fail_fields, "error"),
        "elapsed": summary_value(fail_fields, "elapsed"),
    }

    for key, value in fail_fields.items():
        if (
            key.endswith("_error")
            or key.endswith("_grounded")
            or key.endswith("_refs_kept")
            or key.endswith("_native_model")
            or key.endswith("_warning_count")
        ):
            summary[key] = value

    for stage in STAGES:
        for metric in METRICS:
            key = f"{stage}_{metric}"
            if key in fail_fields:
                summary[key] = fail_fields[key]
    return summary


def failure_summary_line(identity, fail_fields, matrix_fields=None):
    summary = failure_summary_fields(identity or {}, fail_fields or {}, matrix_fields)
    return "ROSS_SMOKE_FAILURE_SUMMARY " + " ".join(
        f"{key}={value}" for key, value in summary.items()
    )
