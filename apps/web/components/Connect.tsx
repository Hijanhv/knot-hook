"use client";

import { useAccount, useConnect, useDisconnect, useSwitchChain, useChainId, useConnectors } from "wagmi";
import { useMemo } from "react";
import { CHAIN_ID } from "@/lib/knot";

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

/** MetaMask's EIP-6963 identifier. Every wallet publishes a unique one. */
const METAMASK_RDNS = "io.metamask";

export default function Connect() {
  const { address, isConnected, connector } = useAccount();
  const { connect, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const chainId = useChainId();

  // Connectors discovered via EIP-6963. Each announces an RDNS, so MetaMask is selected by
  // identity rather than by whichever extension happened to claim window.ethereum. Matching
  // on id first and falling back to the announced name covers older MetaMask builds that
  // predate a stable RDNS.
  const connectors = useConnectors();
  const metaMask = useMemo(
    () =>
      connectors.find((c) => c.id === METAMASK_RDNS) ??
      connectors.find((c) => c.name.toLowerCase() === "metamask") ??
      connectors.find((c) => c.name.toLowerCase().includes("metamask")),
    [connectors]
  );

  // Discovery is async and client-only; render a stable placeholder until it settles so the
  // button never flashes "Install MetaMask" at someone who has it.
  if (connectors.length === 0 && !isConnected) {
    return <span className="btn-ghost pointer-events-none opacity-50">Wallet</span>;
  }

  if (!metaMask && !isConnected) {
    return (
      <a href="https://metamask.io/download/" target="_blank" rel="noopener noreferrer" className="btn-ghost"
        title="This demo connects through MetaMask specifically">
        Install MetaMask
      </a>
    );
  }

  if (!isConnected) {
    return (
      <div className="flex flex-col items-end gap-1">
        <button className="btn" disabled={isPending} onClick={() => metaMask && connect({ connector: metaMask })}>
          {isPending ? "Check MetaMask…" : "Connect MetaMask"}
        </button>
        {error && <span className="max-w-[220px] text-right text-[11px] leading-tight text-amber">{error.message}</span>}
      </div>
    );
  }

  if (chainId !== CHAIN_ID) {
    return (
      <button className="btn bg-amber hover:bg-amber-light" onClick={() => switchChain({ chainId: CHAIN_ID })}>
        Wrong network · switch
      </button>
    );
  }

  return (
    <button className="btn-ghost tnum font-mono text-xs" onClick={() => disconnect()}
      title={`Connected via ${connector?.name ?? "wallet"}. Click to disconnect`}>
      <span className="mr-2 inline-block h-1.5 w-1.5 rounded-full bg-blue align-middle" />
      {short(address!)}
    </button>
  );
}
