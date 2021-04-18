FROM golang

RUN go get golang.org/x/tools/cmd/goimports

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]