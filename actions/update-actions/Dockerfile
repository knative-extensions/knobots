FROM golang

RUN go get github.com/bronze1man/yaml2json

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]