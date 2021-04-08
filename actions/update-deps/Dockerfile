FROM golang

RUN go get github.com/google/ko github.com/google/licenseclassifier github.com/google/go-licenses github.com/dprotaso/modlog knative.dev/test-infra/buoy

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]