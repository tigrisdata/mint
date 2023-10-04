FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV GOROOT /usr/local/go
ENV GOPATH /usr/local/gopath
ENV PATH $GOPATH/bin:$GOROOT/bin:$PATH
ENV MINT_ROOT_DIR /mint

# install base packages
RUN apt-get --yes update; \
    apt-get install -yq --no-install-recommends --no-install-suggests \
    apt-transport-https ca-certificates gnupg wget

# install nodejs source list
RUN wget --quiet --no-check-certificate --output-document=- https://deb.nodesource.com/setup_20.x | bash -

# install needed packages
RUN apt-get --yes update; \
    apt-get install -yq --no-install-recommends --no-install-suggests \
    ant curl dirmngr dnsmasq git jq libunwind8 \
    nodejs openjdk-8-jdk openjdk-8-jdk-headless \
    patch python3 python3-pip \
    php php-curl php-xml \
    ruby ruby-dev ruby-bundler

# install go
ARG GO_VERSION="1.21.0"
ARG GO_DOWNLOAD_URL="https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz"
ARG GO_INSTALL_PATH="/usr/local"
RUN wget --quiet --no-check-certificate --output-document=- "${GO_DOWNLOAD_URL}" | tar -C "${GO_INSTALL_PATH}" -zxf -

# set python 3.10 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1

COPY . /mint

RUN cd /mint && /mint/release.sh

WORKDIR /mint

ENTRYPOINT ["/mint/entrypoint.sh"]
