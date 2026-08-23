export const SITE = {
  project: "Knot",
  projectId: "HK-UHI10-1087",
  cohort: "UHI10",
  theme: "Sustainable Liquidity & MEV Protection",
  github: "https://github.com/Hijanhv/KNOT-hook-",
  // Mintlify docs. Point NEXT_PUBLIC_DOCS_URL at the deployed docs subdomain.
  docs: process.env.NEXT_PUBLIC_DOCS_URL ?? "https://knot.mintlify.app",
  uniswapV4: "https://docs.uniswap.org/contracts/v4/overview",
} as const;

/** Filled in as each contract is deployed. Shown in the footer so the addresses are never buried. */
export const DEPLOYMENTS: { label: string; address?: string; explorer?: string }[] = [
  { label: "KnotFederation", address: process.env.NEXT_PUBLIC_FEDERATION },
  { label: "KnotHook (deep)", address: process.env.NEXT_PUBLIC_DEEP_POOL },
  { label: "KnotHook (shallow)", address: process.env.NEXT_PUBLIC_SHALLOW_POOL },
];
