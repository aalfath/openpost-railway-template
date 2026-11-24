# Deploy and Host OpenPost on Railway

OpenPost is an open-source social media scheduler, an alternative to Buffer. You write posts, adapt them for each network, schedule them on a calendar or queue, and track results. It also has a media library, image and video editors, a meme maker, an inbox and workflows. It is licensed AGPL-3.0.

## About Hosting OpenPost

This template runs the official OpenPost v7.42.5 image as one Railway service, built from a public GitHub repo that pins the image by version and digest. OpenPost keeps its SQLite database and uploaded media on a Railway volume at `/data`, so posts, accounts and files survive redeploys and restarts. On first boot the start script creates your admin account from the email you enter and a generated password, then turns off public sign-up, so nobody else can claim the instance. Login and encryption keys are generated for you. To publish, you add your own app keys for each social network in OpenPost's instance settings.

## Common Use Cases

* Schedule posts to X, LinkedIn, Bluesky, Mastodon, Threads, Instagram and other networks from one calendar
* Run a shared content queue for a small team or a few client brands
* Keep a media library of images, videos and brand assets and reuse them across posts

## Dependencies for OpenPost Hosting

* One OpenPost service (the official image, wrapped by `aalfath/openpost-railway-template`)
* One Railway volume at `/data` for the SQLite database and media

### Deployment Dependencies

* OpenPost: https://github.com/getopenpost/openpost (release v7.42.5)
* Self-hosting docs: https://openpo.st/docs/self-hosting/
* Integration setup for each network: https://openpo.st/docs/self-hosting/integrations
* Template repo: https://github.com/aalfath/openpost-railway-template

### Implementation Details

**What you enter:** only `OPENPOST_ADMIN_EMAIL`, the email you sign in with. `OPENPOST_ADMIN_PASSWORD` (24 characters), `OPENPOST_JWT_SECRET` and `OPENPOST_ENCRYPTION_KEY` are generated. The public URL comes from the Railway domain.

**After deploy:**

1. Open the OpenPost service's Variables tab and copy `OPENPOST_ADMIN_PASSWORD`.
2. Open the public URL and sign in with your admin email and that password. Change the password in your account settings if you like. Changing the variable later doesn't change the password.
3. Go to Settings, Instance, Configuration and add the app keys of each network you want to post to. The callback URL for each network is shown there and in the integration docs. Bluesky, Mastodon, Discord and Telegram need no developer app approval.
4. Sign-up is closed after your admin account is created. To add teammates, set `OPENPOST_DISABLE_REGISTRATIONS=false` on the OpenPost service, let them sign up, invite them to your workspace, then remove the variable to close sign-up again.

**Good to know:**

* Keep `OPENPOST_ENCRYPTION_KEY` unchanged: it encrypts the stored tokens of your social accounts.
* With a custom domain, set `OPENPOST_APP_URL` to `https://YOUR-DOMAIN`, or OAuth callbacks will fail.
* Optional features are off until you add their keys as variables or in instance settings: AI writing (`OPENPOST_AI_API_KEY`, OpenRouter or any OpenAI-compatible API through `OPENPOST_AI_BASE_URL`), email (SMTP), stock photos and S3 storage. See the upstream `.env.example`.
* Maintainer diagnostics to openpo.st are off. Set `OPENPOST_DIAGNOSTICS_ENABLED=true` to send them.
* Resources: it fits Railway's Free plan (0.5 GB RAM, 1 vCPU). On our 0.5 GB test, it idled at about 95 MB and peaked at about 270 MB while it processed a 1080p video and a 3000 px image. Keep one replica, because SQLite and media live on one volume.
* Updates: the template builds from its GitHub repo. When we bump the pinned version, Railway shows you an update notice; read `CHANGELOG.md` in the repo, then apply it. Your volume and data stay.

## Why Deploy OpenPost on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying OpenPost on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
