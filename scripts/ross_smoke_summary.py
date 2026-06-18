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


def benchmark_summary_fields(identity, pass_fields, matrix_fields):
    if not matrix_fields:
        raise MissingBenchmarkMatrixError("missing_benchmark_matrix")

    summary = {
        "runtime": summary_value(identity, "actual_runtime"),
        "requested_runtime": summary_value(identity, "requested_runtime"),
        "model_format": summary_value(identity, "model_format"),
        "artifact_path_type": summary_value(identity, "artifact_path_type"),
        "acceleration": summary_value(identity, "acceleration"),
        "draft_tokens": summary_value(identity, "draft_tokens"),
        "draft_model": summary_value(identity, "draft_model"),
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
