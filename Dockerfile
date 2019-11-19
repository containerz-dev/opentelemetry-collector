# syntax = docker.io/docker/dockerfile:1.1.3-experimental

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
	# hack for lock to k8s.io/client-go@v12.0.0
	go mod edit -replace 'k8s.io/client-go=k8s.io/client-go@78d2af792babf2dd937ba2e2a8d99c753a5eda89' && \
	go mod tidy -v && \
	CGO_ENABLED=0 GOBIN=${OUTDIR}/usr/bin/ go install -a -v -tags='osusergo,netgo,static,static_build' -installsuffix='netgo' -ldflags='-d -s -w "-extldflags=-fno-PIC -static"' \
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

# 55678: OpenCensus receiver
EXPOSE 55678

# 55679: zPagez extension
EXPOSE 55679

# 14250: Jaeger gRPC
# EXPOSE 14250

# 14267: Jaeger thrift TChannel receiver
# EXPOSE 14267

# 14268: Jaeger thrift HTTPPort receiver
# EXPOSE 14268

#	5775: ZipkinThriftUDPPort
# EXPOSE 5775/udp

# 6831: CompactThriftUDPPort
# EXPOSE 6831/udp

# 6832: BinaryThriftUDPPort
# EXPOSE 6832/udp

# 1777: pprof extension
# EXPOSE 1777/tcp
 
# 8889: prometheus metrics
# EXPOSE 8886/tcp
 
# 8889: prometheus exporter metrics
# EXPOSE 8889/tcp

# 13133: health check extension
# EXPOSE 13133/tcp

ENTRYPOINT ["/usr/bin/otelcol"]
