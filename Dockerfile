# syntax = docker.io/docker/dockerfile-upstream:master-experimental

# target: otelsvc-builder
ARG GOLANG_VERSION
ARG ALPINE_VERSION
FROM docker.io/golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} AS otelsvc-builder
ENV OUTDIR=/out \
	GOPROXY="https://proxy.golang.org" \
	GOSUMDB="sum.golang.org"
RUN set -eux && \
	apk add --no-cache \
		bzr \
		ca-certificates \
		git
RUN set -eux && \
	go get -u -d -v github.com/open-telemetry/opentelemetry-service || true
RUN set -eux && \
	mkdir -p "${OUTDIR}/usr/bin" && \
	cd ${GOPATH}/src/github.com/open-telemetry/opentelemetry-service && \
	GO111MODULE=on go mod tidy -v && \
	GO111MODULE=on CGO_ENABLED=0 GOBIN=${OUTDIR}/usr/bin/ go install -a -v -tags 'osusergo netgo static static_build' -installsuffix 'netgo' -ldflags='-d -s -w -extldflags=-static' \
		github.com/open-telemetry/opentelemetry-service/cmd/otelsvc

# target: nonroot
FROM gcr.io/distroless/static:nonroot AS nonroot

# target: otelsvc
FROM scratch AS otelsvc
COPY --from=nonroot /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=nonroot /etc/passwd /etc/passwd
COPY --from=nonroot /etc/group /etc/group
COPY --from=otelsvc-builder --chown=nonroot:nonroot /out/ /
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
EXPOSE 5775
# 6831: CompactThriftUDPPort
EXPOSE 6831
# 6832: BinaryThriftUDPPort
EXPOSE 6832
ENTRYPOINT ["/usr/bin/otelsvc"]
