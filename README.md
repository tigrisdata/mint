# Mint

Mint is a testing framework for TigrisOS, available as a docker image. It runs correctness, benchmarking and stress tests. Following are the SDKs/tools used in correctness tests.

- awscli
- aws-sdk-go
- aws-sdk-java
- aws-sdk-php
- aws-sdk-ruby
- healthcheck
- mc
- minio-go
- minio-java
- minio-js
- minio-py
- s3cmd
- s3select
- versioning

## Running Mint

Mint is run by `docker run` command which requires Docker to be installed.

To run Mint with only the `awscli` test against TigrisOS as test target,

```sh
$ docker run -e SERVER_ENDPOINT=dev-tigris-os.fly.dev -e ACCESS_KEY=Q3AM3UQ867SPQQA43P2F \
             -e SECRET_KEY=zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG -e ENABLE_HTTPS=1 -e RUN_ON_FAIL=1 tigrisdata/mint awscli
```

To run Mint with all the tests against TigrisOS as test target,

```sh
$ docker run -e SERVER_ENDPOINT=dev-tigris-os.fly.dev -e ACCESS_KEY=Q3AM3UQ867SPQQA43P2F \
             -e SECRET_KEY=zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG -e ENABLE_HTTPS=1 -e RUN_ON_FAIL=1 tigrisdata/mint
```

After the tests are run, output is stored in `/mint/log` directory inside the container. To get these logs, use `docker cp` command. For example

```sh
docker cp <container-id>:/mint/log /tmp/logs
```

### Mint environment variables

Below environment variables are required to be passed to the docker container. Supported environment variables:

| Environment variable   | Description                                                                                                                                    | Example                                    |
| :--------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------- |
| `SERVER_ENDPOINT`      | Endpoint of TigrisOS in the format `HOST:PORT`; for virtual style `IP:PORT`                                                                    | `dev-tigris-os.fly.dev`                    |
| `ACCESS_KEY`           | Access key for `SERVER_ENDPOINT` credentials                                                                                                   | `Q3AM3UQ867SPQQA43P2F`                     |
| `SECRET_KEY`           | Secret Key for `SERVER_ENDPOINT` credentials                                                                                                   | `zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG` |
| `ENABLE_HTTPS`         | (Optional) Set `1` to indicate to use HTTPS to access `SERVER_ENDPOINT`. Defaults to `0` (HTTP)                                                | `1`                                        |
| `MINT_MODE`            | (Optional) Set mode indicating what category of tests to be run by values `core`, `full`. Defaults to `core`                                   | `full`                                     |
| `ENABLE_VIRTUAL_STYLE` | (Optional) Set `1` to indicate virtual style access . Defaults to `0` (Path style)                                                             | `1`                                        |
| `RUN_ON_FAIL`          | (Optional) Set `1` to indicate execute all tests independent of failures (currently implemented for minio-go and minio-java) . Defaults to `0` | `1`                                        |
| `SERVER_REGION`        | (Optional) Set custom region for region specific tests                                                                                         | `us-west-1`                                |

### Mint log format

All test logs are stored in `/mint/log/log.json` as multiple JSON document. Below is the JSON format for every entry in the log file.

| JSON field | Type     | Description                                                   | Example                                               |
| :--------- | :------- | :------------------------------------------------------------ | :---------------------------------------------------- |
| `name`     | _string_ | Testing tool/SDK name                                         | `"aws-sdk-php"`                                       |
| `function` | _string_ | Test function name                                            | `"getBucketLocation ( array $params = [] )"`          |
| `args`     | _object_ | (Optional) Key/Value map of arguments passed to test function | `{"Bucket":"aws-sdk-php-bucket-20341"}`               |
| `duration` | _int_    | Time taken in milliseconds to run the test                    | `384`                                                 |
| `status`   | _string_ | one of `PASS`, `FAIL` or `NA`                                 | `"PASS"`                                              |
| `alert`    | _string_ | (Optional) Alert message indicating test failure              | `"I/O error on create file"`                          |
| `message`  | _string_ | (Optional) Any log message                                    | `"validating checksum of downloaded object"`          |
| `error`    | _string_ | Detailed error message including stack trace on status `FAIL` | `"Error executing \"CompleteMultipartUpload\" on ...` |

## For Developers

### Running Mint development code

After making changes to Mint source code a local podman image can be built/run by

```sh
$ podman build -t tigrisdata/mint . -f Dockerfile
$ podman run -e SERVER_ENDPOINT=dev-tigris-os.fly.dev -e ACCESS_KEY=Q3AM3UQ867SPQQA43P2F \
             -e SECRET_KEY=zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG \
             -e ENABLE_HTTPS=1 -e MINT_MODE=full tigrisdata/mint:latest
```

### Adding tests with new tool/SDK

Below are the steps need to be followed

- Create new app directory under [build](https://github.com/tigrisdata/mint/tree/master/build) and [run/core](https://github.com/tigrisdata/mint/tree/master/run/core) directories.
- Create `install.sh` which does installation of required tool/SDK under app directory.
- Any build and install time dependencies should be added to [install-packages.list](https://github.com/tigrisdata/mint/blob/master/install-packages.list).
- Build time dependencies should be added to [remove-packages.list](https://github.com/tigrisdata/mint/blob/master/remove-packages.list) for removal to have clean Mint podman image.
- Add `run.sh` in app directory under `run/core` which execute actual tests.

#### Test data

Tests may use pre-created data set to perform various object operations on TigrisOS. Below data files are available under `/mint/data` directory.

| File name        | Size    |
| :--------------- | :------ |
| datafile-0-b     | 0B      |
| datafile-1-b     | 1B      |
| datafile-1-kB    | 1KiB    |
| datafile-10-kB   | 10KiB   |
| datafile-33-kB   | 33KiB   |
| datafile-100-kB  | 100KiB  |
| datafile-1-MB    | 1MiB    |
| datafile-1.03-MB | 1.03MiB |
| datafile-5-MB    | 5MiB    |
| datafile-6-MB    | 6MiB    |
| datafile-10-MB   | 10MiB   |
| datafile-11-MB   | 11MiB   |
| datafile-65-MB   | 65MiB   |
| datafile-129-MB  | 129MiB  |

### Updating SDKs/binaries in the image

In many cases, updating the SDKs or binaries in the image is just a matter of making a commit updating the corresponding version in this repo. However, in some cases, e.g. when `mc` needs to be updated (the latest `mc` is pulled in during each mint image build), a sort of "dummy" commit is required as an image rebuild must be triggered. Note that an empty commit does not appear to trigger the image rebuild in the Docker Hub.
