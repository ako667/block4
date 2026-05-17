import { useEffect, useState } from "react";
import {
  useAccount,
  useConnect,
  useDisconnect,
  useSwitchChain,
  useWriteContract,
  useReadContract,
  useChainId,
  useBalance,
  usePublicClient,
} from "wagmi";
import { arbitrumSepolia } from "wagmi/chains";
import { parseUnits, parseEther } from "viem";
import { formatAddress, formatEthShort, formatProposalId, formatTokenShort } from "./format";
import { useSubgraphMarkets } from "./hooks/useSubgraph";
import { MarketsPanel } from "./components/MarketsPanel";
import {
  CONTRACTS,
  marketAbi,
  erc20Abi,
  governorAbi,
  isConfigured,
  contractsReady,
  PAY_WITH_ETH,
  GOVERNOR_PROPOSAL_ID,
  PROPOSAL_STATE_LABELS,
  DEFAULT_CHAIN,
} from "./config";
import { anvil, baseSepolia, sepolia } from "./chains";

const SUPPORTED_CHAIN_IDS = [sepolia.id, baseSepolia.id, anvil.id, arbitrumSepolia.id] as const;

function preferredChainId(): number {
  switch (DEFAULT_CHAIN) {
    case "anvil":
      return anvil.id;
    case "base-sepolia":
    case "basesepolia":
      return baseSepolia.id;
    case "sepolia":
    default:
      return sepolia.id;
  }
}

const PREFERRED_CHAIN_ID = preferredChainId();

function friendlyError(err: unknown): string {
  const msg = err instanceof Error ? err.message : String(err);
  if (msg.includes("User rejected")) return "Transaction cancelled in wallet.";
  if (msg.includes("insufficient funds")) return "Insufficient balance for gas or tokens.";
  if (msg.toLowerCase().includes("network")) return "Network error — check RPC connection.";
  return msg.slice(0, 180);
}

export default function App() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending: connecting } = useConnect();
  const { disconnect } = useDisconnect();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const [amount, setAmount] = useState("0.01");
  const [error, setError] = useState<string | null>(null);
  const { markets, loading: subgraphLoading, refreshing, refresh } = useSubgraphMarkets();
  const publicClient = usePublicClient();

  const usdcOk = isConfigured(CONTRACTS.usdc);
  const marketOk = isConfigured(CONTRACTS.sampleMarket);

  const { data: ethBal } = useBalance({ address, query: { enabled: !!address } });

  const { data: usdcBal, refetch: refetchUsdc } = useReadContract({
    address: CONTRACTS.usdc,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address && usdcOk && !PAY_WITH_ETH },
  });

  const { data: votes, refetch: refetchVotes } = useReadContract({
    address: CONTRACTS.pmt,
    abi: erc20Abi,
    functionName: "getVotes",
    args: address ? [address] : undefined,
    query: { enabled: !!address && isConfigured(CONTRACTS.pmt) },
  });

  const { data: pmtBal } = useReadContract({
    address: CONTRACTS.pmt,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: { enabled: !!address && isConfigured(CONTRACTS.pmt) },
  });

  const proposalId = GOVERNOR_PROPOSAL_ID;
  const hasProposal = proposalId > 0n;

  const { data: proposalState, refetch: refetchProposal } = useReadContract({
    address: CONTRACTS.governor,
    abi: governorAbi,
    functionName: "state",
    args: hasProposal ? [proposalId] : undefined,
    query: { enabled: hasProposal && isConfigured(CONTRACTS.governor) },
  });

  const proposalActive = proposalState === 1;
  const hasVotingPower = votes != null && (votes as bigint) > 0n;
  const canVote =
    hasProposal && proposalActive && hasVotingPower && isConfigured(CONTRACTS.governor);

  const { writeContractAsync, isPending } = useWriteContract();

  const wrongChain = isConnected && !SUPPORTED_CHAIN_IDS.includes(chainId as (typeof SUPPORTED_CHAIN_IDS)[number]);
  const onAnvil = chainId === anvil.id;

  // After connect (or on reload), ask MetaMask to switch to VITE_DEFAULT_CHAIN (default: Sepolia)
  useEffect(() => {
    if (!isConnected || chainId === PREFERRED_CHAIN_ID) return;
    try {
      switchChain({ chainId: PREFERRED_CHAIN_ID });
    } catch {
      /* user rejected switch in MetaMask */
    }
  }, [isConnected, chainId, switchChain]);

  async function mintTestUsdc() {
    setError(null);
    if (!address) return;
    try {
      await writeContractAsync({
        address: CONTRACTS.usdc,
        abi: erc20Abi,
        functionName: "mint",
        args: [address, parseUnits("10000", 6)],
      });
      await refetchUsdc();
    } catch (e) {
      setError(friendlyError(e));
    }
  }

  async function buyYes() {
    setError(null);
    try {
      if (!marketOk || !usdcOk) {
        throw new Error(
          "Contract addresses missing. Run: ./scripts/deploy-anvil.sh",
        );
      }

      if (PAY_WITH_ETH) {
        const value = parseEther(amount);
        await writeContractAsync({
          address: CONTRACTS.sampleMarket,
          abi: marketAbi,
          functionName: "buyOutcomeWithEth",
          args: [0, 1n],
          value,
        });
      } else {
        const amt = parseUnits(amount, 6);
        const approveHash = await writeContractAsync({
          address: CONTRACTS.usdc,
          abi: erc20Abi,
          functionName: "approve",
          args: [CONTRACTS.sampleMarket, amt],
        });
        if (publicClient) {
          await publicClient.waitForTransactionReceipt({ hash: approveHash });
        }
        await writeContractAsync({
          address: CONTRACTS.sampleMarket,
          abi: marketAbi,
          functionName: "buyOutcome",
          args: [0, amt, 0n],
          gas: 600_000n,
        });
        await refetchUsdc();
        refresh();
      }
    } catch (e) {
      setError(friendlyError(e));
    }
  }

  async function delegatePmt() {
    setError(null);
    if (!address) return;
    try {
      await writeContractAsync({
        address: CONTRACTS.pmt,
        abi: erc20Abi,
        functionName: "delegate",
        args: [address],
      });
      await refetchVotes();
    } catch (e) {
      setError(friendlyError(e));
    }
  }

  async function castVote() {
    setError(null);
    try {
      if (!isConfigured(CONTRACTS.governor)) {
        throw new Error("Set VITE_GOVERNOR in frontend/.env after deploy.");
      }
      if (!hasProposal) {
        throw new Error("No demo proposal. Re-run ./scripts/deploy-anvil.sh");
      }
      if (!hasVotingPower) {
        throw new Error("Delegate PMT voting power first (button above).");
      }
      if (!proposalActive) {
        const label =
          proposalState != null
            ? PROPOSAL_STATE_LABELS[Number(proposalState)] ?? String(proposalState)
            : "unknown";
        throw new Error(`Proposal is not Active (state: ${label}).`);
      }
      await writeContractAsync({
        address: CONTRACTS.governor,
        abi: governorAbi,
        functionName: "castVote",
        args: [proposalId, 1],
      });
      await refetchProposal();
    } catch (e) {
      setError(friendlyError(e));
    }
  }

  return (
    <div className="app">
      <header>
        <h1>On-Chain Prediction Market</h1>
        <p>Option D — CPMM binary markets with DAO governance</p>
      </header>

      {!isConnected ? (
        <button
          disabled={connecting}
          onClick={() => connect({ connector: connectors[0] })}
        >
          Connect MetaMask
        </button>
      ) : (
        <button onClick={() => disconnect()}>Disconnect {address?.slice(0, 6)}…</button>
      )}

      {isConnected && chainId === sepolia.id && (
        <p className="hint">
          Network: <strong>Sepolia</strong> (Ethereum testnet). Deploy with{" "}
          <code>./scripts/deploy-ethereum-sepolia.sh</code>, then Goldsky + subgraph for Markets
          below.
        </p>
      )}

      {isConnected && chainId === baseSepolia.id && (
        <p className="hint">
          Network: <strong>Base Sepolia</strong> — correct chain for testnet deploy and subgraph.
        </p>
      )}

      {!contractsReady && (
        <div className="banner warn">
          <strong>Contracts not configured.</strong> Start Anvil, then run:
          <pre>cd prediction-market{"\n"}./scripts/deploy-anvil.sh</pre>
          Restart <code>npm run dev</code> after <code>frontend/.env</code> is created.
        </div>
      )}

      {wrongChain && (
        <div className="banner warn">
          Wrong network. Switch to <strong>Sepolia</strong>, <strong>Base Sepolia</strong>, or{" "}
          <strong>Anvil</strong>.
          <button type="button" onClick={() => switchChain({ chainId: sepolia.id })}>
            Sepolia
          </button>
          <button type="button" onClick={() => switchChain({ chainId: baseSepolia.id })}>
            Base Sepolia
          </button>
          <button type="button" onClick={() => switchChain({ chainId: anvil.id })}>
            Anvil
          </button>
        </div>
      )}

      {error && <div className="banner error">{error}</div>}

      <section>
        <h2>Wallet & governance</h2>
        <ul className="stat-list">
          <li>
            <span className="stat-label">{PAY_WITH_ETH ? "ETH balance" : "USDC balance"}</span>
            <span
              className="stat-value"
              title={
                PAY_WITH_ETH && ethBal != null
                  ? `${ethBal.value} wei`
                  : usdcBal != null
                    ? String(usdcBal)
                    : undefined
              }
            >
              {PAY_WITH_ETH
                ? ethBal != null
                  ? formatEthShort(ethBal.value)
                  : "—"
                : usdcBal != null
                  ? formatTokenShort(usdcBal as bigint, 6, "USDC")
                  : "—"}
            </span>
          </li>
          <li>
            <span className="stat-label">PMT balance</span>
            <span className="stat-value" title={pmtBal != null ? String(pmtBal) : undefined}>
              {pmtBal != null ? formatTokenShort(pmtBal as bigint, 18, "PMT") : "—"}
            </span>
          </li>
          <li>
            <span className="stat-label">Voting power</span>
            <span className="stat-value" title={votes != null ? String(votes) : undefined}>
              {votes != null ? formatTokenShort(votes as bigint, 18, "PMT") : "—"}
            </span>
          </li>
          {hasProposal && (
            <li>
              <span className="stat-label">Proposal</span>
              <span className="stat-value" title={proposalId.toString()}>
                #{formatProposalId(proposalId)} ·{" "}
                {proposalState != null
                  ? PROPOSAL_STATE_LABELS[Number(proposalState)] ?? proposalState
                  : "—"}
              </span>
            </li>
          )}
        </ul>
        {isConnected && isConfigured(CONTRACTS.pmt) && !hasVotingPower && pmtBal != null && (pmtBal as bigint) > 0n && (
          <button disabled={isPending} onClick={delegatePmt}>
            Delegate PMT (enable voting)
          </button>
        )}
        {onAnvil && usdcOk && isConnected && !PAY_WITH_ETH && (
          <button disabled={isPending} onClick={mintTestUsdc}>
            Mint 10,000 test USDC
          </button>
        )}
      </section>

      <section>
        <h2>Trade (on-chain)</h2>
        {marketOk && (
          <p className="hint">
            Market:{" "}
            <code title={CONTRACTS.sampleMarket}>{formatAddress(CONTRACTS.sampleMarket)}</code>
            {PAY_WITH_ETH && " · payment: native ETH"}
          </p>
        )}
        <label>
          {PAY_WITH_ETH ? "ETH amount" : "USDC amount"}
          <input value={amount} onChange={(e) => setAmount(e.target.value)} />
        </label>
        <button
          disabled={!isConnected || wrongChain || isPending || !contractsReady}
          onClick={buyYes}
        >
          Buy YES shares {PAY_WITH_ETH ? "(pay ETH)" : ""}
        </button>
        <button
          className="btn-block"
          disabled={!isConnected || wrongChain || isPending || !canVote}
          onClick={castVote}
          title={hasProposal ? proposalId.toString() : undefined}
        >
          Vote FOR proposal #{hasProposal ? formatProposalId(proposalId) : "—"}
        </button>
      </section>

      <MarketsPanel
        markets={markets}
        loading={subgraphLoading}
        onRefresh={refresh}
        refreshing={refreshing}
      />
    </div>
  );
}
