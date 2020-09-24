# syntax = docker.io/docker/dockerfile:experimental

# target: otelcol-builder
ARG GOLANG_VERSION
ARG ALPINE_VERSION
FROM docker.io/golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS otelcol-builder
ENV \
	OUTDIR=/out \
	CGO_ENABLED=0 \
	GO111MODULE=on

RUN set -eux && \
	apk add --no-cache \
		ca-certificates \
		git \
		make \
	&& \
	mkdir -p "${OUTDIR}/usr/local/bin"

ARG OTELCOL_VERSION
ENV OTELCOL_VERSION=${OTELCOL_VERSION:-latest}

RUN set -eux && \
	if [ "${OTELCOL_VERSION}" = 'latest' ]; then OTELCOL_VERSION=$(wget -O - -q https://api.github.com/repos/open-telemetry/opentelemetry-collector/releases/latest | grep '"tag_name":' | sed -E 's|.*"([^"]+)".*|\1|'); fi && \
	git clone --depth 1 --branch "${OTELCOL_VERSION}" --single-branch \
		https://github.com/open-telemetry/opentelemetry-collector.git "${GOPATH}/src/go.opentelemetry.io/collector"

RUN set -eux && \
	go get -u -v github.com/mjibson/esc@latest github.com/google/addlicense@latest

WORKDIR ${GOPATH}/src/go.opentelemetry.io/collector

RUN set -eux && \
	sed -i 's|url = git@github.com:|url = https://github.com/|' .gitmodules && \
	git submodule update --init --depth 1

RUN set -eux && \
	GOFLAGS='-v -tags=osusergo,netgo,static,static_build -trimpath -installsuffix=netgo' make otelcol GOOS="$(go env GOOS)" GOARCH="$(go env GOARCH)" BUILD_INFO="-ldflags='-X=go.opentelemetry.io/collector/internal/version.GitHash=$(git rev-parse --short HEAD) -X=go.opentelemetry.io/collector/internal/version.BuildType=release -d -s -w '-extldflags=-static''"

RUN mv ./bin/otelcol_"$(go env GOOS)"_"$(go env GOARCH)" ${OUTDIR}/usr/local/bin/otelcol

# target: otelcol
FROM gcr.io/distroless/static:nonroot AS otelcol
COPY --from=otelcol-builder --chown=nonroot:nonroot /out/ /
USER nonroot:nonroot
#     55678: OpenCensus receiver
#     55679: zPagez extension
#     14250: Jaeger gRPC
#     14267: Jaeger thrift TChannel receiver
#     14268: Jaeger thrift HTTPPort receiver
#  5775/udp: ZipkinThriftUDPPort
#  6831/udp: CompactThriftUDPPort
#  6831/udp: BinaryThriftUDPPort
#  1777/tcp: pprof extension
#  8886/tcp: prometheus metrics
#  8889/tcp: prometheus exporter metrics
# 13133/tcp: health check extension
EXPOSE 55678 55679
ENTRYPOINT ["otelcol"]


# target: otelcol-debug
FROM gcr.io/distroless/base:debug-nonroot AS otelcol-debug
COPY --from=otelcol-builder --chown=nonroot:nonroot /out/ /
USER nonroot:nonroot
#     55678: OpenCensus receiver
#     55679: zPagez extension
#     14250: Jaeger gRPC
#     14267: Jaeger thrift TChannel receiver
#     14268: Jaeger thrift HTTPPort receiver
#  5775/udp: ZipkinThriftUDPPort
#  6831/udp: CompactThriftUDPPort
#  6831/udp: BinaryThriftUDPPort
#  1777/tcp: pprof extension
#  8886/tcp: prometheus metrics
#  8889/tcp: prometheus exporter metrics
# 13133/tcp: health check extension
EXPOSE 55678 55679
ENTRYPOINT ["otelcol"]
