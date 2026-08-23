"use client";

import { useAccount, useConnect, useDisconnect, useSwitchChain, useChainId } from "wagmi";
import { useEffect, useState } from "react";
import { CHAIN_ID } from "@/lib/knot";

const short = (a: string) => `${a.slice(0, 6)}…${a.slice(-4)}`;

export default function Connect() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending, error } = useConnect();
  const { disconnect } = useDisconnect();
  const { switchChain } = useSwitchChain();
  const chainId = useChainId();

  // Detected on the client only — reading window during SSR would throw, and rendering a
  // different tree on server and client causes a hydration mismatch.
  const [hasMetaMask, setHasMetaMask] = useState<boolean | null>(null);
  useEffect(() => {
    const eth = (globalThis as any).ethereum;
    setHasMetaMask(Boolean(eth?.isMetaMask || eth?.providers?.some((p: any) => p.isMetaMask)));
  }, []);

  // Render the neutral state until detection settles, so the button never flickers.
  if (hasMetaMask === null) {
    return <span className="btn-ghost pointer-events-none opacity-50">Wallet</span>;
  }

  if (!hasMetaMask) {
    return (
      <a
        href="https://metamask.io/download/"
        target="_blank"
        rel="noopener noreferrer"
        className="btn-ghost"
        title="Knot's demo requires MetaMask"
      >
        Install MetaMask
      </a>
    );
  }

  if (!isConnected) {
    const metaMask = connectors.find((c) => c.id === "injected") ?? connectors[0];
    return (
      <div className="flex flex-col items-end gap-1">
        <button className="btn" disabled={isPending} onClick={() => metaMask && connect({ connector: metaMask })}>
          {isPending ? "Check MetaMask…" : "Connect MetaMask"}
        </button>
        {error && <span className="max-w-[220px] text-right text-[11px] leading-tight text-clay">{error.message}</span>}
      </div>
    );
  }

  // The most common way a demo dies in front of a judge is a silent wrong-network state.
  // One obvious button beats a broken UI.
  if (chainId !== CHAIN_ID) {
    return (
      <button
        className="btn border-clay bg-clay hover:bg-clay/90"
        onClick={() => switchChain({ chainId: CHAIN_ID })}
      >
        Wrong network — switch
      </button>
    );
  }

  return (
    <button
      className="btn-ghost tnum font-mono text-xs"
      onClick={() => disconnect()}
      title="Click to disconnect"
    >
      <span className="mr-2 inline-block h-1.5 w-1.5 rounded-full bg-marine align-middle" />
      {short(address!)}
    </button>
  );
}
