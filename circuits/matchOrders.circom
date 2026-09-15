pragma circom 2.1.0;

include "./merkleTree.circom";
include "../node_modules/circomlib/circuits/poseidon.circom";
include "../node_modules/circomlib/circuits/comparators.circom";

/**
 * @title OrderCommit
 * @notice Alineado a Solidity `OrderCommitment.commit`:
 *         Poseidon(Poseidon(price, amount), Poseidon(side, salt)).
 */
template OrderCommit() {
    signal input price;
    signal input amount;
    signal input side;
    signal input salt;
    signal output commitment;

    component left = Poseidon(2);
    left.inputs[0] <== price;
    left.inputs[1] <== amount;

    component right = Poseidon(2);
    right.inputs[0] <== side;
    right.inputs[1] <== salt;

    component outer = Poseidon(2);
    outer.inputs[0] <== left.out;
    outer.inputs[1] <== right.out;
    commitment <== outer.out;
}

/**
 * @title MatchOrders
 * @notice Prueba de match BUY/SELL + membership de notas bajo balanceRoot.
 *
 * Publicos (orden fijo — alinear con DarkPool / fixtures):
 *   0: buyCommitment
 *   1: sellCommitment
 *   2: buyNullifier
 *   3: sellNullifier
 *   4: balanceRoot
 *   5: execAmount
 *   6: execPrice
 *
 * Relaciones:
 *   orderCommitment = Poseidon(Poseidon(price,amount), Poseidon(side,salt))
 *   orderNullifier  = Poseidon(salt, side)
 *   noteCommitment  = Poseidon(noteAmount, noteSecret)
 *   buyPrice >= sellPrice
 *   sellPrice <= execPrice <= buyPrice
 *   execAmount <= buyAmount && execAmount <= sellAmount
 *   execAmount <= buyNoteAmount && execAmount <= sellNoteAmount
 *   Merkle(buyNote) y Merkle(sellNote) => balanceRoot
 *
 * SIDE_BUY = 0, SIDE_SELL = 1
 */
template MatchOrders(levels) {
    // Publicos
    signal input buyCommitment;
    signal input sellCommitment;
    signal input buyNullifier;
    signal input sellNullifier;
    signal input balanceRoot;
    signal input execAmount;
    signal input execPrice;

    // Privados — orden BUY
    signal input buyPrice;
    signal input buyAmount;
    signal input buySalt;

    // Privados — orden SELL
    signal input sellPrice;
    signal input sellAmount;
    signal input sellSalt;

    // Privados — notas apantalladas (saldo)
    signal input buyNoteAmount;
    signal input buyNoteSecret;
    signal input sellNoteAmount;
    signal input sellNoteSecret;
    signal input buyPathElements[levels];
    signal input buyPathIndices[levels];
    signal input sellPathElements[levels];
    signal input sellPathIndices[levels];

    var SIDE_BUY = 0;
    var SIDE_SELL = 1;

    // --- Order commitments ---
    component buyCommit = OrderCommit();
    buyCommit.price <== buyPrice;
    buyCommit.amount <== buyAmount;
    buyCommit.side <== SIDE_BUY;
    buyCommit.salt <== buySalt;
    buyCommitment === buyCommit.commitment;

    component sellCommit = OrderCommit();
    sellCommit.price <== sellPrice;
    sellCommit.amount <== sellAmount;
    sellCommit.side <== SIDE_SELL;
    sellCommit.salt <== sellSalt;
    sellCommitment === sellCommit.commitment;

    // --- Nullifiers: Poseidon(salt, side) ---
    component buyNull = Poseidon(2);
    buyNull.inputs[0] <== buySalt;
    buyNull.inputs[1] <== SIDE_BUY;
    buyNullifier === buyNull.out;

    component sellNull = Poseidon(2);
    sellNull.inputs[0] <== sellSalt;
    sellNull.inputs[1] <== SIDE_SELL;
    sellNullifier === sellNull.out;

    // --- Precio: buyPrice >= sellPrice ---
    component priceMatch = GreaterEqThan(64);
    priceMatch.in[0] <== buyPrice;
    priceMatch.in[1] <== sellPrice;
    priceMatch.out === 1;

    // --- execPrice en [sellPrice, buyPrice] ---
    component execGteSell = GreaterEqThan(64);
    execGteSell.in[0] <== execPrice;
    execGteSell.in[1] <== sellPrice;
    execGteSell.out === 1;

    component execLteBuy = GreaterEqThan(64);
    execLteBuy.in[0] <== buyPrice;
    execLteBuy.in[1] <== execPrice;
    execLteBuy.out === 1;

    // --- execAmount <= order amounts ---
    component execLteBuyAmt = GreaterEqThan(64);
    execLteBuyAmt.in[0] <== buyAmount;
    execLteBuyAmt.in[1] <== execAmount;
    execLteBuyAmt.out === 1;

    component execLteSellAmt = GreaterEqThan(64);
    execLteSellAmt.in[0] <== sellAmount;
    execLteSellAmt.in[1] <== execAmount;
    execLteSellAmt.out === 1;

    // --- Notas: Poseidon(noteAmount, noteSecret) + saldo suficiente ---
    component buyNoteHash = Poseidon(2);
    buyNoteHash.inputs[0] <== buyNoteAmount;
    buyNoteHash.inputs[1] <== buyNoteSecret;

    component sellNoteHash = Poseidon(2);
    sellNoteHash.inputs[0] <== sellNoteAmount;
    sellNoteHash.inputs[1] <== sellNoteSecret;

    component buyNoteAmtOk = GreaterEqThan(64);
    buyNoteAmtOk.in[0] <== buyNoteAmount;
    buyNoteAmtOk.in[1] <== execAmount;
    buyNoteAmtOk.out === 1;

    component sellNoteAmtOk = GreaterEqThan(64);
    sellNoteAmtOk.in[0] <== sellNoteAmount;
    sellNoteAmtOk.in[1] <== execAmount;
    sellNoteAmtOk.out === 1;

    // --- Membership bajo balanceRoot ---
    component buyTree = MerkleTreeChecker(levels);
    buyTree.leaf <== buyNoteHash.out;
    buyTree.root <== balanceRoot;
    for (var i = 0; i < levels; i++) {
        buyTree.pathElements[i] <== buyPathElements[i];
        buyTree.pathIndices[i] <== buyPathIndices[i];
    }

    component sellTree = MerkleTreeChecker(levels);
    sellTree.leaf <== sellNoteHash.out;
    sellTree.root <== balanceRoot;
    for (var j = 0; j < levels; j++) {
        sellTree.pathElements[j] <== sellPathElements[j];
        sellTree.pathIndices[j] <== sellPathIndices[j];
    }

    // Binding de publicos (anti-malleability)
    signal execAmountSquare;
    signal execPriceSquare;
    execAmountSquare <== execAmount * execAmount;
    execPriceSquare <== execPrice * execPrice;
}

// Lab: depth 4 (16 hojas). Debe coincidir con ShieldedVault MERKLE_TREE_LEVELS.
component main {
    public [
        buyCommitment,
        sellCommitment,
        buyNullifier,
        sellNullifier,
        balanceRoot,
        execAmount,
        execPrice
    ]
} = MatchOrders(4);
