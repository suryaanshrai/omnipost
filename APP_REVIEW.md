# Getting platform apps approved

Bluesky, Mastodon, Discord and Telegram work with no app review. The
others publish through an OAuth app that the platform has to approve
before it works for anyone but its developers. This is the slow part of
running OmniPost for other people; start early.

**Redirect URL** for every app: `https://<your UI domain>/oauth/callback`.

| Platform | Who registers the app | Env vars (omnipost `.env`) |
|---|---|---|
| Facebook, Instagram | The deployment | `META_APP_ID`, `META_APP_SECRET` |
| Threads | The deployment | `THREADS_APP_ID`, `THREADS_APP_SECRET` |
| YouTube | The deployment | `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` |
| TikTok | The deployment | `TIKTOK_CLIENT_KEY`, `TIKTOK_CLIENT_SECRET` |
| X, LinkedIn | Each workspace (Settings → Workspace → Your own apps) | none |

Analytics scopes are opt-in (`*_EXTRA_SCOPES`, see `.env.example`): add
one only after the platform has granted it, then reconnect the channel.

## What every review asks for

- A public **privacy policy** and **terms** URL, and a **data deletion**
  route. OmniPost deletes an account and its data from Settings →
  Account (`POST /account/delete/`); link reviewers to that.
- A **screencast** of the whole flow with a test account: sign in to
  OmniPost, connect the account (show the consent screen and the scopes),
  write a post, publish it, show it live on the platform. Record one per
  platform; reviewers reject videos that skip the consent screen.
- A **test login** for your OmniPost instance, and a sentence on why each
  permission is needed (below).
- A verified business or developer identity for Meta and TikTok.

## Meta (Facebook Pages and Instagram)

1. Create a Business app at developers.facebook.com, add *Facebook Login
   for Business* and *Instagram Graph API*.
2. Permissions and what to tell the reviewer:
   - `pages_show_list`: pick which Page to publish to.
   - `pages_read_engagement`: read the Page's posts to confirm what was
     published and show likes and comments.
   - `pages_manage_posts`: publish the post the user wrote and scheduled.
   - `instagram_basic`, `instagram_content_publish`: find the Instagram
     professional account linked to the Page, and publish to it.
   - Optional for analytics: `instagram_manage_insights`, `read_insights`.
3. Complete **Business Verification**, then **App Review** for each
   permission, then switch the app to Live.

Instagram publishing needs an Instagram professional account linked to a
Facebook Page.

## Threads

A separate Meta app with the *Threads API* use case. Request
`threads_basic` and `threads_content_publish`; add
`threads_manage_insights` (and `THREADS_EXTRA_SCOPES`) for numbers. Same
review process and screencast as Meta above.

## YouTube

1. Google Cloud console: create a project, enable *YouTube Data API v3*,
   configure the OAuth consent screen (External), add the upload scope
   and, for analytics, `youtube.readonly`.
2. Upload scopes are *sensitive*: Google asks for verification of the
   consent screen and your domain, and a video of the flow. Until then
   only listed test users can connect.
3. The default quota (10,000 units a day) covers about six uploads. Ask
   for more in the console's quota form once you have users.

## TikTok

1. developers.tiktok.com: create an app, add *Login Kit* and *Content
   Posting API*, scopes `user.info.basic`, `video.upload`,
   `video.publish`.
2. Unaudited apps can only post privately (`SELF_ONLY`) and from a few
   accounts. Submit the **Content Posting API audit** with the
   screencast to post publicly.

## X

Each workspace uses its own app: developer.x.com → project → app → User
authentication settings: type *Web App*, permissions *Read and write*,
callback URL as above. Scopes requested: `tweet.read tweet.write
users.read offline.access`. The free tier's posting limit is low; the
Basic tier raises it. Metrics need read access, which every tier has.

## LinkedIn

Each workspace uses its own app: linkedin.com/developers → create an app
tied to a company Page → Products: *Sign In with LinkedIn using OpenID
Connect* and *Share on LinkedIn* (scopes `openid profile
w_member_social`). Both are granted at once. Analytics (`r_member_social`)
is a restricted permission: apply for it separately, then set
`LINKEDIN_EXTRA_SCOPES=r_member_social`.

## Checking it works

Once an app is approved, connect a real account and run the live checks
in omnipost-api (`./scripts/live_test.sh`, see its README): they read
metrics for a post you name and, with `LIVE_PUBLISH=1`, publish a test
post.

Platforms change these processes often; check each one's current docs.
