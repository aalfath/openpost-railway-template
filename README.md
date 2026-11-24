[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/openpost?utm_medium=integration&utm_source=button&utm_campaign=openpost)

# OpenPost on Railway

One-click Railway template for [OpenPost](https://github.com/getopenpost/openpost), the open-source social media scheduler (AGPL-3.0).

- **Version:** OpenPost **v7.42.5**, official image `ghcr.io/getopenpost/openpost:v7.42.5@sha256:f6c92cbe6a1795049ad81c7b9a646b4e163145bbc46e35e55e539b1ede16c0d6`
- **Services:** one `OpenPost` service built from this repo, with a Railway volume at `/data` (SQLite database and media).
- **Health check:** `/api/v1/health`. Restart policy: on failure.
- **Resources:** fits Railway's Free plan (0.5 GB RAM / 1 vCPU): about 95 MB idle, about 270 MB peak while it processed a 1080p video and a 3000 px image in our test.

## What the wrapper adds

`Dockerfile` pins the official image and adds `railway-start.sh`, which:

- creates the admin account on first boot from `OPENPOST_ADMIN_EMAIL` and `OPENPOST_ADMIN_PASSWORD` on a private port, before the public port opens, then keeps public sign-up closed (`OPENPOST_DISABLE_REGISTRATIONS=true`), so no stranger can register first and become instance admin;
- derives `OPENPOST_APP_URL` from the Railway domain, and trusts only Railway's proxy hops so OpenPost sees each visitor's real IP and HTTPS;
- sizes Go and ffmpeg threads and the Go memory limit from the service's cgroup limits (Railway shows the host's 32 CPUs);
- turns off maintainer diagnostics to openpo.st (set `OPENPOST_DIAGNOSTICS_ENABLED=true` to send them);
- runs OpenPost as the image's unprivileged user and exits non-zero if OpenPost stops unexpectedly, so Railway restarts it.

## Variables

| Variable | Default | Notes |
|---|---|---|
| `OPENPOST_ADMIN_EMAIL` | (you enter it) | Email of the admin account created on first boot |
| `OPENPOST_ADMIN_PASSWORD` | `${{secret(24)}}` | Generated first password of the admin; copy it from the Variables tab |
| `OPENPOST_JWT_SECRET` | `${{secret(48)}}` | Signs login sessions |
| `OPENPOST_ENCRYPTION_KEY` | `${{secret(48)}}` | Encrypts stored social account tokens; never change it |
| `OPENPOST_APP_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` | Public URL; set `https://YOUR-DOMAIN` for a custom domain |
| `PORT` | `8080` | Port OpenPost listens on |

Every other OpenPost setting (network app keys, AI, SMTP, S3) can be added as a variable, see upstream [`.env.example`](https://github.com/getopenpost/openpost/blob/v7.42.5/.env.example), or set in OpenPost under Settings, Instance, Configuration.

## After deploy

1. Copy `OPENPOST_ADMIN_PASSWORD` from the service's Variables tab.
2. Open the public URL and sign in with your admin email and that password.
3. Add the app keys of each social network under Settings, Instance, Configuration ([integration guide](https://openpo.st/docs/self-hosting/integrations)).
4. To add teammates, set `OPENPOST_DISABLE_REGISTRATIONS=false`, let them sign up, invite them to your workspace, then remove the variable again.

## Updates

Deployers get Railway's "update available" notice when this repo's `main` changes. Each version bump changes the `FROM` tag and digest in `Dockerfile` and gets an entry in [`CHANGELOG.md`](CHANGELOG.md), with breaking changes first. Read it, then apply the update in Railway; your volume and data stay.

GitHub Container Registry keeps OpenPost's old tags today; if upstream ever prunes them, an old pin would stop building, so apply updates when they come.

## Licence

OpenPost is AGPL-3.0-only, © its authors. This repo only packages the unmodified upstream image.
