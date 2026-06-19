#!/usr/bin/env python3
"""Shared parser helpers for Ross local-model smoke benchmark logs."""

STAGES = ["source", "general", "bengali", "hindi", "tamil", "telugu"]
METRICS = [
    "input_tokens",
    "output_tokens",
    "token_speed",
    "first_token_ms",
    "measured_tokens",
    "acceleration",
    "draft_tokens",
    "draft_model",
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


def runtime_identity_availability_error(identity):
    if identity.get("available") != "true":
        return f"available={summary_value(identity, 'available')}"

    if identity.get("fallback") != "none":
        return f"fallback={summary_value(identity, 'fallback')}"

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
    if expected_runtime == "gemma_local_runtime":
        draft_model = identity.get("draft_model") or ""
        if not draft_model.lower().endswith(".gguf"):
            return f"draft_model_format={summary_value(identity, 'draft_model')}"
    return None


def benchmark_matrix_stage_names(matrix_fields):
    stages = matrix_fields.get("stages") or ""
    names = []
    for stage in stages.split(","):
        name = stage.split(":", 1)[0].strip()
        if name:
            names.append(name)
    return names


def benchmark_matrix_case_names(matrix_fields):
    cases = matrix_fields.get("cases") or ""
    return [case.strip() for case in cases.split(",") if case.strip()]


def benchmark_matrix_shape_error(matrix_fields):
    cases = benchmark_matrix_case_names(matrix_fields)
    stages = benchmark_matrix_stage_names(matrix_fields)
    if len(cases) != len(stages):
        return f"cases={len(cases)} stages={len(stages)}"
    if len(set(stages)) != len(stages):
        return "duplicate_stages=" + ",".join(stages)
    return None


def benchmark_stage_draft_error(identity, pass_fields, matrix_fields):
    if identity.get("acceleration") != "draftModelSpeculative":
        return None

    identity_draft_tokens = identity.get("draft_tokens")
    identity_draft_model = identity.get("draft_model")
    for stage in benchmark_matrix_stage_names(matrix_fields):
        stage_acceleration = pass_fields.get(f"{stage}_acceleration")
        if stage_acceleration != "draftModelSpeculative":
            return f"{stage}_acceleration={summary_value(pass_fields, f'{stage}_acceleration')}"
        stage_draft_tokens = pass_fields.get(f"{stage}_draft_tokens")
        if stage_draft_tokens in (None, "nil"):
            return f"{stage}_draft_tokens={summary_value(pass_fields, f'{stage}_draft_tokens')}"
        if identity_draft_tokens not in (None, "nil") and stage_draft_tokens != identity_draft_tokens:
            return f"{stage}_draft_tokens={stage_draft_tokens}"
        stage_draft_model = pass_fields.get(f"{stage}_draft_model")
        if stage_draft_model in (None, "nil"):
            return f"{stage}_draft_model={summary_value(pass_fields, f'{stage}_draft_model')}"
        if identity_draft_model not in (None, "nil") and stage_draft_model != identity_draft_model:
            return f"{stage}_draft_model={stage_draft_model}"
    return None


def benchmark_stage_metric_error(pass_fields, matrix_fields):
    required_metrics = [
        "input_tokens",
        "output_tokens",
        "token_speed",
        "first_token_ms",
        "measured_tokens",
    ]
    for stage in benchmark_matrix_stage_names(matrix_fields):
        for metric in required_metrics:
            key = f"{stage}_{metric}"
            if pass_fields.get(key) in (None, ""):
                return f"{key}=nil"

        output_tokens = pass_fields.get(f"{stage}_output_tokens")
        token_speed = pass_fields.get(f"{stage}_token_speed")
        if token_speed != "nil":
            try:
                if float(token_speed) <= 0:
                    return f"{stage}_token_speed={token_speed}"
            except ValueError:
                return f"{stage}_token_speed={token_speed}"
            try:
                if int(output_tokens) <= 0:
                    return f"{stage}_output_tokens={output_tokens}"
            except ValueError:
                return f"{stage}_output_tokens={output_tokens}"

        if pass_fields.get(f"{stage}_measured_tokens") == "true":
            if pass_fields.get(f"{stage}_input_tokens") == "nil":
                return f"{stage}_input_tokens=nil"
            if output_tokens == "nil":
                return f"{stage}_output_tokens=nil"
    return None


def benchmark_summary_fields(identity, pass_fields, matrix_fields):
    if not matrix_fields:
        raise MissingBenchmarkMatrixError("missing_benchmark_matrix")
    actual_runtime = identity.get("actual_runtime") if identity else None
    if not actual_runtime:
        raise MissingBenchmarkMatrixError("missing_runtime_identity")
    pass_runtime = pass_fields.get("runtime") if pass_fields else None
    if not pass_runtime:
        raise MissingBenchmarkMatrixError("missing_benchmark_pass_runtime")
    if pass_runtime != actual_runtime:
        raise MissingBenchmarkMatrixError(
            f"benchmark_runtime_mismatch pass_runtime={summary_value(pass_fields, 'runtime')} "
            f"identity_runtime={summary_value(identity, 'actual_runtime')}"
        )
    identity_requested_runtime = identity.get("requested_runtime")
    if identity_requested_runtime not in (None, "nil", actual_runtime):
        raise MissingBenchmarkMatrixError(
            f"benchmark_requested_runtime_mismatch requested_runtime={identity_requested_runtime} "
            f"identity_runtime={actual_runtime}"
        )
    for required_key in ("profile", "cases", "stages"):
        if not matrix_fields.get(required_key):
            raise MissingBenchmarkMatrixError(f"missing_benchmark_matrix_{required_key}")
    if not pass_fields.get("profile"):
        raise MissingBenchmarkMatrixError("missing_benchmark_pass_profile")
    if pass_fields.get("profile") != matrix_fields.get("profile"):
        raise MissingBenchmarkMatrixError(
            f"benchmark_profile_mismatch pass_profile={summary_value(pass_fields, 'profile')} "
            f"matrix_profile={summary_value(matrix_fields, 'profile')}"
        )
    matrix_shape_error = benchmark_matrix_shape_error(matrix_fields)
    if matrix_shape_error:
        raise MissingBenchmarkMatrixError(f"benchmark_matrix_shape_mismatch {matrix_shape_error}")
    draft_stage_error = benchmark_stage_draft_error(identity, pass_fields, matrix_fields)
    if draft_stage_error:
        raise MissingBenchmarkMatrixError(f"benchmark_draft_stage_mismatch {draft_stage_error}")
    stage_metric_error = benchmark_stage_metric_error(pass_fields, matrix_fields)
    if stage_metric_error:
        raise MissingBenchmarkMatrixError(f"benchmark_stage_metrics_missing {stage_metric_error}")

    summary = {
        "provider": summary_value(identity, "provider"),
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "artifact_path": summary_value(identity, "artifact_path"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_status": summary_value(identity, "draft_status"),
        "context_tokens": summary_value(identity, "context_tokens"),
        "gpu_offload": summary_value(identity, "gpu_offload"),
        "fallback": summary_value(identity, "fallback"),
        "available": summary_value(identity, "available"),
        "identity_error": summary_value(identity, "error"),
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
        "provider": summary_value(identity, "provider"),
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "artifact_path": summary_value(identity, "artifact_path"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_status": summary_value(identity, "draft_status"),
        "context_tokens": summary_value(identity, "context_tokens"),
        "gpu_offload": summary_value(identity, "gpu_offload"),
        "fallback": summary_value(identity, "fallback"),
        "available": summary_value(identity, "available"),
        "identity_error": summary_value(identity, "error"),
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
