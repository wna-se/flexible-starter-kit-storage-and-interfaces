# Quickstart guide to the SDA

This document contains information on how to work with the Sensitive Data Archive (SDA) from the GDI user perspective.

## Brief description of the storage and interfaces stack

The storage and interfaces software stack for the GDI-starter-kit consists of the following services:

| Component     | Description |
|---------------|------|
| broker        | RabbitMQ based message broker, [SDA-MQ](https://github.com/neicnordic/sda-mq). |
| database      | PostgreSQL database, [SDA-DB](https://github.com/neicnordic/sda-db). |
| storage       | S3 object store, demo uses Minio S3. |
| mock-oidc     | A python implementation of a mock-oidc in place of LS-AAI. |
| s3inbox       | Proxy inbox to the S3 backend store, [SDA-S3Proxy](https://github.com/neicnordic/sda-s3proxy). |
| download      | Data out solution for downloading files from the SDA, [SDA-download](https://github.com/neicnordic/sda-download). |
| SDA-pipeline     | The ingestion pipeline of the SDA, [SDA-pipeline](https://github.com/neicnordic/sda-pipeline). This comprises of the following core components: `ingest`, `verify`, `finalize` and `mapper`.|

Detailed documentation on the `sda-pipeline` can be found at: https://neicnordic.github.io/sda-pipeline/pkg/sda-pipeline/.

NeIC Sensitive Data Archive documentation can be found at: https://neic-sda.readthedocs.io/en/latest/ .

## Deployment

The storage and interfaces stack can be deployed with the use of the provided `docker-compose.yml` file by running

```shell
docker compose up -d
```

from the root of this repo. Configuration can be customized by changing the [`config/config.yml`](./config/config.yml) file.

### Adding TLS to internet facing services

Internet facing services such as `s3inbox`, `download` and `mock-oidc`, need to be secured via TLS certification. This can be most conveniently achieved by using [Let's Encrypt](https://letsencrypt.org/getting-started/) as Certificate Authority. Assuming shell access to your web host, a convenient way to set this up is through installing Certbot (or any other ACME client supported by Let's Encrypt). Detailed instructions on setting up Certbot for different systems can be found [here](https://certbot.eff.org/).

## Authentication for users (mock or AAI)

To interact with SDA services, users need to provide [JSON Web Token](https://jwt.io/) (JWT) authentication. Ultimately, tokens can be fetched by [LS-AAI](https://lifescience-ri.eu/ls-login/) upon user login to an OIDC relaying party (RP) service that is [registered with LS-AAI](https://spreg-legacy.aai.elixir-czech.org/). An example of such an RP service is the [sda-auth](https://github.com/neicnordic/sda-auth) service, which however not included in the present stack.

For the starter-kit, jw tokens can be issued by the included `mock-oidc` service and used for authentication instead. The `mock-oidc` is a simple Python implementation that mimics the basic OIDC functionality of LS-AAI. It does not require user authentication and serves a valid token through its `/token` endpoint:

```shell
token=$(curl -s -k https://<mock-oidc_domain_name>/tokens | jq -r '.[0]')
```

This token is created upon deployment. See `scripts/make_credentials.sh` for more details. Note that the API returns a list of tokens where the first element is the token of interest, and the rest are legacy tokens for [testing  `sda-download`](https://github.com/neicnordic/sda-download/blob/main/dev_utils/README.md#get-a-token).

## How to perform common user tasks

### Data encryption

The `sda-pipeline` only ingests files encrypted with the archive's `c4gh` public key. For instance, using the go implementation of the [`crypt4gh` utility](https://github.com/neicnordic/crypt4gh) a file can be encrypted simply by running:

```shell
crypt4gh encrypt -f <file-to-encrypt> -p <sda-c4gh-public-key>
```


### Uploading data

Users can upload data to the SDA by transferring them directly to the archive's `s3inbox` with an S3 client tool such as [`s3cmd`](https://s3tools.org/s3cmd):
```

```shell
s3cmd -c s3cmd.conf put <path-to-file.c4gh> s3://<username>/<target-path-to-file.c4gh>
```

where `s3cmd.conf` is a configuration file with the following content:
```ini
[default]
access_key = <USER_NAME>
secret_key = <USER_NAME>
access_token=<JW_TOKEN>
check_ssl_certificate = False
check_ssl_hostname = False
encoding = UTF-8
encrypt = False
guess_mime_type = True
host_base = <S3_INBOX_DOMAIN_NAME>
host_bucket = <S3_INBOX_DOMAIN_NAME>
human_readable_sizes = true
multipart_chunk_size_mb = 50
use_https = True
socket_timeout = 30
```

### The sda-cli tool

Instead of the tools above, users are **encouraged** to use [`sda-cli`](https://github.com/NBISweden/sda-cli), which is a tool specifically developed to perform all common SDA user-related tasks in a convenient and unified manner. It is recommended to use precompiled executables for `sda-cli` which can be found at https://github.com/NBISweden/sda-cli/releases

To start using the tool run:

```shell
./sda-cli help
```

#### Examples of common usage

- Encrypt and upload a file to the SDA in one go:

```shell
./sda-cli upload -config s3cmd.conf --encrypt-with-key <sda-c4gh-public-key> <unencrypted_file_to_upload>
```

- Encrypt and upload a whole folder recursively to a specified path, which can be different from the source, in one go:

```shell
./sda-cli upload -config s3cmd.conf --encrypt-with-key <sda-c4gh-public-key> -r <folder_1_to_upload> -targetDir <upload_folder>
```

- List all uploaded files in the user's bucket recursively:

```shell
./sda-cli list -config s3cmd.conf
```
For detailed documentation on the tool's capabilities and usage please refer [here](https://github.com/NBISweden/sda-cli#usage).

### Downloading data

Users can directly download data from the SDA via `sda-download`, for more details see the service's [api reference](https://github.com/neicnordic/sda-download/blob/main/docs/API.md) and the examples [here](https://github.com/GenomicDataInfrastructure/starter-kit-storage-and-interfaces). In short, given a valid token, `$token`,  a user can download the file with file ID, `$fileID` by issuing the following command:

```shell
curl --cacert <path-to-certificate-file> -H "Authorization: Bearer $token" https://<sda-download_DOMAIN_NAME>/files/$fileID -o <output-filename>
```

### Data access permissions

In order for a user to access a file, permission to access the dataset that the file belongs to is needed. This is granted through [REMS](https://github.com/CSCfi/rems) in the form of `GA4GH` visas. For details see [starter-kit documentation on REMS](https://github.com/GenomicDataInfrastructure/starter-kit-rems) and the links therein.



## How to perform common admin tasks

### The sda-admin tool

Within the scope of the starter-kit, it is up to the system administrator to curate incoming uploads to the Sensitive Data Archive. To ease this task, we have created the `sda-admin` tool which is a shell script that can perform all the necessary steps in order for an unencrypted file to end up properly ingested and archived by the SDA stack. The script  can be found under `scripts/` and can be used to upload and ingest files as well as assigning accession ID to archived files and linking them to a dataset.

In the background it utilizes the `sda-cli` for encrypting and uploading files and automates generating and sending broker messages between the SDA services. Detailed documentation on its usage along with examples can be retrieved upon running the command:

```shell
./sda-admin help
```

Below we provide a step-by-step example of `sda-admin` usage.

Create a test file:

```shell
dd if=/dev/random of=test_file count=1 bs=$(( 1024 * 1024 *  1 )) iflag=fullblock
```

Fetch the archive's `c4gh` public key (assuming shell access to the host machine):

```shell
docker cp ingest:/shared/c4gh.pub.pem .
```

**Encrypt and upload**

To encrypt and upload `test_file` to the s3inbox, first get a token and prepare a `s3cmd` configuration file as described in the section [Uploading data](#uploading-data) above. Then run the following:

```shell
./sda-admin --sda-config s3cmd.conf --sda-key c4gh.pub.pem upload test_file
```

One can verify that the encrypted file is uploaded in the archive's inbox by the following command:

```shell
sda-cli list --config s3cmd.conf
```

**Ingesting**

To list the filenames currently in the "inbox" queue waiting to be ingested run:

```shell
./sda-admin ingest
```

If `test_file.c4gh` is in the returned list, run:

```shell
./sda-admin ingest test_file
```
to trigger ingestion of the file.

**Adding accession IDs**

Check that the file has been ingested by listing the filenames currently in the "verified" queue waiting to have accession IDs assigned to them:

```shell
./sda-admin accession
```

If `test_file.c4gh` is in the returned list, we can proceed with accession:

```shell
./sda-admin accession MYID001 test_file
```

where `MYID001` is the `accession ID` we wish to assign to the file.

**Mapping to datasets**

Check that the file got an accession ID by listing the filenames currently in the "completed" queue waiting to be associated with a dataset ID:

```shell
./sda-admin dataset
```

Lastly, associate the file with a dataset ID:

```shell
./sda-admin dataset MYSET001 test_file
```

Note that all the above steps can be done for multiple files at a time except from assigning accession IDs which needs to be done for one file at a time.

### Monitoring the status of services

Assuming access to a terminal session in the host machine of the deployed docker compose stack, the status of all running containers can be checked as per usual with the command: `docker ps` whereas all logs from the deployed  services can be monitored in real time as per usual by the command:

```shell
docker compose -f docker-compose.yml logs -f
```

or per service as:

```shell
docker compose -f docker-compose.yml logs <container-name> -f
```

Note that when applicable periodic `healthchecks` are in place to ensure that services are running normally. All containers are configured to always restart upon failure.

### Working with RabbitMQ

As stated, we use [RabbitMQ](https://www.rabbitmq.com/) as our message broker between different services in this stack. Monitoring the status of the broker service can most conveniently be done via the web interface, which is accessible at http://localhost:15672/ (use `https` if TLS is enabled). By default, `user:password` credentials with values `test:test` are created upon deployment and can be changed by editing the `docker-compose.yml` file. There are two ways to create a password hash for RabbitMQ as described [here](https://www.rabbitmq.com/passwords.html#computing-password-hash)

Broker messages are most conveniently generated by `scripts/sda-admin`as described above. If for some reason one wants to send MQ messages manually instead, there exist step-by-step examples [here](https://github.com/neicnordic/sda-pipeline/tree/master/dev_utils#json-formatted-messages).
