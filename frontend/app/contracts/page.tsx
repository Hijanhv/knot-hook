"use client";

import { useReadContracts } from "wagmi";
import { CONTRACTS, CHAIN, POOL_MANAGER } from "@/lib/contracts";
import { federationAbi, FEDERATION_ADDRESS, DEEP_POOL, SHALLOW_POOL, CHAIN_ID, fmt } from "@/lib/knot";
import Shoreline from "@/components/Shoreline";

/** Every deployed address, with live reserves read from the chain beside each one. */
export default function ContractsPage() {
  const { data } = useReadContracts({
    contracts: [
      { address: FEDERATION_ADDRESS as `0x${string}`, abi: federationAbi, functionName: "reservesOf", args: [DEEP_POOL as `0x${string}`], chainId: CHAIN_ID },
      { address: FEDERATION_ADDRESS as `0x${string}`, abi: federationAbi, functionName: "reservesOf", args: [SHALLOW_POOL as `0x${string}`], chainId: CHAIN_ID },
      { address: FEDERATION_ADDRESS as `0x${string}`, abi: federationAbi, functionName: "memberCount", chainId: CHAIN_ID },
    ],
    query: { refetchInterval: 15_000 },
  });

  const dr = data?.[0]?.result as readonly bigint[] | undefined;
  const sr = data?.[1]?.result as readonly bigint[] | undefined;
  const members = data?.[2]?.result as bigint | undefined;
  const liveFor = (n: string) => (n.includes("deep") ? dr : n.includes("shallow") ? sr : undefined);

  return (
    <>
      <Shoreline flip className="-mb-1" />
      <div className="wrap py-12">
        <p className="eyebrow mb-3">Deployed contracts</p>
        <h1 className="font-display text-[clamp(2.4rem,6vw,4.5rem)] font-bold leading-[0.95] tracking-tightest">
          Live on <span className="text-ocean">{CHAIN.name}</span>
        </h1>
        <div className="mt-5 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em]">
          <span className="border border-edge px-2.5 py-1">chain {CHAIN.id}</span>
          <span className="border border-edge px-2.5 py-1">{members !== undefined ? `${members} members` : "…"}</span>
          <span className="flex items-center gap-1.5 border border-edge bg-ocean px-2.5 py-1 text-sand-light">
            <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-ocean-foam" />live
          </span>
        </div>

        <div className="mt-10 space-y-px bg-edge">
          {CONTRACTS.map((c) => {
            const r = liveFor(c.name);
            return (
              <div key={c.address} className="bg-sand-light p-6 md:p-8">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="min-w-0">
                    <h2 className="font-display text-2xl font-bold tracking-tightest">{c.name}</h2>
                    <p className="mt-1.5 max-w-xl text-[15px] leading-[1.5] text-muted">{c.role}</p>
                  </div>
                  {r && (
                    <div className="text-right">
                      <p className="eyebrow mb-1">live reserves</p>
                      <p className="tnum font-mono text-sm">{fmt(r[0], 0)} / {fmt(r[1], 0)}</p>
                    </div>
                  )}
                </div>

                <a href={`${CHAIN.explorer}/address/${c.address}`} target="_blank" rel="noopener noreferrer"
                  className="group mt-5 flex items-center justify-between gap-3 border border-edge bg-sand px-4 py-3 transition-colors hover:bg-ocean hover:text-sand-light">
                  <code className="tnum break-all font-mono text-xs md:text-sm">{c.address}</code>
                  <span className="shrink-0 font-mono text-[11px] uppercase tracking-[0.12em] opacity-60 group-hover:opacity-100">explorer ↗</span>
                </a>

                <div className="mt-4 flex flex-wrap gap-1.5">
                  {c.reads.map((fn) => (
                    <code key={fn} className="border border-line bg-sand px-2 py-1 font-mono text-[10px] text-muted">{fn}</code>
                  ))}
                </div>
              </div>
            );
          })}
        </div>

        <div className="mt-8 border border-line bg-sand p-6">
          <p className="eyebrow mb-3">Also relevant</p>
          <div className="space-y-2 text-[15px]">
            <div className="flex flex-wrap items-baseline justify-between gap-3 border-b border-line pb-2">
              <span className="text-muted">Uniswap v4 PoolManager (canonical, not ours)</span>
              <a href={`${CHAIN.explorer}/address/${POOL_MANAGER}`} target="_blank" rel="noopener noreferrer"
                className="tnum font-mono text-xs text-ocean hover:underline">{POOL_MANAGER} ↗</a>
            </div>
            <p className="text-[14px] leading-[1.5] text-muted">
              <code className="font-mono text-[13px]">KnotMath</code> has no address of its own — it is a
              library, inlined into both hooks at compile time.
            </p>
          </div>
        </div>
      </div>
    </>
  );
}
