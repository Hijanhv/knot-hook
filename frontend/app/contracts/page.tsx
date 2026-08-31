"use client";

import { useReadContracts } from "wagmi";
import { CONTRACTS, CHAIN, POOL_MANAGER } from "@/lib/contracts";
import { federationAbi, FEDERATION_ADDRESS, DEEP_POOL, SHALLOW_POOL, CHAIN_ID, fmt } from "@/lib/knot";

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
      <div className="wrap py-20 md:py-24">
        <p className="eyebrow mb-3">Deployed contracts</p>
        <h1 className="font-display text-[clamp(2.25rem,5vw,3.75rem)] font-semibold leading-[1.05] tracking-tightest">
          Live on <span className="text-blue">{CHAIN.name}</span>
        </h1>
        <div className="mt-5 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em]">
          <span className="pill">chain {CHAIN.id}</span>
          <span className="pill">{members !== undefined ? `${members} members` : "…"}</span>
          <span className="pill text-blue-light">
            <span className="h-1.5 w-1.5 animate-pulse rounded-full bg-blue" />live
          </span>
        </div>

        <div className="mt-12 space-y-5">
          {CONTRACTS.map((c) => {
            const r = liveFor(c.name);
            return (
              <div key={c.address} className="card card-hover md:p-8">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="min-w-0">
                    <h2 className="opsz-text font-display text-2xl font-semibold tracking-[-0.015em] text-ink">{c.name}</h2>
                    <p className="mt-1.5 max-w-xl text-[15px] leading-[1.5] text-muted">{c.role}</p>
                  </div>
                  {r && (
                    <div className="text-right">
                      <p className="eyebrow mb-1">live reserves</p>
                      <p className="tnum font-mono text-sm text-blue">{fmt(r[0], 0)} / {fmt(r[1], 0)}</p>
                    </div>
                  )}
                </div>

                <a href={`${CHAIN.explorer}/address/${c.address}`} target="_blank" rel="noopener noreferrer"
                  className="group mt-6 flex items-center justify-between gap-3 rounded-[3px] border border-line bg-paper px-4 py-3.5 transition-colors hover:border-blue">
                  <code className="tnum break-all font-mono text-xs text-ink-soft md:text-sm">{c.address}</code>
                  <span className="shrink-0 font-mono text-[11px] uppercase tracking-[0.12em] text-faint transition-colors group-hover:text-blue">explorer ↗</span>
                </a>

                <div className="mt-4 flex flex-wrap gap-1.5">
                  {c.reads.map((fn) => (
                    <code key={fn} className="rounded border border-line bg-paper px-2 py-1 font-mono text-[10px] text-muted">{fn}</code>
                  ))}
                </div>
              </div>
            );
          })}
        </div>

        <div className="card mt-10">
          <p className="eyebrow mb-3">Also relevant</p>
          <div className="space-y-2 text-[15px]">
            <div className="flex flex-wrap items-baseline justify-between gap-3 border-b border-line pb-2">
              <span className="text-muted">Uniswap v4 PoolManager (canonical, not ours)</span>
              <a href={`${CHAIN.explorer}/address/${POOL_MANAGER}`} target="_blank" rel="noopener noreferrer"
                className="tnum font-mono text-xs text-blue hover:underline">{POOL_MANAGER} ↗</a>
            </div>
            <p className="text-[14px] leading-[1.5] text-muted">
              <code className="font-mono text-[13px]">KnotMath</code> has no address of its own. It is a
              library, inlined into both hooks at compile time.
            </p>
          </div>
        </div>
      </div>
    </>
  );
}
