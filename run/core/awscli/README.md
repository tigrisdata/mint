## `awscli` tests

This directory serves as the location for Mint tests using `awscli`. Top level `mint.sh` calls `run.sh` to execute tests.

## Adding new tests

New tests is added into `test.sh` as new functions.

## Running tests manually

- Set environment variables `SERVER_ENDPOINT`, `ACCESS_KEY` and `SECRET_KEY`
- Call `run.sh` with output log file and error log file. for example

```bash
export SERVER_ENDPOINT="dev-tigris-os.fly.dev"
export ACCESS_KEY="Q3AM3UQ867SPQQA43P2F"
export SECRET_KEY="zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG"
./run.sh /tmp/output.log /tmp/error.log
```
