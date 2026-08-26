# Knot documentation

Mintlify source. Deployed from this folder.

## Local preview

```bash
npm i -g mint
cd docs-site && mint dev
```

## Deploying

Mintlify deploys through a GitHub app, authorised in a browser — there is no CLI path for it.
One-time setup:

1. Sign in at [mintlify.com](https://mintlify.com)
2. **Add deployment** → authorise the GitHub app → select `Hijanhv/KNOT-hook-`
3. Set the content directory to `docs-site`
4. Copy the published URL into `frontend/.env.local`:
   ```
   NEXT_PUBLIC_DOCS_URL=https://<your-subdomain>.mintlify.app
   ```

After that, every push to `main` redeploys automatically. The site's nav and footer already read
`NEXT_PUBLIC_DOCS_URL`, so the Docs links go live as soon as it is set.
