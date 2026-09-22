# abimo.ca — domain, e-mail and website, step by step

The domain is registered at **GoDaddy** (done 2026-09-22). GoDaddy's own DNS
and e-mail are upsell-heavy, so the plan is: keep the registration at
GoDaddy, hand DNS to **Cloudflare's free plan**, and use Cloudflare for
e-mail forwarding. One evening of clicking; the only cost is the domain.
Order matters: nameservers → DNS → website → Apple e-mail → Supabase mail.

## 1. Put the domain on Cloudflare DNS (GoDaddy keeps the registration) — 15 min + waiting

1. Create a free account at https://dash.cloudflare.com (turn on 2FA).
2. **Add a domain** → type `abimo.ca` → choose the **Free** plan → *Continue*.
   Cloudflare scans GoDaddy's existing records (there won't be much; skip
   anything it suggests for "parking" or "domaincontrol").
3. Cloudflare shows **two nameservers**, e.g. `ada.ns.cloudflare.com` and
   `kip.ns.cloudflare.com`. Keep that tab open.
4. In GoDaddy: **My Products → abimo.ca → DNS → Nameservers → Change** →
   *I'll use my own nameservers* → paste the two Cloudflare names → Save.
   GoDaddy may ask you to confirm by e-mail or 2FA.
5. Back in Cloudflare click **Done, check nameservers**. Propagation takes
   from a few minutes to a few hours; Cloudflare e-mails you when the zone
   is *Active*. Everything below is done in Cloudflare from then on.
6. While you're in GoDaddy: turn **auto-renew ON** and confirm
   **domain privacy** is on (it is included free with `.ca` — CIRA hides
   individual registrants' details by default).

Why not stay on GoDaddy DNS: it works, but GoDaddy charges for e-mail
forwarding (bundled with Microsoft 365) and its DNS editor is slower.
Cloudflare's DNS + Email Routing are free and what most indie developers use.

## 2. DNS records for the website (GitHub Pages) — 5 min

Websites → abimo.ca → **DNS → Records → Add record**. Six records, all with
**Proxy status = DNS only** (grey cloud, not orange — GitHub needs to see the
real hostname to issue the certificate):

| Type | Name | Content |
|---|---|---|
| A | `@` | `185.199.108.153` |
| A | `@` | `185.199.109.153` |
| A | `@` | `185.199.110.153` |
| A | `@` | `185.199.111.153` |
| AAAA | `@` | `2606:50c0:8000::153` |
| AAAA | `@` | `2606:50c0:8001::153` |
| AAAA | `@` | `2606:50c0:8002::153` |
| AAAA | `@` | `2606:50c0:8003::153` |
| CNAME | `www` | `5mars.github.io` |

(GitHub's current IPs are listed at
https://docs.github.com/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site
— check they still match before adding.)

## 3. E-mail on the domain with Apple (iCloud+ Custom Email Domain) — 15 min

You use Apple's inbox, so skip Cloudflare Email Routing entirely and let
iCloud host the mailboxes. It sends *and* receives, works in Mail on every
Apple device, and is included with any paid iCloud+ plan (50 GB tier is
enough). Do this only once Cloudflare says the zone is *Active*.

1. On the Mac: **System Settings → [your name] → iCloud → iCloud Mail →
   Custom Email Domain** (or on the web: https://icloud.com/icloudplus →
   *Custom Email Domain*). Choose **Only you** (you can add family later).
2. Enter `abimo.ca`. When asked whether the domain already has e-mail
   addresses, say **No** and continue. Apple offers to sign in to your
   registrar — choose the **manual** route ("I'll set up my own records").
3. Apple shows four DNS records. Add each in **Cloudflare → DNS → Records**,
   all *DNS only* (grey cloud). They look like this (copy Apple's exact values):

   | Type | Name | Content / priority |
   |---|---|---|
   | MX | `@` | `mx01.mail.icloud.com` — priority 10 |
   | MX | `@` | `mx02.mail.icloud.com` — priority 10 |
   | TXT | `@` | `apple-domain=XXXXXXXXXXXXXXXX` (verification) |
   | TXT | `@` | `v=spf1 include:icloud.com ~all` |
   | CNAME | `sig1._domainkey` | `sig1.dkim.abimo.ca.at.icloudmailer.com` |

   If Cloudflare already created an SPF TXT for another service, **edit** it
   to `v=spf1 include:icloud.com include:amazonses.com ~all` instead of
   adding a second SPF record (two SPF records break delivery).
4. Back in Apple's dialog click **Finish setup / Verify**. It can take a few
   minutes after the records propagate.
5. **Create addresses**: `support@abimo.ca`, `privacy@abimo.ca`,
   `review@abimo.ca` (up to three per person per domain). Optionally turn on
   **Allow all incoming messages** (catch-all) so typos still reach you.
6. In **Mail → Settings → Composing** choose which address is the default
   for new mail; when replying to a support message Mail answers from the
   address it arrived on automatically.
7. Test from your phone: mail `support@abimo.ca` → it lands in Mail under
   iCloud; reply → it goes out as support@abimo.ca.

Notes
- iCloud custom domains and Cloudflare Email Routing both want the MX
  records, so use only Apple's. Resend (section 6) uses a subdomain and
  coexists.
- Apple caps custom-domain mailboxes at the same iCloud storage you already
  pay for; support volume for an indie app is nowhere near it.
- If you ever want Gmail instead, the free path is Cloudflare Email Routing
  + Gmail *Send mail as* (see the git history of this file for those steps).

## 4. (folded into 3 — Apple sends and receives)

## 5. Publish the website — 5 min + ~10 min waiting

1. Merge https://github.com/5mars/abimo-legal/pull/1 (it contains the
   `CNAME` file with `abimo.ca`, the landing page, support, privacy, terms).
2. Repo → **Settings → Pages**. *Custom domain* should already read
   `abimo.ca` (from the CNAME file). Click **Save** if it doesn't.
3. Wait for "DNS check successful" (1–10 min), then tick **Enforce HTTPS**.
   Always tick it — the app and App Store Connect link to https:// URLs.
4. Open https://abimo.ca , https://abimo.ca/privacy/ ,
   https://abimo.ca/support/ and https://www.abimo.ca (redirects).
5. Tell Claude "domain is live" → the in-app support e-mail and legal links
   switch to abimo.ca and get committed to PR #23.

## 6. Supabase auth e-mails from your domain (needed before launch) — 20 min

Supabase's built-in mailer is for development only: it is rate-limited to a
handful of messages per hour and sends from a supabase.io address. Your
sign-up confirmation mails would stop after the first few users. Standard
fix: a transactional mail provider on your own domain.

1. https://resend.com → sign up (free tier: 3,000 mails/month, plenty).
2. **Domains → Add domain** `abimo.ca` (region: US). Resend shows 3–4 DNS
   records (MX + TXT on the `send` subdomain, plus a DKIM TXT `resend._domainkey`) — they don't collide with the iCloud records. Add each
   in Cloudflare DNS, *DNS only*. Click **Verify**.
3. **API Keys → Create** ("supabase-auth", sending access only). Copy it once.
4. Supabase dashboard → Project → **Authentication → SMTP Settings** → enable
   custom SMTP: host `smtp.resend.com`, port `465`, user `resend`, password =
   the API key, sender `noreply@abimo.ca`, sender name `Abimo`.
5. Authentication → **Rate Limits** → raise "emails sent per hour" to 100+.
6. Authentication → **Email Templates** → put "Abimo" in the subject lines.
7. Test: sign up a throwaway address in the app; the confirmation arrives
   from noreply@abimo.ca within seconds.

## 7. Later, when you want more than a landing page

The site is plain HTML on GitHub Pages; add pages as folders with an
`index.html`. If you outgrow that (blog, waitlist form), Cloudflare Pages or
Vercel host a static site free and read from the same repo. Don't move the
`/privacy/` and `/terms/` URLs — App Store Connect and the app link to them.
