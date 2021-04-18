FROM golang

RUN go get github.com/client9/misspell/cmd/misspell

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]