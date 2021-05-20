# Akamai-ACME-Validator

Automatically validates pending Akamai CPS (certificate) changes by updating ACME TXT records.

[See demo here](https://deoxy.net/posts/automating-akamai-cert-validation/)

Requires the Akamai CLI to be set up with the DNS and CPS modules.

## Setup
Download the [Akamai CLI tool here](https://github.com/akamai/cli/releases/latest) and set up API keys.
```bash
mv akamai /usr/bin/
chmod +x /usr/bin/akamai
akamai install cps
akamai install dns
akamai --version
akamai cps --version
akamai dns --version
git clone https://github.com/deoxykev/akamai-acme-validator
cd akamai-acme-validator
```

## Usage
### Generate new zone files
This will generate new zone files by deleting old acme records, then appending new records that are required
```bash
./update-acme-records.sh
```
