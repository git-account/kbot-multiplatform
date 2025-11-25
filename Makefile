APP=$(shell basename $(shell git remote get-url origin))
REGISTRY=ghcr.io/git-account
BUILDER_IMAGE ?= quay.io/projectquay/golang:1.24
BASE_IMAGE ?= scratch
VERSION=$(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
# Determine host OS/ARCH and default TARGETOS/TARGETARCH to them
HOST_UNAME_S := $(shell uname -s 2>/dev/null || echo Linux)
HOST_UNAME_M := $(shell uname -m 2>/dev/null || echo x86_64)
HOST_OS := $(shell echo $(HOST_UNAME_S) | tr '[:upper:]' '[:lower:]' | sed -e 's/mingw.*/windows/' -e 's/cygwin.*/windows/')
HOST_ARCH := $(shell echo $(HOST_UNAME_M) | sed -e 's/x86_64/amd64/' -e 's/amd64/amd64/' -e 's/aarch64/arm64/' -e 's/arm64/arm64/' -e 's/armv7l/armv7/')

# default to host values but allow overrides
TARGETOS ?= $(HOST_OS)
TARGETARCH ?= $(HOST_ARCH)

# Supported platforms
LINUX_OS=linux
LINUX_ARCH=amd64
ARM_OS=linux
ARM_ARCH=arm64
MACOS_OS=darwin
MACOS_ARCH=amd64
WINDOWS_OS=windows
WINDOWS_ARCH=amd64

format: 
	gofmt -s -w ./

.PHONY: format lint test get build linux arm macos windows all image image-all image-local push clean

lint:
	golint

test:
	go test -v

get:
	go mod download

build: format get
	CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -v -o kbot -ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"

# Build for specific platforms
linux: format get
	CGO_ENABLED=0 GOOS=${LINUX_OS} GOARCH=${LINUX_ARCH} go build -v -o kbot-${LINUX_OS}-${LINUX_ARCH} -ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"

arm: format get
	CGO_ENABLED=0 GOOS=${ARM_OS} GOARCH=${ARM_ARCH} go build -v -o kbot-${ARM_OS}-${ARM_ARCH} -ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"

macos: format get
	CGO_ENABLED=0 GOOS=${MACOS_OS} GOARCH=${MACOS_ARCH} go build -v -o kbot-${MACOS_OS}-${MACOS_ARCH} -ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"

windows: format get
	CGO_ENABLED=0 GOOS=${WINDOWS_OS} GOARCH=${WINDOWS_ARCH} go build -v -o kbot-${WINDOWS_OS}-${WINDOWS_ARCH}.exe -ldflags "-X=github.com/git-account/kbot-multiplatform/cmd.appVersion=${VERSION}"

all: linux arm macos windows
	@echo "Built all platforms"

IMAGE_TAG=${REGISTRY}/${APP}:${VERSION}-${TARGETARCH}
image:
	# Build a single platform image using docker build
	# Note: building images for other architectures without QEMU/emulation may result in images that don't run on your host
	docker build \
		--build-arg TARGETOS=${TARGETOS} --build-arg TARGETARCH=${TARGETARCH} --build-arg VERSION=${VERSION} \
		--build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --build-arg BASE_IMAGE=${BASE_IMAGE} \
		-t ${IMAGE_TAG} .

image-local:
	# Build a single platform image locally using build args (no need to set --platform)
	# Note: building for a different platform without QEMU may produce an image that won't run locally
	docker build \
		--build-arg TARGETOS=${TARGETOS} --build-arg TARGETARCH=${TARGETARCH} --build-arg VERSION=${VERSION} \
		--build-arg BUILDER_IMAGE=${BUILDER_IMAGE} --build-arg BASE_IMAGE=${BASE_IMAGE} \
		-t ${IMAGE_TAG} .

image-all:
	# Build multiple single-arch images using docker build (no manifests, not multi-arch image). This loops over common platforms.
	$(MAKE) image TARGETOS=linux TARGETARCH=amd64 BUILDER_IMAGE=${BUILDER_IMAGE} BASE_IMAGE=alpine
	$(MAKE) image TARGETOS=linux TARGETARCH=arm64 BUILDER_IMAGE=${BUILDER_IMAGE} BASE_IMAGE=alpine
	# Windows images will need a Windows base image and a Windows builder to create a runnable image from linux host.
	$(MAKE) image TARGETOS=windows TARGETARCH=amd64 BUILDER_IMAGE=${BUILDER_IMAGE} BASE_IMAGE=mcr.microsoft.com/windows/nanoserver:1809

push:
	docker push ${IMAGE_TAG}
clean:
	rm -rf kbot kbot-* *.exe
	-docker rmi ${IMAGE_TAG}