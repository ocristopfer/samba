# Security policy

This image runs a Samba file server that holds your users' passwords and
exposes the `/shared` folder over the network. Please treat security issues
accordingly.

## Reporting a vulnerability

Do **not** open a public issue. Use GitHub's private vulnerability reporting
(the "Report a vulnerability" button on the repository's **Security** tab) and include:

- what is affected (`Dockerfile`, `entrypoint.sh`, `smb.conf`, `supervisord.conf`,
  compose file, build script);
- steps to reproduce, or a proof of concept;
- the commit the image was built from.

You should get an answer within a few days. Fixes are published on `main`;
rebuild the image to get them.

## Supported versions

Only the `main` branch receives fixes. Images built from older commits should
be rebuilt.

## Scope

In scope: anything this repository configures — for example a share reachable
without authentication, a user able to read another user's `homes` folder,
passwords leaking into logs or the process list, or unsafe permissions created
by the entrypoint.

Out of scope: vulnerabilities in Samba itself or in the Ubuntu base image —
report those upstream and rebuild the image once a fix is released.

## Deployment hardening (short version)

- **Change every example password.** `SAMBA_PASSWORDS` defaults to `samba123`, and
  the README and `docker-compose.yml` use example passwords (`alice123`, ...)
  that are public. Also update the health check, which embeds one of them.
- **Never expose ports 139/445 to the internet.** Keep the server on a private
  network or behind a VPN; only port 445 is needed by modern clients.
- Passwords are passed as environment variables and are visible to anyone with
  access to the Docker API (`docker inspect`). Restrict who can manage Docker on
  the host, and keep your compose file out of public repositories.
- Remove the `[public]` share from `smb.conf` if you don't need it.
- Rebuild the image regularly to pick up Samba and Ubuntu security updates.
