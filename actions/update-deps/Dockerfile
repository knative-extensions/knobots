FROM golang

RUN go get github.com/google/ko@v0.6.0 github.com/google/licenseclassifier github.com/google/go-licenses github.com/dprotaso/modlog knative.dev/test-infra/buoy

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]