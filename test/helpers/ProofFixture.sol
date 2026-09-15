// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title ProofFixtureLib
 * @notice Carga `test/fixtures/match/solidity_proof.json` para tests Foundry.
 */
library ProofFixtureLib {
    using stdJson for string;

    struct ProofData {
        uint256[2] a;
        uint256[2][2] b;
        uint256[2] c;
        uint256[7] input;
    }

    /**
     * @notice Lee la fixture Solidity-friendly exportada en Fase 4.
     * @param json Contenido de solidity_proof.json.
     */
    function parse(string memory json) internal pure returns (ProofData memory p) {
        p.a[0] = json.readUint(".a[0]");
        p.a[1] = json.readUint(".a[1]");
        p.b[0][0] = json.readUint(".b[0][0]");
        p.b[0][1] = json.readUint(".b[0][1]");
        p.b[1][0] = json.readUint(".b[1][0]");
        p.b[1][1] = json.readUint(".b[1][1]");
        p.c[0] = json.readUint(".c[0]");
        p.c[1] = json.readUint(".c[1]");
        p.input[0] = json.readUint(".input[0]");
        p.input[1] = json.readUint(".input[1]");
        p.input[2] = json.readUint(".input[2]");
        p.input[3] = json.readUint(".input[3]");
        p.input[4] = json.readUint(".input[4]");
        p.input[5] = json.readUint(".input[5]");
        p.input[6] = json.readUint(".input[6]");
    }
}

/**
 * @title ProofFixtureBase
 * @notice Base de test con helper de lectura de fixture MatchOrders.
 */
abstract contract ProofFixtureBase is Test {
    string internal constant FIXTURE_PATH = "test/fixtures/match/solidity_proof.json";

    function _loadProof() internal view returns (ProofFixtureLib.ProofData memory) {
        string memory json = vm.readFile(FIXTURE_PATH);
        return ProofFixtureLib.parse(json);
    }
}
