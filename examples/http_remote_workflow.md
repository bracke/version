# HTTP remote workflow

Replace the URL with a real Git smart HTTP(S) remote under your control.

```sh
version clone https://example.invalid/team/project.git project
cd project
version fetch origin
version status
version push origin main
```

Normal release tests do not contact public internet hosts.
