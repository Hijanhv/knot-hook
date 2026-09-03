import { ACTIVE_DEPLOYMENT } from "./deployment";

export const SITE = {
  project: "Knot",
  cohort: "UHI10",
  theme: "Reserve-aware custom accounting",
  github: "https://github.com/Hijanhv/KNOT-hook-",
  // Mintlify docs. Point NEXT_PUBLIC_DOCS_URL at the deployed docs subdomain.
  docs: process.env.NEXT_PUBLIC_DOCS_URL ?? "https://knot-38d8bd0e.mintlify.app",
  uniswapV4: "https://docs.uniswap.org/contracts/v4/overview",
} as const;

/** Shown in the footer so the canonical manifest's addresses are never buried. */
export const DEPLOYMENTS: { label: string; address?: string; explorer?: string }[] = [
  { label: "KnotFederation", address: ACTIVE_DEPLOYMENT?.contracts.federation },
  { label: "KnotHook (deep)", address: ACTIVE_DEPLOYMENT?.contracts.deep },
  { label: "KnotHook (shallow)", address: ACTIVE_DEPLOYMENT?.contracts.shallow },
  { label: "kETH", address: ACTIVE_DEPLOYMENT?.currencies.currency0 },
  { label: "kUSD", address: ACTIVE_DEPLOYMENT?.currencies.currency1 },
];
