# abimo.app — domain, e-mail and website, step by step

Everything here is one evening of clicking. Order matters: domain → DNS →
e-mail → website → Supabase mail. Budget: ~US$15/year for the domain,
everything else on free tiers.

## 1. Register the domain (Cloudflare Registrar) — 10 min

1. Create an account at https://dash.cloudflare.com (any e-mail; turn on 2FA).
2. Left sidebar → **Domain Registration → Register Domains**. Search `abimo.app`.
3. Add to cart → checkout. Pay with your card (I can't do this part). Leave
   **auto-renew ON**. WHOIS privacy is automatic and free on Cloudflare.
4. Cloudflare Registrar sells at cost; `.app` is roughly US$14–20/year.
5. Registration completes in a minute. The domain appears under **Websites**
   with Cloudflare as its nameservers already — nothing to change.

Why Cloudflare: cheapest renewals, free privacy, free DNS, free e-mail
forwarding, no upsells. (Alternative if you prefer: Porkbun, same steps.)

## 2. DNS records for the website (GitHub Pages) — 5 min

Websites → abimo.app → **DNS → Records → Add record**. Six records, all with
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

## 3. E-mail on the domain (receive) — 10 min

Websites → abimo.app → **Email → Email Routing**.

1. **Get started** → it adds the MX and TXT records itself (click *Add records
   and enable*).
2. **Destination addresses → Add**: your real inbox (the one you read).
   Cloudflare sends a verification mail; click it.
3. **Routing rules → Custom addresses → Create address**, three times:
   `support@abimo.app`, `privacy@abimo.app`, `review@abimo.app` → your inbox.
   Leave *catch-all* off (spam magnet).
4. Test: send a mail from your phone to support@abimo.app; it lands in your inbox.

## 4. Replying *as* support@abimo.app (send) — 10 min, optional but recommended

Cloudflare routing is receive-only. To reply without exposing your personal
address, pick one:

**If your inbox is Gmail / Google Workspace:**
1. Google Account → Security → 2-Step Verification on → **App passwords** →
   create one named "Abimo support".
2. Gmail → Settings → Accounts → *Send mail as* → **Add another email address**.
   Name `Abimo Support`, address `support@abimo.app`, *treat as an alias* ✓.
3. SMTP `smtp.gmail.com`, port `587`, TLS, username = your Gmail address,
   password = the app password.
4. Gmail sends a confirmation to support@abimo.app → it arrives via Cloudflare
   → click it. Repeat for privacy@ if you want.
5. Add a Cloudflare DNS **TXT** `@` → `v=spf1 include:_spf.google.com include:_spf.mx.cloudflare.net ~all`
   so replies aren't marked as spam. (Cloudflare will have created an SPF
   record already; edit it to add the Google include rather than adding a second.)

**If your inbox is iCloud Mail and you pay for iCloud+:**
Settings → iCloud → iCloud Mail → **Custom Email Domain** → add `abimo.app`
→ create `support@`. Apple gives you the MX/TXT records to paste into
Cloudflare (this *replaces* Cloudflare Email Routing — use one or the other).
Send and receive both work in Mail.app.

## 5. Publish the website — 5 min + ~10 min waiting

1. Merge https://github.com/5mars/abimo-legal/pull/1 (it contains the
   `CNAME` file with `abimo.app`, the landing page, support, privacy, terms).
2. Repo → **Settings → Pages**. *Custom domain* should already read
   `abimo.app` (from the CNAME file). Click **Save** if it doesn't.
3. Wait for "DNS check successful" (1–10 min), then tick **Enforce HTTPS**.
   `.app` domains are HTTPS-only by design, so this box must be on.
4. Open https://abimo.app , https://abimo.app/privacy/ ,
   https://abimo.app/support/ and https://www.abimo.app (redirects).
5. Tell Claude "domain is live" → the in-app support e-mail and legal links
   switch to abimo.app and get committed to PR #23.

## 6. Supabase auth e-mails from your domain (needed before launch) — 20 min

Supabase's built-in mailer is for development only: it is rate-limited to a
handful of messages per hour and sends from a supabase.io address. Your
sign-up confirmation mails would stop after the first few users. Standard
fix: a transactional mail provider on your own domain.

1. https://resend.com → sign up (free tier: 3,000 mails/month, plenty).
2. **Domains → Add domain** `abimo.app` (region: US). Resend shows 3–4 DNS
   records (MX for `send`, TXT SPF, TXT DKIM `resend._domainkey`). Add each
   in Cloudflare DNS, *DNS only*. Click **Verify**.
3. **API Keys → Create** ("supabase-auth", sending access only). Copy it once.
4. Supabase dashboard → Project → **Authentication → SMTP Settings** → enable
   custom SMTP: host `smtp.resend.com`, port `465`, user `resend`, password =
   the API key, sender `noreply@abimo.app`, sender name `Abimo`.
5. Authentication → **Rate Limits** → raise "emails sent per hour" to 100+.
6. Authentication → **Email Templates** → put "Abimo" in the subject lines.
7. Test: sign up a throwaway address in the app; the confirmation arrives
   from noreply@abimo.app within seconds.

## 7. Later, when you want more than a landing page

The site is plain HTML on GitHub Pages; add pages as folders with an
`index.html`. If you outgrow that (blog, waitlist form), Cloudflare Pages or
Vercel host a static site free and read from the same repo. Don't move the
`/privacy/` and `/terms/` URLs — App Store Connect and the app link to them.
