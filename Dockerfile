FROM golang:1.12-alpine
ADD . /go
RUN  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -a -tags netgo -ldflags '-w -extldflags "-static"'  -o app .

FROM scratch
COPY --from=0 /go/app .
ENV PORT 80
ENTRYPOINT ["./app"]