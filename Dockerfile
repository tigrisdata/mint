FROM ubuntu:22.04

ENV DEBIAN_FRONTEND noninteractive
ENV LANG C.UTF-8
ENV GOROOT /usr/local/go
ENV GOPATH /usr/local/gopath
ENV PATH $GOPATH/bin:$GOROOT/bin:$PATH
ENV MINT_ROOT_DIR /mint

RUN apt-get --yes update && \
    apt-get install -yq --no-install-recommends --no-install-suggests wget jq curl git dnsmasq patch python3 python3-pip

COPY . /mint

RUN cd /mint && /mint/release.sh

WORKDIR /mint

ENTRYPOINT ["/mint/entrypoint.sh"]
