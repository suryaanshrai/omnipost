# API and automation

## API tokens

Settings → Account → API tokens makes a personal token (`op_...`). Send
it as `Authorization: Bearer op_...` to any endpoint. Tokens act with
your permissions, can be read-only and can expire. They can't make more
tokens, change your password or delete the account.

The OpenAPI schema is at `/swagger-ui/` on your API (when
`ENABLE_API_DOCS` is on) and in `schema.yml` in omnipost-api.

```bash
curl -H "Authorization: Bearer $OMNIPOST_TOKEN" https://api.example.com/workspaces/
```

## Webhooks

Settings → Integrations → Webhooks sends a signed JSON event to your URL
when a post is published, a post fails, or an account needs reconnecting.
Verify `X-OmniPost-Signature` (`sha256=` HMAC of `timestamp.body` with
the webhook's secret).

## MCP server

`mcp_server/` in omnipost-api lets Claude or any MCP client draft,
check, schedule and publish posts and read their numbers. Install it with
`pipx install ./mcp_server` and give it `OMNIPOST_API_URL` and
`OMNIPOST_TOKEN`; its README has the client configuration.
