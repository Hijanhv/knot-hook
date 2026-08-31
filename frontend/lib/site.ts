import { DEPLOYED } from "./contracts";

export const SITE = {
  project: "Knot",
  projectId: "HK-UHI10-1087",
  cohort: "UHI10",
  theme: "Sustainable Liquidity & MEV Protection",
  github: "https://github.com/Hijanhv/KNOT-hook-",
  // Mintlify docs. Point NEXT_PUBLIC_DOCS_URL at the deployed docs subdomain.
  docs: process.env.NEXT_PUBLIC_DOCS_URL ?? "https://knot-38d8bd0e.mintlify.app",
  uniswapV4: "https://docs.uniswap.org/contracts/v4/overview",
} as const;

/** Shown in the footer so the addresses are never buried. Defaults to the live deployment. */
export const DEPLOYMENTS: { label: string; address?: string; explorer?: string }[] = [
  { label: "KnotFederation", address: process.env.NEXT_PUBLIC_FEDERATION ?? DEPLOYED.federation },
  { label: "KnotHook (deep)", address: process.env.NEXT_PUBLIC_DEEP_POOL ?? DEPLOYED.deep },
  { label: "KnotHook (shallow)", address: process.env.NEXT_PUBLIC_SHALLOW_POOL ?? DEPLOYED.shallow },
];
