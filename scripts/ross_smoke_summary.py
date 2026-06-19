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
STAGE_AUX_METRICS = [
    "raw_chars",
    "parsed_chars",
    "output_chars",
    "refs",
    "source_refs",
    "warning_count",
    "grounded",
    "refs_kept",
    "native_model",
    "error",
    "runtime_error_detail",
]

CASE_EXPECTATIONS = {
    "english_source_bound_document_qa": {
        "stage": "source",
        "task": "document_qa",
        "language": "en",
        "source_refs": "source_refs_required",
    },
    "english_source_bound_document_qa_low_token": {
        "stage": "source",
        "task": "document_qa",
        "language": "en",
        "source_refs": "source_refs_required",
    },
    "bengali_source_bound_document_qa": {
        "stage": "bengali",
        "task": "document_qa",
        "language": "bn",
        "source_refs": "source_refs_required",
    },
    "hindi_source_bound_document_qa": {
        "stage": "hindi",
        "task": "document_qa",
        "language": "hi",
        "source_refs": "source_refs_required",
    },
    "tamil_source_bound_document_qa": {
        "stage": "tamil",
        "task": "document_qa",
        "language": "ta",
        "source_refs": "source_refs_required",
    },
    "telugu_source_bound_document_qa": {
        "stage": "telugu",
        "task": "document_qa",
        "language": "te",
        "source_refs": "source_refs_required",
    },
    "english_open_no_document_query": {
        "stage": "general",
        "task": "open_query",
        "language": "en",
        "source_refs": "no_source_refs",
    },
    "english_open_no_document_query_low_token": {
        "stage": "general",
        "task": "open_query",
        "language": "en",
        "source_refs": "no_source_refs",
    },
}

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


def first_non_nil_value(*values):
    for value in values:
        if value not in (None, "", "nil"):
            return value
    return "nil"


def runtime_identity_supported_runtime_error(identity):
    actual_runtime = identity.get("actual_runtime")
    if actual_runtime not in RUNTIME_ARTIFACT_RULES:
        return f"actual_runtime={summary_value(identity, 'actual_runtime')}"
    return None


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
    if expected_runtime == "gemma_local_runtime":
        artifact_path = (identity.get("artifact_path") or "").lower()
        if not artifact_path.endswith(".gguf"):
            return f"gguf_file_path={summary_value(identity, 'artifact_path')}"
    if expected_runtime == "mlx_swift_lm":
        artifact_path = (identity.get("artifact_path") or "").lower()
        if artifact_path.endswith((".gguf", ".safetensors", ".bin")):
            return f"mlx_directory_path={summary_value(identity, 'artifact_path')}"
    if expected_runtime == "apple_foundation_models":
        if model_format == "system_model" and artifact_path_type != "system":
            return f"system_model_path_type={summary_value(identity, 'artifact_path_type')}"
        if model_format == "system_model":
            artifact_path = identity.get("artifact_path") or ""
            if artifact_path != "system-model" and not artifact_path.startswith("system://"):
                return f"system_model_path={summary_value(identity, 'artifact_path')}"
        if model_format != "system_model" and artifact_path_type == "system":
            return f"adapter_path_type={summary_value(identity, 'artifact_path_type')}"
        if model_format != "system_model":
            artifact_path = (identity.get("artifact_path") or "").lower()
            if artifact_path.endswith((".gguf", ".bin", ".safetensors")):
                return f"adapter_foreign_model_path={summary_value(identity, 'artifact_path')}"
            allowed_suffixes = (
                (".bundle", ".mlmodel", ".mlmodelc", ".mlpackage")
                if model_format in {"foundation_adapter", "coreai_adapter"}
                else (".mlmodel", ".mlmodelc", ".mlpackage")
            )
            if not artifact_path.endswith(allowed_suffixes):
                return f"adapter_path_shape={summary_value(identity, 'artifact_path')}"
    return None


def runtime_identity_availability_error(identity):
    if identity.get("available") != "true":
        return f"available={summary_value(identity, 'available')}"

    if identity.get("fallback") != "none":
        return f"fallback={summary_value(identity, 'fallback')}"

    return None


def runtime_identity_resource_error(identity):
    if identity.get("provider") in (None, "", "nil"):
        return f"provider={summary_value(identity, 'provider')}"

    context_tokens = identity.get("context_tokens")
    try:
        if int(context_tokens) <= 0:
            return f"context_tokens={summary_value(identity, 'context_tokens')}"
    except (TypeError, ValueError):
        return f"context_tokens={summary_value(identity, 'context_tokens')}"

    if identity.get("gpu_offload") in (None, "", "nil"):
        return f"gpu_offload={summary_value(identity, 'gpu_offload')}"

    if identity.get("checksum_verified") != "true":
        return f"checksum_verified={summary_value(identity, 'checksum_verified')}"

    return None


def runtime_identity_diagnostic_error(identity):
    if identity.get("error") not in (None, "", "nil"):
        return f"error={summary_value(identity, 'error')}"

    if identity.get("runtime_error_detail") not in (None, "", "nil"):
        return f"runtime_error_detail={summary_value(identity, 'runtime_error_detail')}"

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
    if expected_runtime == "mlx_swift_lm":
        draft_model = (identity.get("draft_model") or "").lower()
        if draft_model.endswith((".gguf", ".safetensors", ".bin")):
            return f"draft_model_format={summary_value(identity, 'draft_model')}"
    return None


def benchmark_matrix_stage_names(matrix_fields):
    names = []
    for stage_spec in benchmark_matrix_stage_specs(matrix_fields):
        names.append(stage_spec["stage"])
    return names


def benchmark_matrix_stage_specs(matrix_fields):
    stages = matrix_fields.get("stages") or ""
    specs = []
    for stage_spec in stages.split(","):
        parts = [part.strip() for part in stage_spec.split(":") if part.strip()]
        if not parts:
            continue
        spec = {
            "stage": parts[0],
            "task": parts[1] if len(parts) > 1 else "nil",
            "language": parts[2] if len(parts) > 2 else "nil",
            "source_refs": parts[3] if len(parts) > 3 else "nil",
            "max_tokens": "nil",
        }
        for part in parts[4:]:
            if part.startswith("max_tokens="):
                spec["max_tokens"] = part.split("=", 1)[1] or "nil"
                break
        specs.append(spec)
    return specs


def benchmark_matrix_stage_specs_by_name(matrix_fields):
    return {spec["stage"]: spec for spec in benchmark_matrix_stage_specs(matrix_fields)}


def benchmark_matrix_stage_max_tokens(matrix_fields):
    max_tokens_by_stage = {}
    for stage_spec in benchmark_matrix_stage_specs(matrix_fields):
        raw_value = stage_spec.get("max_tokens")
        try:
            max_tokens_by_stage[stage_spec["stage"]] = int(raw_value)
        except (TypeError, ValueError):
            max_tokens_by_stage[stage_spec["stage"]] = None
    return max_tokens_by_stage


def benchmark_matrix_case_names(matrix_fields):
    cases = matrix_fields.get("cases") or ""
    return [case.strip() for case in cases.split(",") if case.strip()]


def benchmark_matrix_shape_error(matrix_fields):
    cases = benchmark_matrix_case_names(matrix_fields)
    stages = benchmark_matrix_stage_names(matrix_fields)
    stage_specs = benchmark_matrix_stage_specs(matrix_fields)
    if len(cases) != len(stages):
        return f"cases={len(cases)} stages={len(stages)}"
    unknown_stages = [stage for stage in stages if stage not in STAGES]
    if unknown_stages:
        return "unknown_stages=" + ",".join(unknown_stages)
    if len(set(stages)) != len(stages):
        return "duplicate_stages=" + ",".join(stages)
    unknown_cases = [case for case in cases if case not in CASE_EXPECTATIONS]
    if unknown_cases:
        return "unknown_cases=" + ",".join(unknown_cases)
    for case, stage_spec in zip(cases, stage_specs):
        expected = CASE_EXPECTATIONS[case]
        for key in ("stage", "task", "language", "source_refs"):
            if stage_spec.get(key) != expected[key]:
                return (
                    f"case_stage_mismatch case={case} {key}={summary_value(stage_spec, key)} "
                    f"expected={expected[key]}"
                )
        if stage_spec.get("max_tokens") in (None, "nil", ""):
            return f"case_stage_mismatch case={case} max_tokens=nil"
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


def benchmark_profile_draft_error(identity, pass_fields, matrix_fields):
    profiles = {
        (pass_fields.get("profile") or "").replace("-", "_"),
        (matrix_fields.get("profile") or "").replace("-", "_"),
    }
    if not any(profile == "mtp" or profile.startswith("mtp_") for profile in profiles):
        return None
    if identity.get("acceleration") != "draftModelSpeculative":
        return f"acceleration={summary_value(identity, 'acceleration')}"
    return None


def benchmark_stage_metric_error(pass_fields, matrix_fields):
    required_metrics = [
        "input_tokens",
        "output_tokens",
        "token_speed",
        "first_token_ms",
        "measured_tokens",
    ]
    matrix_max_tokens = benchmark_matrix_stage_max_tokens(matrix_fields)
    for stage in benchmark_matrix_stage_names(matrix_fields):
        for metric in required_metrics:
            key = f"{stage}_{metric}"
            if pass_fields.get(key) in (None, ""):
                return f"{key}=nil"

        output_tokens = pass_fields.get(f"{stage}_output_tokens")
        input_tokens = pass_fields.get(f"{stage}_input_tokens")
        token_speed = pass_fields.get(f"{stage}_token_speed")
        first_token_ms = pass_fields.get(f"{stage}_first_token_ms")
        measured_tokens = pass_fields.get(f"{stage}_measured_tokens")
        try:
            if int(input_tokens) < 0:
                return f"{stage}_input_tokens={input_tokens}"
        except (TypeError, ValueError):
            return f"{stage}_input_tokens={summary_value(pass_fields, f'{stage}_input_tokens')}"
        try:
            parsed_output_tokens = int(output_tokens)
            if parsed_output_tokens <= 0:
                return f"{stage}_output_tokens={output_tokens}"
            matrix_stage_max_tokens = matrix_max_tokens.get(stage)
            if matrix_stage_max_tokens is None:
                return f"{stage}_max_tokens=nil"
            if parsed_output_tokens > matrix_stage_max_tokens:
                return f"{stage}_output_tokens={output_tokens}>max_tokens={matrix_stage_max_tokens}"
        except (TypeError, ValueError):
            return f"{stage}_output_tokens={summary_value(pass_fields, f'{stage}_output_tokens')}"
        try:
            if float(token_speed) <= 0:
                return f"{stage}_token_speed={token_speed}"
        except (TypeError, ValueError):
            return f"{stage}_token_speed={summary_value(pass_fields, f'{stage}_token_speed')}"
        try:
            if float(first_token_ms) < 0:
                return f"{stage}_first_token_ms={first_token_ms}"
        except (TypeError, ValueError):
            return f"{stage}_first_token_ms={summary_value(pass_fields, f'{stage}_first_token_ms')}"
        if measured_tokens not in ("true", "false"):
            return f"{stage}_measured_tokens={summary_value(pass_fields, f'{stage}_measured_tokens')}"
    return None


def benchmark_stage_quality_error(pass_fields, matrix_fields):
    stage_specs = benchmark_matrix_stage_specs_by_name(matrix_fields)
    for stage in benchmark_matrix_stage_names(matrix_fields):
        stage_error = pass_fields.get(f"{stage}_error")
        if stage_error not in (None, "", "nil"):
            return f"{stage}_error={stage_error}"

        native_model = pass_fields.get(f"{stage}_native_model")
        if native_model != "true":
            return f"{stage}_native_model={summary_value(pass_fields, f'{stage}_native_model')}"

        stage_spec = stage_specs.get(stage, {})
        if stage_spec.get("source_refs") == "source_refs_required":
            source_ref_key = "source_refs" if stage == "source" else f"{stage}_source_refs"
            source_refs = pass_fields.get(source_ref_key)
            try:
                if int(source_refs) <= 0:
                    return f"{source_ref_key}={source_refs}"
            except (TypeError, ValueError):
                return f"{source_ref_key}={summary_value(pass_fields, source_ref_key)}"
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
    if identity_requested_runtime in (None, "nil", ""):
        raise MissingBenchmarkMatrixError("benchmark_requested_runtime_missing requested_runtime=nil")
    if identity_requested_runtime != actual_runtime:
        raise MissingBenchmarkMatrixError(
            f"benchmark_requested_runtime_mismatch requested_runtime={identity_requested_runtime} "
            f"identity_runtime={actual_runtime}"
        )
    pass_requested_runtime = pass_fields.get("requested_runtime") if pass_fields else None
    if pass_requested_runtime in (None, "nil", ""):
        raise MissingBenchmarkMatrixError("benchmark_pass_requested_runtime_missing requested_runtime=nil")
    if pass_requested_runtime not in (None, "nil", actual_runtime):
        raise MissingBenchmarkMatrixError(
            f"benchmark_pass_requested_runtime_mismatch requested_runtime={pass_requested_runtime} "
            f"identity_runtime={actual_runtime}"
        )
    if (
        identity_requested_runtime not in (None, "nil")
        and pass_requested_runtime not in (None, "nil")
        and pass_requested_runtime != identity_requested_runtime
    ):
        raise MissingBenchmarkMatrixError(
            f"benchmark_pass_requested_runtime_mismatch pass_requested_runtime={pass_requested_runtime} "
            f"identity_requested_runtime={identity_requested_runtime}"
        )
    identity_pack_runtime = identity.get("pack_runtime")
    if identity_pack_runtime not in (None, "nil", actual_runtime):
        raise MissingBenchmarkMatrixError(
            f"benchmark_pack_runtime_mismatch pack_runtime={identity_pack_runtime} "
            f"identity_runtime={actual_runtime}"
        )
    supported_runtime_error = runtime_identity_supported_runtime_error(identity)
    if supported_runtime_error:
        raise MissingBenchmarkMatrixError(f"benchmark_runtime_unsupported {supported_runtime_error}")
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
    if identity_pack_runtime in (None, "nil", ""):
        raise MissingBenchmarkMatrixError("benchmark_pack_runtime_missing pack_runtime=nil")
    availability_error = runtime_identity_availability_error(identity)
    if availability_error:
        raise MissingBenchmarkMatrixError(f"benchmark_runtime_unavailable {availability_error}")
    resource_error = runtime_identity_resource_error(identity)
    if resource_error:
        raise MissingBenchmarkMatrixError(f"benchmark_runtime_identity_missing {resource_error}")
    diagnostic_error = runtime_identity_diagnostic_error(identity)
    if diagnostic_error:
        raise MissingBenchmarkMatrixError(f"benchmark_runtime_diagnostic_error {diagnostic_error}")
    artifact_error = runtime_identity_artifact_error(identity, actual_runtime)
    if artifact_error:
        raise MissingBenchmarkMatrixError(f"benchmark_runtime_artifact_mismatch {artifact_error}")
    draft_artifact_error = runtime_identity_draft_artifact_error(identity, actual_runtime)
    if draft_artifact_error:
        raise MissingBenchmarkMatrixError(f"benchmark_draft_artifact_mismatch {draft_artifact_error}")
    draft_profile_error = benchmark_profile_draft_error(identity, pass_fields, matrix_fields)
    if draft_profile_error:
        raise MissingBenchmarkMatrixError(f"benchmark_draft_profile_mismatch {draft_profile_error}")
    draft_stage_error = benchmark_stage_draft_error(identity, pass_fields, matrix_fields)
    if draft_stage_error:
        raise MissingBenchmarkMatrixError(f"benchmark_draft_stage_mismatch {draft_stage_error}")
    stage_metric_error = benchmark_stage_metric_error(pass_fields, matrix_fields)
    if stage_metric_error:
        raise MissingBenchmarkMatrixError(f"benchmark_stage_metrics_missing {stage_metric_error}")
    stage_quality_error = benchmark_stage_quality_error(pass_fields, matrix_fields)
    if stage_quality_error:
        raise MissingBenchmarkMatrixError(f"benchmark_stage_quality_missing {stage_quality_error}")

    summary = {
        "provider": summary_value(identity, "provider"),
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "pack_runtime": summary_value(identity, "pack_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "checksum_verified": summary_value(identity, "checksum_verified"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "artifact_path": summary_value(identity, "artifact_path"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_candidate_tokens": summary_value(identity, "draft_candidate_tokens"),
        "draft_candidate_model": summary_value(identity, "draft_candidate_model"),
        "draft_status": summary_value(identity, "draft_status"),
        "draft_error_detail": summary_value(identity, "draft_error_detail"),
        "runtime_error_detail": summary_value(identity, "runtime_error_detail"),
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
    stage_specs = benchmark_matrix_stage_specs_by_name(matrix_fields)
    stage_cases = {}
    for case_name, spec in zip(
        benchmark_matrix_case_names(matrix_fields),
        benchmark_matrix_stage_specs(matrix_fields),
    ):
        stage_cases[spec.get("stage")] = case_name
    for stage in STAGES:
        if stage in stage_specs:
            stage_spec = stage_specs[stage]
            summary[f"{stage}_case"] = stage_cases.get(stage, "nil")
            summary[f"{stage}_task"] = summary_value(stage_spec, "task")
            summary[f"{stage}_language"] = summary_value(stage_spec, "language")
            summary[f"{stage}_source_refs_policy"] = summary_value(stage_spec, "source_refs")
            summary[f"{stage}_max_tokens"] = summary_value(stage_spec, "max_tokens")
        for metric in METRICS:
            key = f"{stage}_{metric}"
            if key in pass_fields:
                summary[key] = pass_fields[key]
        for metric in STAGE_AUX_METRICS:
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
    requested_runtime = first_non_nil_value(
        identity.get("requested_runtime"),
        fail_fields.get("requested_runtime"),
    )
    identity_runtime = identity.get("actual_runtime")
    artifact_runtime = identity_runtime if identity_runtime in RUNTIME_ARTIFACT_RULES else requested_runtime
    summary = {
        "provider": summary_value(identity, "provider"),
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": requested_runtime,
        "pack_runtime": summary_value(identity, "pack_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "checksum_verified": summary_value(identity, "checksum_verified"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "artifact_path": summary_value(identity, "artifact_path"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
        "draft_model_path_type": summary_value(identity, "draft_model_path_type"),
        "draft_candidate_tokens": summary_value(identity, "draft_candidate_tokens"),
        "draft_candidate_model": summary_value(identity, "draft_candidate_model"),
        "draft_status": summary_value(identity, "draft_status"),
        "draft_error_detail": summary_value(identity, "draft_error_detail"),
        "runtime_error_detail": summary_value(identity, "runtime_error_detail"),
        "context_tokens": summary_value(identity, "context_tokens"),
        "gpu_offload": summary_value(identity, "gpu_offload"),
        "fallback": summary_value(identity, "fallback"),
        "available": summary_value(identity, "available"),
        "identity_error": summary_value(identity, "error"),
        "identity_availability_error": runtime_identity_availability_error(identity) or "nil",
        "identity_resource_error": runtime_identity_resource_error(identity) or "nil",
        "identity_artifact_error": runtime_identity_artifact_error(identity, artifact_runtime) or "nil",
        "identity_draft_artifact_error": runtime_identity_draft_artifact_error(identity, artifact_runtime) or "nil",
        "fail_runtime": summary_value(fail_fields, "runtime"),
        "fail_runtime_error_detail": summary_value(fail_fields, "runtime_error_detail"),
        "fail_draft_error_detail": summary_value(fail_fields, "draft_error_detail"),
        "profile": summary_value(fail_fields, "profile"),
        "matrix_profile": summary_value(matrix_fields or {}, "profile"),
        "matrix_cases": summary_value(matrix_fields or {}, "cases"),
        "matrix_stages": summary_value(matrix_fields or {}, "stages"),
        "matrix_shape_error": benchmark_matrix_shape_error(matrix_fields or {}) or "nil",
        "stage": summary_value(fail_fields, "stage"),
        "error": summary_value(fail_fields, "error"),
        "elapsed": summary_value(fail_fields, "elapsed"),
    }

    stage_specs = benchmark_matrix_stage_specs_by_name(matrix_fields or {})
    stage_cases = {
        spec.get("stage"): case_name
        for case_name, spec in zip(
            benchmark_matrix_case_names(matrix_fields or {}),
            benchmark_matrix_stage_specs(matrix_fields or {}),
        )
    }
    for stage in STAGES:
        stage_spec = stage_specs.get(stage)
        if stage_spec:
            summary[f"{stage}_case"] = stage_cases.get(stage, "nil")
            summary[f"{stage}_task"] = summary_value(stage_spec, "task")
            summary[f"{stage}_language"] = summary_value(stage_spec, "language")
            summary[f"{stage}_source_refs_policy"] = summary_value(stage_spec, "source_refs")
            summary[f"{stage}_max_tokens"] = summary_value(stage_spec, "max_tokens")
        for metric in METRICS:
            key = f"{stage}_{metric}"
            if key in fail_fields:
                summary[key] = fail_fields[key]
        for metric in STAGE_AUX_METRICS:
            key = f"{stage}_{metric}"
            if key in fail_fields:
                summary[key] = fail_fields[key]
    return summary


def failure_summary_line(identity, fail_fields, matrix_fields=None):
    summary = failure_summary_fields(identity or {}, fail_fields or {}, matrix_fields)
    return "ROSS_SMOKE_FAILURE_SUMMARY " + " ".join(
        f"{key}={value}" for key, value in summary.items()
    )
