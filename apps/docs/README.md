# Knot documentation

Mintlify source. Deployed from this folder.

## Local preview

```bash
npm i -g mint
cd apps/docs && mint dev
```

## Deploying

Mintlify deploys through a GitHub app, authorised in a browser. There is no CLI path for it.
One-time setup:

1. Sign in at [mintlify.com](https://mintlify.com)
2. **Add deployment** → authorise the GitHub app → select `Hijanhv/knot-hook`
3. Set the content directory to `apps/docs`
4. Copy the published URL into `apps/web/.env.local`:
   ```
   NEXT_PUBLIC_DOCS_URL=https://<your-subdomain>.mintlify.app
   ```

After that, every push to `main` redeploys automatically. The site's nav and footer already read
`NEXT_PUBLIC_DOCS_URL`, so the Docs links go live as soon as it is set.
