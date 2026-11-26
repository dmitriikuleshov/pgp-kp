# Все строки одной цели выполняются в одном shell; ошибка останавливает цель.
SHELL := /bin/sh
.SHELLFLAGS := -eu -c
.ONESHELL:
.DEFAULT_GOAL := all

# Сборка программы.
NVCC := /usr/local/cuda/bin/nvcc

TARGET := build/kp
SOURCE := src/main.cu
HEADERS := $(wildcard src/*/*.hpp src/*/*.cuh)

NVCC_FLAGS := \
	-std=c++17 \
	-O2 \
	-arch=native \
	-Isrc \
	-Werror cross-execution-space-call \
	-Xcompiler=-Wall,-Wextra

# Настройки можно переопределить: make video WIDTH=1920 HEIGHT=1080 SSAA=2
FRAMES ?= 60
WIDTH ?= 1280
HEIGHT ?= 960
DEPTH ?= 10
SSAA ?= 3
FPS ?= 30
RENDER_MODE ?= gpu
FRAME_DIR ?= data/out/hd
VIDEO ?= data/animation_hd.mp4
PYTHON ?= $(abspath ../lab3/.venv/bin/python)

FFMPEG ?= ffmpeg
WINDOWS_FFMPEG := /mnt/c/Users/admin/AppData/Local/YouTubeDownloader/bin/ffmpeg.exe

.PHONY: all clean render png encode-video clean-frames video animation

all: $(TARGET)

$(TARGET): $(SOURCE) $(HEADERS) | build
	@echo "  NVCC      $@"
	$(NVCC) $(NVCC_FLAGS) "$<" -o "$@"

build:
	@mkdir -p "$@"

render: $(TARGET)
	@mkdir -p "$(FRAME_DIR)"
	# Меняем число кадров, путь, разрешение и глубину/SSAA в --default.
	# Угол обзора в третьей строке сохраняется.
	"$(TARGET)" --default |
		sed -e '1s|.*|$(FRAMES)|' \
		    -e '2s|.*|$(FRAME_DIR)/frame_%d.data|' \
		    -e '3s|^[^ ]* [^ ]* |$(WIDTH) $(HEIGHT) |' \
		    -e '$$s|.*|$(DEPTH) $(SSAA)|' |
		"$(TARGET)" --$(RENDER_MODE)

png:
	@found=0
	for frame in "$(FRAME_DIR)"/frame_*.data; do
		if [ -f "$$frame" ]; then
			"$(PYTHON)" src/tools/data2png.py "$$frame" "$${frame%.data}.png"
			found=1
		fi
	done
	if [ "$$found" -eq 0 ]; then
		echo "No .data frames found in $(FRAME_DIR)" >&2
		exit 1
	fi

encode-video:
	@ffmpeg="$(FFMPEG)"
	if ! command -v "$$ffmpeg" >/dev/null 2>&1; then
		if [ "$$ffmpeg" = ffmpeg ] && [ -x "$(WINDOWS_FFMPEG)" ]; then
			ffmpeg="$(WINDOWS_FFMPEG)"
		else
			echo "FFmpeg was not found: $$ffmpeg" >&2
			exit 1
		fi
	fi
	if [ ! -f "$(FRAME_DIR)/frame_0.png" ]; then
		echo "No PNG frames found in $(FRAME_DIR)" >&2
		exit 1
	fi

	mkdir -p "$(dir $(VIDEO))"
	input="$(abspath $(FRAME_DIR))/frame_%d.png"
	output="$(abspath $(VIDEO))"
	# Windows-версия FFmpeg получает Windows-пути к кадрам и видео.
	case "$$ffmpeg" in
		*.exe)
			input=$$(wslpath -w "$$input")
			output=$$(wslpath -w "$$output")
			;;
	esac
	"$$ffmpeg" -y -framerate "$(FPS)" -start_number 0 \
		-i "$$input" -frames:v "$(FRAMES)" -c:v libx264 -crf 18 \
		-pix_fmt yuv420p -movflags +faststart "$$output"

clean-frames:
	@find "$(FRAME_DIR)" -maxdepth 1 -type f \
		\( -name 'frame_*.data' -o -name 'frame_*.png' \) -delete
	rmdir "$(FRAME_DIR)" 2>/dev/null || true

video:
	@$(MAKE) render
	$(MAKE) png
	$(MAKE) encode-video
	$(MAKE) clean-frames

animation: video

clean:
	@echo "  CLEAN"
	rm -rf build
