# External Data Staging

This directory is the canonical local staging location for external, non-versioned CSV inputs required by pipeline runs.

Current dataset wired in `config/datasets.yaml`:

- `san_lorenzo_daily` -> `data-raw/external/data_USGS_ppt_soil.csv`

How to fetch from `jerez` (default source):

```bash
./scripts/fetch_san_lorenzo_usgs_csv.sh
```

Override source or destination when needed:

```bash
./scripts/fetch_san_lorenzo_usgs_csv.sh \
  --remote-user jaguir26 \
  --remote-host jerez.be.ucsc.edu \
  --remote-path /data/muscat_data/jaguir26/data/data_USGS_ppt_soil.csv \
  --dest data-raw/external/data_USGS_ppt_soil.csv
```

Notes:

- Files in this directory are intentionally ignored by git.
- The fetch script prints a SHA256 checksum after download for reproducibility logs.
