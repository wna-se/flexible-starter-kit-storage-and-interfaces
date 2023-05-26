# starter-kit-storage-and-interfaces

To boot strap all of this simply run:

```cmd
docker compose up -d
```

For demonstration purpose with an example dataset use the following command:

```cmd
docker compose --profile demo up -d
```

The files imported by the data loading script come from here: `https://github.com/ga4gh/htsget-refserver/tree/main/data/gcp/gatk-test-data/wgs_bam`

## Download unencrypted files directly

### Get token for downloading data

There are 3 tokens available, the first has access to a dataset at this site, the second one is empty and the third doesn't have access to this site.

```cmd
token=$(curl -s -k https://localhost:8080/tokens | jq -r '.[0]')
```

### List datasets

```cmd
curl -s -H "Authorization: Bearer $token" http://localhost:8443/metadata/datasets | jq .
```

### List files in a dataset

```cmd
datasetID=$(curl -s -H "Authorization: Bearer $token" http://localhost:8443/metadata/datasets | jq -r .'[0]')
curl -s -H "Authorization: Bearer $token" "http://localhost:8443/metadata/datasets/$datasetID/files" | jq .
```

### Download a specific file

```cmd
fileID=$(curl -s -H "Authorization: Bearer $token" "http://localhost:8443/metadata/datasets/$datasetID/files" | jq -r '.[0].fileId')
filename=$(curl -s -H "Authorization: Bearer $token" "http://localhost:8443/metadata/datasets/$datasetID/files" | jq -r '.[0].displayFileName' | cut -d '.' -f 1,2 )
curl -s -H "Authorization: Bearer $token" http://localhost:8443/files/$fileID -o "$filename"
```
