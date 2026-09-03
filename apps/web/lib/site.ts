import { ACTIVE_DEPLOYMENT } from "./deployment";

const docsUrl = process.env.NEXT_PUBLIC_DOCS_URL?.trim() || "https://knot-38d8bd0e.mintlify.app";

export const SITE = {
  project: "Knot",
  projectId: "HK-UHI10-1087",
  cohort: "UHI10",
  theme: "Reserve-aware custom accounting",
  github: "https://github.com/Hijanhv/knot-hook",
  // Treat an empty Vercel variable as unset so every public Docs link stays usable.
  docs: docsUrl,
  uniswapV4: "https://docs.uniswap.org/contracts/v4/overview",
} as const;

/** Shown in the footer so the canonical manifest's addresses are never buried. */
export const DEPLOYMENTS: { label: string; address?: string; explorer?: string }[] = [
  { label: "KnotFederation", address: ACTIVE_DEPLOYMENT?.contracts.federation },
  { label: "KnotHook (deep)", address: ACTIVE_DEPLOYMENT?.contracts.deep },
  { label: "KnotHook (shallow)", address: ACTIVE_DEPLOYMENT?.contracts.shallow },
  { label: "kETH", address: ACTIVE_DEPLOYMENT?.currencies.currency0 },
  { label: "kUSD", address: ACTIVE_DEPLOYMENT?.currencies.currency1 },
  ...(ACTIVE_DEPLOYMENT?.faucet
    ? [{ label: "KnotFaucet", address: ACTIVE_DEPLOYMENT.faucet.address }]
    : []),
];
