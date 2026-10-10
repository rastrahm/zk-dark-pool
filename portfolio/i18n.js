const I18N = {
  es: {
    'html.lang': 'es',
    'meta.title': 'ZK Dark Pool & Blind Order Book — Rolando Strahm',
    'meta.description':
      'Dark pool institucional: órdenes ciegas Poseidon, match Groth16, ShieldedVault, gas y SWC-100–136. Foundry · Circom · Solidity 0.8.24.',

    'nav.overview': 'Proyecto',
    'nav.pillars': 'Pilares',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Proceso',
    'nav.attacks': 'Defensa',
    'nav.repos': 'Repos',
    'nav.close': '← Cerrar',

    'hero.tag': '// MÓDULO 21 · PORTFOLIO WEB3',
    'hero.title': 'ZK DARK POOL<br>BLIND ORDER BOOK',
    'hero.role': 'Solidity 0.8.24 · Foundry · Circom · Groth16 · SWC',
    'hero.sub':
      'Dark pool institucional con commitments Poseidon, match ZK on-chain y settlement atómico en vault apantallado — gas documentado y auditoría SWC-100–136.',
    'hero.cta1': 'Ver en GitHub',
    'hero.cta2': 'Ver en GitLab',

    'ov.eyebrow': '// 01 — CONTEXTO',
    'ov.title': 'Por qué este proyecto',
    'ov.lead':
      'Un dark pool institucional no puede filtrar <strong>precio ni tamaño</strong> on-chain. Este módulo combina <strong>órdenes ciegas Poseidon</strong>, verificación <strong>Groth16</strong> del match y settlement en <strong>ShieldedVault</strong>, cerrado con <strong>gas</strong> (Poseidon vs pairing) y matriz <strong>SWC</strong>.',

    'pi.eyebrow': '// 02 — TRES PILARES',
    'pi.title': 'Qué entrega el módulo',
    'p1.num': '// PILAR_01',
    'p1.title': 'Órdenes ciegas',
    'p1.desc':
      'Commitments Poseidon anidados; BlindOrderBook solo ve hashes vivos. Params ocultos hasta el match probado.',
    'p1.l1': 'OrderCommitment + PoseidonT3',
    'p1.l2': 'liveOrders / orderNullifiers',
    'p1.l3': 'OrderAlreadyFilled',
    'p2.num': '// PILAR_02',
    'p2.title': 'Match Groth16',
    'p2.desc':
      'Circuito MatchOrders(4): BUY≥SELL, rango de execPrice, membership bajo balanceRoot; 7 públicos on-chain.',
    'p2.l1': '4782 constraints · Circom 2.1.9',
    'p2.l2': 'InvalidZKProof',
    'p2.l3': 'Fixtures + Groth16Verifier',
    'p3.num': '// PILAR_03',
    'p3.title': 'Vault + Gas + SWC',
    'p3.desc':
      'ShieldedVault con settlement proof-based, opts de SLOAD, snapshot de gas y auditoría SWC-100–136 con 0 vulnerables.',
    'p3.l1': 'applySettlement solo darkPool',
    'p3.l2': '74 tests · Poseidon ~18k vs verify ~229k',
    'p3.l3': '0 SWC vulnerables',

    'gas.eyebrow': '// 03 — OPTIMIZACIÓN DE GAS',
    'gas.title': 'Poseidon vs pairing',
    'gas.lead':
      'Fase <strong>7</strong>: baseline en <code>.gas-snapshot</code> y tradeoffs en <code>doc/GAS.md</code>. El coste e2e lo domina <strong>Groth16</strong>; las opts del pool recortan SLOAD/SSTORE en el path de match.',
    'gas.th1': 'Optimización / path',
    'gas.th2': 'Tradeoff / efecto',
    'gas.r1a': 'PoseidonT3.hash ≈ 18 229',
    'gas.r1b': 'Baseline hash 2-inputs; hashOrder ~65k (3× anidados)',
    'gas.r2a': 'Groth16Verifier.verifyProof ≈ 228 808',
    'gas.r2b': '~12.5× un Poseidon; dominante en e2e',
    'gas.r3a': 'Checks baratos antes del pairing',
    'gas.r3b': 'live / nullifier / root fallan sin pagar ecPairing',
    'gas.r4a': 'Mark nullifiers sin re-SLOAD',
    'gas.r4b': 'Tras checks, write directo (evita 4 SLOAD de _consumeOrder)',
    'gas.r5a': 'Cache immutables vault/verifier',
    'gas.r5b': 'Menos lecturas repetidas en executeMatch',
    'gas.r6a': 'Transient reentrancy por contrato',
    'gas.r6b': 'tstore xor address(); DarkPool→Vault sin falso reentrancy',
    'gas.r7a': 'executeMatch mock ≈ 135k · e2e ≈ 2.4M',
    'gas.r7b': 'MockVerifier vs deposits Poseidon + pairing real',

    'swc.eyebrow': '// 04 — VERIFICACIÓN SWC',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Matriz completa <strong>SWC-100 → SWC-136</strong> contra DarkPool / Vault / Verifier. Informe en <code>doc/SWC-AUDIT.md</code> (estilo módulo 20). Conclusión: <strong>0 vulnerabilidades explotables</strong>.',
    'swc.s1': 'Mitigados / N/A',
    'swc.s2': 'Informativos (diseño)',
    'swc.s3': 'Vulnerables',
    'swc.th1': 'SWC clave',
    'swc.th2': 'Mitigación en el protocolo',
    'swc.r103': 'Floating pragma: pragma solidity 0.8.24 fijo',
    'swc.r107': 'Reentrancy: CEI + transient lock por contrato (pool→vault)',
    'swc.r121': 'Replay: orderNullifiers + noteNullifiers; tests de replay',
    'swc.r122': 'Proof inválida: pairing Groth16 + binding de 7 públicos',
    'swc.r123': 'Requirement: OrderAlreadyFilled / InvalidZKProof / UnknownBalanceRoot',
    'swc.r136': 'Privacidad: params de orden solo como commitments Poseidon',
    'swc.info': 'INFORMATIVO',
    'swc.i1t': 'Carrera de matchers',
    'swc.i1d':
      'Varios relayers pueden enviar el mismo proof; solo el primero marca nullifiers. Inherente a dark pools.',
    'swc.i2t': 'Pairing costoso · ptau lab',
    'swc.i2d':
      'verifyProof ~229k gas (caller paga). Trusted setup de lab (pot14) no es ceremonia productiva.',

    'pr.eyebrow': '// 05 — PROCESO',
    'pr.title': 'Fases 0–7 cerradas',
    'pr.lead':
      'Gates de autorización: setup → hasher/book → vault → circuito → verifier → DarkPool → matriz seguridad → gas/Deploy/SWC.',
    'ph.0': 'Bootstrap Foundry + Circom',
    'ph.12': 'Hasher + BlindOrderBook + Vault',
    'ph.34': 'MatchOrders + Groth16Verifier',
    'ph.56': 'executeMatch + matriz seguridad',
    'ph.7': 'Gas + Deploy + SWC · cierre v1',
    'st.1': 'Fases',
    'st.2': 'Tests PASS',
    'st.3': 'SWC críticos',
    'st.4': 'Campañas def.',

    'term.label': 'rolando@strahm:~/21-zk-dark-pool',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 74 passed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informativos: 5 · Mitigados/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_21_CLOSED · V1_OK',

    'at.eyebrow': '// 06 — CAMPAÑAS DEFENSIVAS',
    'at.title': 'Defensivo, no ofensivo',
    'at.lead':
      'MatchExecution, OrderNullifierReplay, PriceMismatch y TamperedProof: el “éxito” del misuse es que revierte. Sin PoCs de exploit.',
    'cA.t': 'Match OK',
    'cA.d': 'Settlement atómico con proof válida + change notes.',
    'cB.t': 'Nullifier replay',
    'cB.d': 'Segundo match → OrderAlreadyFilled (SWC-121).',
    'cC.t': 'Price mismatch',
    'cC.d': 'execPrice/execAmount tampered → InvalidZKProof.',
    'cD.t': 'Tampered proof',
    'cD.d': 'a/b/c o commitments alterados → InvalidZKProof.',
    'cE.t': 'Gas paths',
    'cE.d': 'Poseidon vs Groth16 + e2e snapshot documentado.',

    're.eyebrow': '// 07 — CÓDIGO ABIERTO',
    're.title': 'Repositorios',
    're.lead':
      'Mismo código en GitHub y GitLab: contratos, circuito Circom, tests, GAS.md, SWC-AUDIT.md, diagramas y Deploy.',
    're.cta': 'Contactar',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — ZK Dark Pool · Blind Order Book · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · CIRCOM · GROTH16 · ALL_SYSTEMS_OPERATIONAL',
  },

  en: {
    'html.lang': 'en',
    'meta.title': 'ZK Dark Pool & Blind Order Book — Rolando Strahm',
    'meta.description':
      'Institutional dark pool: Poseidon blind orders, Groth16 match, ShieldedVault, gas and SWC-100–136. Foundry · Circom · Solidity 0.8.24.',

    'nav.overview': 'Project',
    'nav.pillars': 'Pillars',
    'nav.gas': 'Gas',
    'nav.swc': 'SWC',
    'nav.process': 'Process',
    'nav.attacks': 'Defense',
    'nav.repos': 'Repos',
    'nav.close': '← Close',

    'hero.tag': '// MODULE 21 · WEB3 PORTFOLIO',
    'hero.title': 'ZK DARK POOL<br>BLIND ORDER BOOK',
    'hero.role': 'Solidity 0.8.24 · Foundry · Circom · Groth16 · SWC',
    'hero.sub':
      'Institutional dark pool with Poseidon commitments, on-chain ZK match, and atomic settlement in a shielded vault — documented gas and a full SWC-100–136 audit.',
    'hero.cta1': 'View on GitHub',
    'hero.cta2': 'View on GitLab',

    'ov.eyebrow': '// 01 — CONTEXT',
    'ov.title': 'Why this project',
    'ov.lead':
      'An institutional dark pool must not leak <strong>price or size</strong> on-chain. This module combines <strong>Poseidon blind orders</strong>, <strong>Groth16</strong> match verification, and <strong>ShieldedVault</strong> settlement, closed with <strong>gas</strong> (Poseidon vs pairing) and an <strong>SWC</strong> matrix.',

    'pi.eyebrow': '// 02 — THREE PILLARS',
    'pi.title': 'What the module ships',
    'p1.num': '// PILLAR_01',
    'p1.title': 'Blind orders',
    'p1.desc':
      'Nested Poseidon commitments; BlindOrderBook only sees live hashes. Params stay hidden until a proven match.',
    'p1.l1': 'OrderCommitment + PoseidonT3',
    'p1.l2': 'liveOrders / orderNullifiers',
    'p1.l3': 'OrderAlreadyFilled',
    'p2.num': '// PILLAR_02',
    'p2.title': 'Groth16 match',
    'p2.desc':
      'MatchOrders(4) circuit: BUY≥SELL, execPrice range, membership under balanceRoot; 7 public inputs on-chain.',
    'p2.l1': '4782 constraints · Circom 2.1.9',
    'p2.l2': 'InvalidZKProof',
    'p2.l3': 'Fixtures + Groth16Verifier',
    'p3.num': '// PILLAR_03',
    'p3.title': 'Vault + Gas + SWC',
    'p3.desc':
      'ShieldedVault with proof-based settlement, SLOAD opts, gas snapshot, and SWC-100–136 audit with 0 vulnerable findings.',
    'p3.l1': 'applySettlement darkPool-only',
    'p3.l2': '74 tests · Poseidon ~18k vs verify ~229k',
    'p3.l3': '0 vulnerable SWCs',

    'gas.eyebrow': '// 03 — GAS OPTIMIZATION',
    'gas.title': 'Poseidon vs pairing',
    'gas.lead':
      'Phase <strong>7</strong>: baseline in <code>.gas-snapshot</code> and tradeoffs in <code>doc/GAS.md</code>. E2E cost is dominated by <strong>Groth16</strong>; pool opts cut SLOAD/SSTORE on the match path.',
    'gas.th1': 'Optimization / path',
    'gas.th2': 'Tradeoff / effect',
    'gas.r1a': 'PoseidonT3.hash ≈ 18,229',
    'gas.r1b': '2-input hash baseline; hashOrder ~65k (3× nested)',
    'gas.r2a': 'Groth16Verifier.verifyProof ≈ 228,808',
    'gas.r2b': '~12.5× one Poseidon; dominates e2e',
    'gas.r3a': 'Cheap checks before pairing',
    'gas.r3b': 'live / nullifier / root fail without paying ecPairing',
    'gas.r4a': 'Mark nullifiers without re-SLOAD',
    'gas.r4b': 'After checks, direct writes (skips 4 SLOADs from _consumeOrder)',
    'gas.r5a': 'Cache vault/verifier immutables',
    'gas.r5b': 'Fewer repeated reads in executeMatch',
    'gas.r6a': 'Per-contract transient reentrancy',
    'gas.r6b': 'tstore xor address(); DarkPool→Vault without false reentrancy',
    'gas.r7a': 'executeMatch mock ≈ 135k · e2e ≈ 2.4M',
    'gas.r7b': 'MockVerifier vs Poseidon deposits + real pairing',

    'swc.eyebrow': '// 04 — SWC VERIFICATION',
    'swc.title': 'SWC Registry · EIP-1470',
    'swc.lead':
      'Full <strong>SWC-100 → SWC-136</strong> matrix against DarkPool / Vault / Verifier. Report in <code>doc/SWC-AUDIT.md</code> (module-20 style). Conclusion: <strong>0 exploitable vulnerabilities</strong>.',
    'swc.s1': 'Mitigated / N/A',
    'swc.s2': 'Informational (design)',
    'swc.s3': 'Vulnerable',
    'swc.th1': 'Key SWC',
    'swc.th2': 'Mitigation in the protocol',
    'swc.r103': 'Floating pragma: fixed pragma solidity 0.8.24',
    'swc.r107': 'Reentrancy: CEI + per-contract transient lock (pool→vault)',
    'swc.r121': 'Replay: orderNullifiers + noteNullifiers; replay tests',
    'swc.r122': 'Invalid proof: Groth16 pairing + 7-public binding',
    'swc.r123': 'Requirement: OrderAlreadyFilled / InvalidZKProof / UnknownBalanceRoot',
    'swc.r136': 'Privacy: order params only as Poseidon commitments',
    'swc.info': 'INFORMATIONAL',
    'swc.i1t': 'Matcher race',
    'swc.i1d':
      'Several relayers may submit the same proof; only the first marks nullifiers. Inherent to dark pools.',
    'swc.i2t': 'Expensive pairing · lab ptau',
    'swc.i2d':
      'verifyProof ~229k gas (caller pays). Lab trusted setup (pot14) is not a production ceremony.',

    'pr.eyebrow': '// 05 — PROCESS',
    'pr.title': 'Phases 0–7 closed',
    'pr.lead':
      'Authorization gates: setup → hasher/book → vault → circuit → verifier → DarkPool → security matrix → gas/Deploy/SWC.',
    'ph.0': 'Foundry + Circom bootstrap',
    'ph.12': 'Hasher + BlindOrderBook + Vault',
    'ph.34': 'MatchOrders + Groth16Verifier',
    'ph.56': 'executeMatch + security matrix',
    'ph.7': 'Gas + Deploy + SWC · v1 closeout',
    'st.1': 'Phases',
    'st.2': 'Tests PASS',
    'st.3': 'Critical SWCs',
    'st.4': 'Def. campaigns',

    'term.label': 'rolando@strahm:~/21-zk-dark-pool',
    'term.1': 'forge test',
    'term.2': '[PASS] suite · 74 passed',
    'term.3': 'cat doc/SWC-AUDIT.md | head',
    'term.4': 'Vulnerable: 0 · Informational: 5 · Mitigated/N/A: 31',
    'term.5': 'echo status',
    'term.6': 'MODULE_21_CLOSED · V1_OK',

    'at.eyebrow': '// 06 — DEFENSIVE CAMPAIGNS',
    'at.title': 'Defensive, not offensive',
    'at.lead':
      'MatchExecution, OrderNullifierReplay, PriceMismatch, and TamperedProof: a successful “misuse” means the call reverts. No exploit PoCs.',
    'cA.t': 'Match OK',
    'cA.d': 'Atomic settlement with a valid proof + change notes.',
    'cB.t': 'Nullifier replay',
    'cB.d': 'Second match → OrderAlreadyFilled (SWC-121).',
    'cC.t': 'Price mismatch',
    'cC.d': 'Tampered execPrice/execAmount → InvalidZKProof.',
    'cD.t': 'Tampered proof',
    'cD.d': 'Altered a/b/c or commitments → InvalidZKProof.',
    'cE.t': 'Gas paths',
    'cE.d': 'Poseidon vs Groth16 + documented e2e snapshot.',

    're.eyebrow': '// 07 — OPEN SOURCE',
    're.title': 'Repositories',
    're.lead':
      'Same codebase on GitHub and GitLab: contracts, Circom circuit, tests, GAS.md, SWC-AUDIT.md, diagrams, and Deploy.',
    're.cta': 'Contact',
    're.linkedin': 'LinkedIn',

    'ft.left': 'ROLANDO STRAHM — ZK Dark Pool · Blind Order Book · Portfolio',
    'ft.right': 'FOUNDRY · SOLC 0.8.24 · CIRCOM · GROTH16 · ALL_SYSTEMS_OPERATIONAL',
  },
};

function setLanguage(lang) {
  const dict = I18N[lang] || I18N.es;
  document.documentElement.lang = dict['html.lang'];
  document.title = dict['meta.title'];

  const metaDesc = document.querySelector('meta[name="description"]');
  if (metaDesc && dict['meta.description']) {
    metaDesc.setAttribute('content', dict['meta.description']);
  }

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    const val = dict[key];
    if (val == null) return;
    if (el.hasAttribute('data-i18n-html')) el.innerHTML = val;
    else el.textContent = val;
  });

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.lang === lang);
  });

  localStorage.setItem('zk-dark-pool-portfolio-lang', lang);

  const url = new URL(window.location.href);
  url.searchParams.set('lang', lang);
  history.replaceState(null, '', url);
}

function initI18n() {
  const params = new URLSearchParams(window.location.search);
  const fromQuery = params.get('lang');
  const saved = localStorage.getItem('zk-dark-pool-portfolio-lang');
  const preferred =
    (fromQuery === 'en' || fromQuery === 'es' ? fromQuery : null) ||
    saved ||
    (navigator.language?.startsWith('en') ? 'en' : 'es');

  setLanguage(preferred);

  document.querySelectorAll('.lang-btn').forEach((btn) => {
    btn.addEventListener('click', () => setLanguage(btn.dataset.lang));
  });
}

document.addEventListener('DOMContentLoaded', initI18n);
