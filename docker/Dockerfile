# syntax=docker/dockerfile:1.7
# GodotGo toolchain image: headless Godot 4 editor (+ optional export
# templates), gdtoolkit and the Godot MCP server. It runs the workspace's own
# tools/*.sh scripts against any project in games/ or framework/.
# Material Maker lives in Dockerfile.material-maker-src (built from source).
#
# Build:  tools/docker.sh build
# Use:    tools/docker.sh verify [project] | check | test | smoke | export | shell

ARG UBUNTU_VERSION=24.04
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG GODOT_VERSION=4.7.2
ARG GODOT_RELEASE=stable
ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive \
	GODOT_VERSION=${GODOT_VERSION} \
	GODOT_RELEASE=${GODOT_RELEASE}

# Runtime libraries: Godot headless needs very little, but Material Maker and
# xvfb-driven runs need X11 + Mesa (llvmpipe/lavapipe software rendering).
RUN apt-get update && apt-get install -y --no-install-recommends \
		ca-certificates curl unzip xz-utils git bash \
		python3 python3-venv python3-pip \
		nodejs npm \
		xvfb xauth \
		libx11-6 libxcursor1 libxinerama1 libxrandr2 libxi6 libxext6 libxrender1 libxkbcommon0 \
		libgl1 libegl1 libgl1-mesa-dri mesa-vulkan-drivers libvulkan1 \
		libasound2t64 libpulse0 libfontconfig1 libdbus-1-3 libudev1 \
	&& rm -rf /var/lib/apt/lists/*

# --- Godot editor (headless-capable) + export templates -----------------------
RUN set -eux; \
	case "${TARGETARCH}" in \
		amd64) GODOT_ARCH=x86_64 ;; \
		arm64) GODOT_ARCH=arm64 ;; \
		*) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
	esac; \
	tag="${GODOT_VERSION}-${GODOT_RELEASE}"; \
	base="https://github.com/godotengine/godot/releases/download/${tag}"; \
	curl -fsSL -o /tmp/godot.zip "${base}/Godot_v${tag}_linux.${GODOT_ARCH}.zip"; \
	unzip -q /tmp/godot.zip -d /tmp/godot; \
	install -m 0755 "/tmp/godot/Godot_v${tag}_linux.${GODOT_ARCH}" /usr/local/bin/godot; \
	rm -rf /tmp/godot /tmp/godot.zip; \
	godot --version

ARG WITH_EXPORT_TEMPLATES=0
RUN set -eux; \
	if [ "${WITH_EXPORT_TEMPLATES}" = "1" ]; then \
		case "${TARGETARCH}" in amd64) GODOT_ARCH=x86_64 ;; arm64) GODOT_ARCH=arm64 ;; esac; \
		tag="${GODOT_VERSION}-${GODOT_RELEASE}"; \
		dest="/root/.local/share/godot/export_templates/${GODOT_VERSION}.${GODOT_RELEASE}"; \
		mkdir -p "${dest}"; \
		curl -fsSL -o /tmp/templates.tpz "https://github.com/godotengine/godot/releases/download/${tag}/Godot_v${tag}_export_templates.tpz"; \
		# Only the Linux templates for this CPU are kept (~130 MB instead of ~1.2 GB).
		unzip -q -j /tmp/templates.tpz "templates/linux_release.${GODOT_ARCH}" "templates/linux_debug.${GODOT_ARCH}" "templates/version.txt" -d "${dest}"; \
		rm -f /tmp/templates.tpz; ls -la "${dest}"; \
	fi

# --- gdtoolkit (gdlint / gdformat) --------------------------------------------
RUN python3 -m venv /opt/gdtoolkit \
	&& /opt/gdtoolkit/bin/pip install --no-cache-dir "gdtoolkit==4.*" \
	&& ln -s /opt/gdtoolkit/bin/gdlint /opt/gdtoolkit/bin/gdformat /opt/gdtoolkit/bin/gdradon /usr/local/bin/

# --- Godot MCP server (stdio) -------------------------------------------------
RUN npm install -g --no-fund --no-audit @coding-solo/godot-mcp \
	&& ln -sf "$(npm root -g)/@coding-solo/godot-mcp/build/index.js" /usr/local/bin/godot-mcp \
	&& chmod +x /usr/local/bin/godot-mcp

ENV GODOT_BIN=/usr/local/bin/godot \
	GODOT_PATH=/usr/local/bin/godot \
	XDG_DATA_HOME=/root/.local/share \
	XDG_CONFIG_HOME=/root/.config \
	XDG_CACHE_HOME=/root/.cache \
	LIBGL_ALWAYS_SOFTWARE=1 \
	GALLIUM_DRIVER=llvmpipe

WORKDIR /workspace
COPY docker/entrypoint.sh /usr/local/bin/godotgo-entrypoint
COPY docker/mcp-entrypoint.sh /usr/local/bin/godotgo-mcp-entrypoint
RUN chmod +x /usr/local/bin/godotgo-entrypoint /usr/local/bin/godotgo-mcp-entrypoint
ENTRYPOINT ["/usr/local/bin/godotgo-entrypoint"]
CMD ["tools/verify.sh"]
