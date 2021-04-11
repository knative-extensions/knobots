FROM golang

RUN go get github.com/bronze1man/yaml2json && apt-get update && apt-get install -y jq

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]