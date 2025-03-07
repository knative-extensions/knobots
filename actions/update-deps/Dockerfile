# Copyright 2021 The Knative Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# TODO: figure out how to template this.
FROM golang:1.24

RUN go install github.com/google/ko@latest
RUN go install github.com/google/go-licenses@latest
RUN go install github.com/dprotaso/modlog@latest
RUN go install knative.dev/toolbox/buoy@latest
RUN curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && \
    chmod 700 get_helm.sh && \
    ./get_helm.sh && \
    rm -f get_helm.sh

# install gettext package for envsubst command, which are needed in some packages
RUN apt-get update && apt-get install -y gettext-base && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh

# Disable Go' toolchain machinery to stick to the installed version of Go
ENV GOTOOLCHAIN=local

ENTRYPOINT ["/entrypoint.sh"]
