# cicd

CI/CD infrastructure configuration.

| Directory | Contents |
|---|---|
| `web/` | HAProxy upstream config stubs for routing to CI and web services |

The HAProxy configs here define upstream backends (e.g. Drone CI) that are
included into the main HAProxy config on the reverse proxy host.
