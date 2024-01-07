# simple-go

## Usage

```bash
$ simple-go --help
usage: simple-go --config=CONFIG [<flags>]


Flags:
  -h, --[no-]help      Show context-sensitive help (also try --help-long and --help-man).
      --config=CONFIG  path to yaml configuration file
      --[no-]version   Show application version.
```

## Configuration

```yaml
# simple-go configuration file
#
# This file contains the configuration for the simple-go server.
# It is a yaml file with the following structure:
#
# web_listen: <listen address>
#
# log:
# log_level: <log level>
# log_no_color: <true/false>
# log_json: <true/false>
---
web_listen: :8080

log:
log_level: debug
log_no_color: false
log_json: false

```

## Endpoints

### /

- **Method**: GET
- **Content-Type**: application/json

#### Response

```json
{
  "message": "Hello World!"
}
```

## Development

### Requirements

- [Go](https://golang.org/) >= 1.21.1
- [Goreleaser](https://goreleaser.com/) >= 0.182.0

### Build

#### Using go build

```bash
$ go build -o terradmin-validate
```

#### Using goreleaser

```bash
$ goreleaser build --clean --skip=validate --snapshot
```

### Test

```bash
$ go test -v ./...
```

### Lint

```bash
$ golangci-lint run --config .golangci.yml
```

