---
title: Solana Client SDK Patterns (Next.js + Node/TS)
description: How to pick and wire a Solana JS/TS client in 2026 — @solana/kit vs web3.js v1/v3 vs gill, Anchor vs Codama clients, wallet-adapter in Next.js, versioned tx, commitment, simulate-before-send
applies_to: [solana]
sources:
  - "Anza/kit repo - https://github.com/anza-xyz/kit (verified 2026-08-25)"
  - "Solana docs: Migrating to Kit - https://solana.com/docs/frontend/web3-compat (verified 2026-08-25)"
  - "Solana docs: JS/TS SDK - https://solana.com/docs/clients/official/javascript (verified 2026-08-25)"
  - "gill (gillsdk) - https://github.com/gillsdk/gill (verified 2026-08-25)"
  - "Codama - https://github.com/codama-idl/codama (verified 2026-08-25)"
  - "Solana docs: Codama clients - https://solana.com/docs/programs/codama/clients (verified 2026-08-25)"
  - "create-solana-dapp - https://github.com/solana-developers/create-solana-dapp (verified 2026-08-25)"
  - "Helius: Commitment levels - https://www.helius.dev/blog/solana-commitment-levels (verified 2026-08-25)"
last_verified: 2026-08-25
---

# Solana Client SDK Patterns

## START HERE for a new build

1. **Scaffold, don't hand-roll.** `npx create-solana-dapp@latest` — pick the Next.js template with an Anchor program preset. Ships wallet-adapter wired up, autoConnect, and a working Connection/RPC provider already SSR-safe. Reuse this over building the provider tree from scratch.
2. **Client SDK: `@solana/kit`.** It *is* web3.js 2.0 (renamed). web3.js v1 is maintenance-only — new code should not start there. (re-verify near ship date: check `npm view @solana/web3.js versions` and `npm view @solana/kit version` for the latest patch.)
3. **Program client: Codama-generated, or `gill` if you want a batteries-included layer on top of kit.** If your program is Anchor-based, generate the IDL, then generate a Kit-native TS client with Codama instead of relying on `@coral-xyz/anchor`'s legacy client.
4. **Always simulate before you send.** No exceptions for anything that moves funds or calls an unaudited program.

Minimal send+confirm skeleton (see full snippet below) — this is the shape every transaction path in the app should follow: build → simulate → sign → send-and-confirm at `confirmed`.

## SDK decision table

| SDK | Status (2026) | When to use | Notes |
|---|---|---|---|
| `@solana/kit` (was web3.js 2.x) | **Active, recommended** | All new Next.js/Node apps | Modular, tree-shakable, functional (no classes), typed addresses/signers, faster tx confirmation path, smaller bundles. Package: `@solana/kit`. |
| `@solana/web3.js` v1.x | Maintenance mode | Only when integrating with a legacy codebase/dep that hasn't migrated | Do not start new projects here. Class-based `Connection`/`PublicKey`/`Transaction` API. |
| `@solana/web3.js` v3 | Compat bridge | Large existing v1 codebase, migrating incrementally | Rebuilds the old class API on top of `@solana/kit` internals — lets you swap the import and get Kit's engine without a full rewrite. Not for greenfield. |
| `gill` (gillsdk/gill) | Active, community | You want Kit's primitives *plus* pre-built helpers (SPL Token/Token-2022, Memo, Compute Budget, Metaplex Token Metadata) in one import, less boilerplate | Built directly on `@solana/kit`, fully tree-shakable, same underlying types — safe to mix with raw kit calls. Good default for app code; drop to raw `@solana/kit` for anything gill doesn't wrap. |

Rule of thumb: **kit or gill, never new v1 code.** If a tutorial/example shows `new Connection(...)`, `Transaction.from(...)`, or `Keypair.generate()` from `@solana/web3.js`, treat it as v1 legacy and translate to kit idioms (`createSolanaRpc`, `generateKeyPairSigner`, address as a branded string).

## Anchor TS client vs Codama-generated client

| | Anchor's built-in TS client (`@coral-xyz/anchor` `Program`) | Codama-generated client |
|---|---|---|
| Base library | web3.js v1 idioms internally | Generates against `@solana/kit` types |
| Setup | `new Program(idl, provider)`, call `program.methods.foo(...).accounts({...}).rpc()` | Import generated `getFooInstruction(...)`, compose with kit's `pipe`/transaction-message builders |
| Type safety | Decent, from IDL | Strong — codegen produces exact typed instruction builders + account decoders per program |
| Fit with this stack | Works, but you're mixing v1-flavored client with a kit-based app (extra glue/adapters) | Native fit if the rest of the app is on kit/gill — no v1<->kit bridging |
| Maturity | Long-established, ubiquitous in tutorials | Newer; **Codama's Anchor-IDL support is actively evolving** — pin versions, check CHANGELOG before upgrading (re-verify) |

Decision: **default to Codama-generated Kit clients** for any Anchor program you own (`anchor build` → IDL → `codama` config → generate). Fall back to the Anchor TS client only if a dependency ships one and generating your own isn't worth the time in your 6-12h window. Note the Anchor repo itself moved from `coral-xyz/anchor` to `solana-foundation/anchor` — update import/registry references accordingly (re-verify current org).

```bash
# Reuse-first: generate a Kit-native client from an Anchor IDL with Codama
npm i -D @codama/cli @codama/nodes-from-anchor
npx codama run js   # per codama.config.json — see solana.com/docs/programs/codama/clients
```

## wallet-adapter in Next.js — SSR gotchas

`@solana/wallet-adapter-react` + `@solana/wallet-adapter-react-ui` touch `window`/wallet extensions at import/mount time. Next.js SSR/RSC will break unless you isolate them client-side.

**Do:**
- Put `ConnectionProvider` / `WalletProvider` / `WalletModalProvider` inside a client component (`'use client'`) that is itself dynamically imported with `{ ssr: false }`:
  ```tsx
  // app/providers.tsx
  'use client';
  const SolanaProviders = dynamic(() => import('./solana-providers'), { ssr: false });
  ```
- Import `@solana/wallet-adapter-react-ui/styles.css` once, at the same client boundary.
- Set `autoConnect` on `WalletProvider` — pairs with `localStorage`-persisted last-wallet so returning users don't re-click connect every load. Don't force-autoConnect on first visit (bad UX / silent popup blocks).
- Memoize the `endpoint` and `wallets` array (`useMemo`) — recreating the wallets array every render re-triggers adapter init.
- Wrap wallet-dependent UI (`WalletMultiButton`, balance displays, send buttons) behind the same `ssr:false` boundary or guard with a `mounted` state flag to avoid hydration mismatch (server renders "no wallet", client renders "connected" → React hydration error).

**Don't:**
- Don't call `useWallet()`/`useConnection()` in a Server Component or at module scope — client-hook only.
- Don't instantiate a kit `Rpc` object in a Server Component and pass it as a prop to a Client Component — kit RPC objects aren't serializable across the RSC boundary; create the RPC client-side (or use a route handler for server-side reads).

## Versioned transactions

- Always build **v0 transactions** (`createTransactionMessage({ version: 0 })` in kit) to get Address Lookup Table (ALT) support — legacy (`version: 'legacy'`) only if a target program/wallet still can't parse v0 (rare in 2026).
- Use ALTs once an instruction set pushes you near the 1232-byte tx size limit (common with multi-hop swaps, batched CPI-heavy instructions) — resolve addresses through the lookup table instead of inlining every account.
- Kit's transaction-message pipe is the same for versioned vs legacy; the only diff is the `version` field and (optionally) `compressTransactionMessageUsingAddressLookupTables`.

## Commitment levels — pick per call site

| Level | Meaning | Use for |
|---|---|---|
| `processed` | Seen in a block, may be on a minority fork | Live UI feedback only (optimistic "tx landed" spinner) — never gate money-moving logic on it |
| `confirmed` | Voted on by supermajority (66%+) stake | **Default for almost everything**: send-and-confirm, reading account state after a user action, UX "success" state |
| `finalized` | Rooted, effectively irreversible | Off-chain settlement/ledger writes, anything where a fork-reorg would corrupt external state (e.g. crediting a DB balance, releasing custody) |

Rule: confirm sends at `confirmed`; re-check at `finalized` before writing irreversible off-chain side effects (payouts, DB debits tied to real money).

## ALWAYS simulate before send — checklist

- [ ] Call `rpc.simulateTransaction(signedTx, { commitment: 'confirmed', sigVerify: false, replaceRecentBlockhash: true })` (kit) before every `sendTransaction`, in prod code paths, not just tests.
- [ ] Check `simulation.value.err === null` — surface the decoded program error to the user/log instead of sending blind.
- [ ] Use simulation's `unitsConsumed` to right-size `ComputeBudgetProgram.setComputeUnitLimit` (don't hardcode 200k — either simulate-and-set or accept default with margin).
- [ ] For wallet-adapter flows where the wallet itself signs (user can't be simulated against ahead of their own signature), simulate with a throwaway/fee-payer stand-in or rely on `sendTransaction`'s built-in preflight (`skipPreflight: false` — keep it `false` unless you have a specific reason, e.g. re-sending an already-simulated/known-good tx).
- [ ] On `simulateTransaction` failure, do not silently retry with `skipPreflight: true` — that's how broken/malicious instructions land on-chain.

## Minimal send + confirm (Node/TS, `@solana/kit`)

```ts
import {
  createSolanaRpc,
  createSolanaRpcSubscriptions,
  createTransactionMessage,
  pipe,
  setTransactionMessageFeePayerSigner,
  setTransactionMessageLifetimeUsingBlockhash,
  appendTransactionMessageInstructions,
  signTransactionMessageWithSigners,
  sendAndConfirmTransactionFactory,
  getSignatureFromTransaction,
} from '@solana/kit';
import { getTransferSolInstruction } from '@solana-program/system';

const rpc = createSolanaRpc('https://api.devnet.solana.com');
const rpcSubscriptions = createSolanaRpcSubscriptions('wss://api.devnet.solana.com');
const sendAndConfirm = sendAndConfirmTransactionFactory({ rpc, rpcSubscriptions });

const { value: latestBlockhash } = await rpc.getLatestBlockhash().send();

const message = pipe(
  createTransactionMessage({ version: 0 }),
  m => setTransactionMessageFeePayerSigner(payerSigner, m),
  m => setTransactionMessageLifetimeUsingBlockhash(latestBlockhash, m),
  m => appendTransactionMessageInstructions(
    [getTransferSolInstruction({ source: payerSigner, destination: destAddress, amount: 1_000_000n })],
    m,
  ),
);

const signedTx = await signTransactionMessageWithSigners(message);

// ALWAYS simulate first
const sim = await rpc.simulateTransaction(signedTx, { commitment: 'confirmed' }).send();
if (sim.value.err) throw new Error(`simulation failed: ${JSON.stringify(sim.value.err)}`);

await sendAndConfirm(signedTx, { commitment: 'confirmed' });
console.log('sig:', getSignatureFromTransaction(signedTx));
```

`payerSigner` comes from `generateKeyPairSigner()` (Node/backend) or a wallet-adapter-bridged `TransactionSigner` on the client (gill and kit both ship adapter-to-kit-signer helpers — don't write your own signer shim).

## Do / Don't

| Do | Don't |
|---|---|
| Scaffold with `create-solana-dapp` before writing provider boilerplate | Hand-roll a wallet provider tree from a blog post |
| `@solana/kit` or `gill` for all new client code | Start a new project on `@solana/web3.js` v1 |
| Codama-generate program clients from IDL | Hand-write instruction serialization |
| Simulate every send in prod code, not just CI | Ship with `skipPreflight: true` as default |
| `confirmed` for UX, `finalized` before irreversible off-chain writes | Gate money-moving logic on `processed` |
| Isolate wallet-adapter behind `dynamic(..., { ssr: false })` | Call `useWallet()` in a Server Component |
| Build v0 transactions with ALTs when near size limits | Default to `legacy` transactions |

## See also

- knowledge/security/solana-audit-checklist.md
- knowledge/latency/rpc-and-realtime.md
- knowledge/testing/frameworks-and-matrix.md
- knowledge/solana/tx-landing.md
