# markdrayton/gokrazy-fr24feed

Run `fr24feed` on a [gokrazy](http://gokrazy.org/) appliance. It's a bit of a
hack -- the `fr24feed` binary assumes it is running under Raspbian and shells
out to `bash`, `pgrep`, and other tools that aren't present in a userspace-free
gokrazy appliance. To make things work, the `fr24feed` process runs in a
separate mount namespace under `/run/fr24feed` containing dummy versions of the
tools it calls.

## Installation

Deploy a new instance (here named `fr24`) with the
[quickstart guide](https://gokrazy.org/quickstart/index.html) then install
`gokrazy-fr24feed` as follows

```
$ gok -i fr24 add github.com/0xERR0R/blocky                  # fr24feed needs to resolve an NTP server
$ gok -i fr24  add github.com/markdrayton/gokrazy-fr24feed
```

Configure modules at `~/gokrazy/fr24/config.json`:

```
{
    "Packages": [
        "github.com/markdrayton/gokrazy-fr24feed",
        "github.com/0xERR0R/blocky"
    ],
    "PackageConfig": {
        "github.com/markdrayton/gokrazy-fr24feed": {
            "ExtraFilePaths": {
                "/fr24feed/fr24feed.ini": "fr24feed.ini"
            },
            "WaitForClock": true
        },
        "github.com/0xERR0R/blocky": {
            "ExtraFilePaths": {
                "/etc/blocky.yaml": "blocky.config.yaml"
            },
            "CommandLineFlags": [
                "--config",
                "/etc/blocky.yaml"
            ],
            "WaitForClock": true
        }
    }
}
```

Configure `fr24feed`:

```
$ cat ~/gokrazy/fr24/fr24feed.ini
receiver="dvbt"
fr24key="$yourkey"
bs="yes"
raw="yes"
mlat="no"
mlat-without-gps="no"
path="/usr/local/bin/dump1090"
```

Configure `blocky` with something like:

```
$ cat ~/gokrazy/fr24/blocky.config.yml
upstream:
  default:
    - https://security.cloudflare-dns.com/dns-query
    - https://dns.quad9.net/dns-query
ports:
  dns: 53
  http: 4000
```

Deploy:

```
$ gok -i fr24 update
```
