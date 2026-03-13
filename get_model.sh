#!/usr/bin/env bash
#
# Download pretrained FastVLM MLX models into Visionkit/model/
# Adapted from apex-vlm/app/get_pretrained_mlx_model.sh
#
# For licensing see accompanying LICENSE_MODEL file.
# Copyright (C) 2025 Apple Inc. All Rights Reserved.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_DEST="${SCRIPT_DIR}/Visionkit/model"

show_help() {
    local is_error=${1:-true}

    echo "Usage: $0 --model <model_size> [--dest <directory>]"
    echo
    echo "Required arguments:"
    echo "  --model <model_size>    Size of the model to download"
    echo
    echo "Optional arguments:"
    echo "  --dest <directory>      Destination directory (default: Visionkit/model/)"
    echo
    echo "Available model sizes:"
    echo "  0.5b  - 0.5B parameter model (FP16)  ~1.0 GB"
    echo "  1.5b  - 1.5B parameter model (INT8)  ~1.9 GB"
    echo "  7b    - 7B parameter model (INT4)     ~4.5 GB"
    echo
    echo "Examples:"
    echo "  $0 --model 1.5b"
    echo "  $0 --model 7b --dest /path/to/model"

    if [ "$is_error" = "false" ]; then
        exit 0
    else
        exit 1
    fi
}

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --model) model_size="$2"; shift ;;
        --dest) dest_dir="$2"; shift ;;
        --help) show_help false ;;
        *) echo -e "Unknown parameter: $1\n"; show_help true ;;
    esac
    shift
done

if [ -z "$model_size" ]; then
    echo -e "Error: --model parameter is required\n"
    show_help true
fi

dest_dir="${dest_dir:-$DEFAULT_DEST}"

# Map model size to full model name
case "$model_size" in
    "0.5b") model="llava-fastvithd_0.5b_stage3_llm.fp16" ;;
    "1.5b") model="llava-fastvithd_1.5b_stage3_llm.int8" ;;
    "7b")   model="llava-fastvithd_7b_stage3_llm.int4" ;;
    *)
        echo -e "Error: Invalid model size '$model_size'\n"
        show_help true
        ;;
esac

cleanup() {
    rm -rf "$tmp_dir"
}

trap cleanup EXIT INT TERM

# Create destination directory if needed
if [ ! -d "$dest_dir" ]; then
    echo "Creating destination directory: $dest_dir"
    mkdir -p "$dest_dir"
elif [ "$(ls -A "$dest_dir")" ]; then
    echo "Destination directory '$dest_dir' exists and is not empty."
    read -p "Clear it and continue? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "\nStopping."
        exit 1
    fi
    echo -e "\nClearing existing contents in '$dest_dir'"
    rm -rf "${dest_dir:?}"/*
fi

# Download
tmp_dir=$(mktemp -d)
tmp_zip_file="${tmp_dir}/${model}.zip"
tmp_extract_dir="${tmp_dir}/${model}"
mkdir -p "$tmp_extract_dir"

base_url="https://ml-site.cdn-apple.com/datasets/fastvlm"

echo -e "\nDownloading '${model}' model ...\n"
wget -q --progress=bar:noscroll --show-progress -O "$tmp_zip_file" "$base_url/$model.zip"

echo -e "\nUnzipping model..."
unzip -q "$tmp_zip_file" -d "$tmp_extract_dir"

echo -e "\nCopying model files to '$dest_dir'..."
cp -r "$tmp_extract_dir/$model"/* "$dest_dir"

if [ ! -d "$dest_dir" ] || [ -z "$(ls -A "$dest_dir")" ]; then
    echo -e "\nModel extraction failed."
    exit 1
fi

echo -e "\nDone! Model '$model_size' installed to '$dest_dir'"
