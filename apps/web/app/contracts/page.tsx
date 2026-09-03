"use client";

import { useQuery } from "@tanstack/react-query";
import { CONTRACTS, CHAIN, POOL_MANAGER } from "@/lib/contracts";
import { federationAbi, CHAIN_ID, fmt } from "@/lib/knot";
import { chainHeadAgeSeconds, isChainHeadStale, publicClient, readChainHead } from "@/lib/rpc";
import { ACTIVE_DEPLOYMENT, DEPLOYMENT, DEPLOYMENT_IS_ACTIVE } from "@/lib/deployment";

/** Every deployed address, with live reserves read from the chain beside each one. */
export default function ContractsPage() {
  const active = ACTIVE_DEPLOYMENT;
  const chainQuery = useQuery({
    queryKey: ["knot", CHAIN_ID, "contract-state"],
    queryFn: async () => {
      if (!active) throw new Error("An active KNOT release manifest is required");
      const head = await readChainHead();
      const [deep, shallow, aggregate0, aggregate1, members] = await Promise.all([
        publicClient.readContract({
          address: active.contracts.federation,
          abi: federationAbi,
          functionName: "reservesOf",
          args: [active.contracts.deep],
          blockNumber: head.number,
        }),
        publicClient.readContract({
          address: active.contracts.federation,
          abi: federationAbi,
          functionName: "reservesOf",
          args: [active.contracts.shallow],
          blockNumber: head.number,
        }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "aggregateReserve0", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "aggregateReserve1", blockNumber: head.number }),
        publicClient.readContract({ address: active.contracts.federation, abi: federationAbi, functionName: "memberCount", blockNumber: head.number }),
      ]);
      return { deep, shallow, aggregate: [aggregate0, aggregate1] as const, members, head };
    },
    refetchInterval: 15_000,
    retry: 1,
    enabled: DEPLOYMENT_IS_ACTIVE,
  });

  const dr = chainQuery.data?.deep;
  const sr = chainQuery.data?.shallow;
  const members = chainQuery.data?.members;
  const stale = chainQuery.data ? isChainHeadStale(chainQuery.data.head) : false;
  const liveFor = (n: string) => (n.includes("deep") ? dr : n.includes("shallow") ? sr : undefined);

  return (
    <>
      <div className="wrap py-20 md:py-24">
        <p className="eyebrow mb-3">Deployment</p>
        <h1 className="font-display text-[clamp(2.25rem,5vw,3.75rem)] font-semibold leading-[1.05] tracking-tightest">
          {DEPLOYMENT_IS_ACTIVE ? "Live on" : "Release metadata for"} <span className="text-blue">{CHAIN.name}</span>
        </h1>
        <div className="mt-5 flex flex-wrap gap-2 font-mono text-[11px] uppercase tracking-[0.14em]">
          <span className="pill">chain {CHAIN.id}</span>
          <span className="pill">{members !== undefined ? `${members} members` : DEPLOYMENT_IS_ACTIVE ? "members unavailable" : "manifest unavailable"}</span>
          {active && <span className="pill text-blue-light">5 exact Sourcify matches</span>}
          <span className={`pill ${chainQuery.isSuccess && DEPLOYMENT_IS_ACTIVE ? "text-blue-light" : "text-muted"}`}>
            <span
              className={`h-1.5 w-1.5 rounded-full ${
                chainQuery.isSuccess && DEPLOYMENT_IS_ACTIVE ? "animate-pulse bg-blue" : DEPLOYMENT_IS_ACTIVE && chainQuery.isPending ? "animate-pulse bg-faint" : "bg-amber"
              }`}
            />
            {!DEPLOYMENT_IS_ACTIVE
              ? "manifest unavailable"
              : chainQuery.isSuccess
                ? `${stale ? "stale" : "live"} · block ${chainQuery.data.head.number}`
              : chainQuery.isPending
                ? "reading chain"
                : "rpc unavailable"}
          </span>
        </div>

        {!DEPLOYMENT_IS_ACTIVE && (
          <p role="status" className="mt-5 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
            {DEPLOYMENT.statusReason} No KNOT-owned address is published until its bytecode, hook flags, seeded reserves,
            quotes, and complete transaction lifecycle have been verified.
          </p>
        )}

        {DEPLOYMENT_IS_ACTIVE && chainQuery.isError && (
          <div role="alert" className="mt-5 flex flex-wrap items-center justify-between gap-3 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
            <span>Contract addresses remain on the explorer, but the RPC did not return reserve data. No cached value is shown as current.</span>
            <button type="button" className="btn-ghost shrink-0" onClick={() => void chainQuery.refetch()}>Retry reads</button>
          </div>
        )}

        {stale && chainQuery.data && (
          <p role="status" className="mt-5 border-l-2 border-amber bg-paper px-4 py-3 text-sm text-ink-soft">
            The returned chain head is {chainHeadAgeSeconds(chainQuery.data.head)} seconds old. Treat these reads as stale.
          </p>
        )}

        {chainQuery.data && (
          <dl className="mt-5 grid gap-2 font-mono text-[11px] sm:grid-cols-3">
            <div className="card p-4"><dt className="eyebrow">Deep reserves</dt><dd className="tnum mt-2">{fmt(chainQuery.data.deep[0], 0)} / {fmt(chainQuery.data.deep[1], 0)}</dd></div>
            <div className="card p-4"><dt className="eyebrow">Shallow reserves</dt><dd className="tnum mt-2">{fmt(chainQuery.data.shallow[0], 0)} / {fmt(chainQuery.data.shallow[1], 0)}</dd></div>
            <div className="card p-4"><dt className="eyebrow">Contract aggregate</dt><dd className="tnum mt-2 text-blue">{fmt(chainQuery.data.aggregate[0], 0)} / {fmt(chainQuery.data.aggregate[1], 0)}</dd></div>
          </dl>
        )}

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

                {c.poolId && (
                  <div className="mt-3 rounded-[3px] border border-line bg-paper px-4 py-3">
                    <p className="eyebrow mb-1">Pool ID</p>
                    <code className="tnum break-all font-mono text-[11px] text-ink-soft">{c.poolId}</code>
                  </div>
                )}

                <div className="mt-4 flex flex-wrap gap-1.5">
                  {c.reads.map((fn) => (
                    <code key={fn} className="rounded border border-line bg-paper px-2 py-1 font-mono text-[10px] text-muted">{fn}</code>
                  ))}
                </div>
              </div>
            );
          })}
        </div>

        {!DEPLOYMENT_IS_ACTIVE && (
          <div className="card mt-12 md:p-8">
            <p className="eyebrow mb-3">Release gate</p>
            <h2 className="opsz-text font-display text-2xl font-semibold tracking-[-0.015em] text-ink">No stale address placeholders</h2>
            <p className="mt-2 max-w-2xl text-[15px] leading-[1.55] text-muted">
              Only a release containing one federation, two flag-valid hooks, activated members, and all four verified
              Universal Router swap branches can pass the manifest validator.
            </p>
          </div>
        )}

        <div className="card mt-10">
          <p className="eyebrow mb-3">Also relevant</p>
          <div className="space-y-2 text-[15px]">
            <div className="flex flex-wrap items-baseline justify-between gap-3 border-b border-line pb-2">
              <span className="text-muted">Uniswap v4 PoolManager (canonical, not ours)</span>
              <a href={`${CHAIN.explorer}/address/${POOL_MANAGER}`} target="_blank" rel="noopener noreferrer"
                className="tnum font-mono text-xs text-blue hover:underline">{POOL_MANAGER} ↗</a>
            </div>
            {active && (
              <>
                <div className="flex flex-wrap items-baseline justify-between gap-3 border-b border-line pb-2">
                  <span className="text-muted">kETH · currency0</span>
                  <a href={`${CHAIN.explorer}/address/${active.currencies.currency0}`} target="_blank" rel="noopener noreferrer"
                    className="tnum break-all font-mono text-xs text-blue hover:underline">{active.currencies.currency0} ↗</a>
                </div>
                <div className="flex flex-wrap items-baseline justify-between gap-3 border-b border-line pb-2">
                  <span className="text-muted">kUSD · currency1</span>
                  <a href={`${CHAIN.explorer}/address/${active.currencies.currency1}`} target="_blank" rel="noopener noreferrer"
                    className="tnum break-all font-mono text-xs text-blue hover:underline">{active.currencies.currency1} ↗</a>
                </div>
              </>
            )}
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
