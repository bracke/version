# SSH remote workflow

Replace the host/path with a real SSH remote for your environment.

```sh
version clone git@example.invalid:team/project.git project
cd project
version fetch origin
version status
version push origin main
```

SSH trust and authentication are handled by the configured SSH client.
