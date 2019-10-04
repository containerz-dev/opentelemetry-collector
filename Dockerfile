# syntax = docker.io/docker/dockerfile-upstream:master-experimental

# target: otelcol-builder
ARG GOLANG_VERSION
ARG ALPINE_VERSION
FROM docker.io/golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS otelcol-builder
ENV OUTDIR='/out' \
	GO111MODULE='on' \
	GOPROXY="https://proxy.golang.org" \
	GOSUMDB="sum.golang.org"
RUN set -eux && \
	apk add --no-cache \
		bzr \
		ca-certificates \
		git
RUN set -eux && \
	mkdir -p "${OUTDIR}/usr/bin" && \
	GO111MODULE=off go get -u -d -v github.com/open-telemetry/opentelemetry-collector || true
WORKDIR ${GOPATH}/src/github.com/open-telemetry/opentelemetry-collector
RUN set -eux && \
	go mod tidy -v && \
	CGO_ENABLED=0 GOBIN=${OUTDIR}/usr/bin/ go install -a -u -v -x -tags='osusergo,netgo,static,static_build' -installsuffix='netgo' -buildmode='pie' -ldflags='-d -s -w "-extldflags=-fno-PIC -static"' \
		github.com/open-telemetry/opentelemetry-collector/cmd/otelcol

# target: nonroot
FROM gcr.io/distroless/static:nonroot AS nonroot

# target: otelcol
FROM scratch AS otelcol
COPY --from=nonroot /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=nonroot /etc/passwd /etc/passwd
COPY --from=nonroot /etc/group /etc/group
COPY --from=otelcol-builder --chown=nonroot:nonroot /out/ /
USER nonroot:nonroot

# 55678: OpenCensus
EXPOSE 55678
# 55679: zPagez
EXPOSE 55679
# 14250: Jaeger GRPCPort
EXPOSE 14250
# 14267: TChannel
EXPOSE 14267
# 14268: CollectorHTTPPort
EXPOSE 14268
#	5775: ZipkinThriftUDPPort
EXPOSE 5775/udp
# 6831: CompactThriftUDPPort
EXPOSE 6831/udp
# 6832: BinaryThriftUDPPort
EXPOSE 6832/udp

ENTRYPOINT ["/usr/bin/otelcol"]
