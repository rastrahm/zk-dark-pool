// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity 0.8.24;

import {IVerifier} from "../interfaces/IVerifier.sol";

/// @notice Verifier Groth16 generado por snarkJS (GPL-3.0) — VK del circuito MatchOrders(4).
contract Groth16Verifier is IVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 13980431271589359908123445396195044039245723511809490087112269123319720276431;
    uint256 constant alphay  = 10909974648138072404189185952887379864063958793235181050337885522085024186549;
    uint256 constant betax1  = 14638784398519314338072514749167930053544862370067027528311901224538201408879;
    uint256 constant betax2  = 15792823622904755751936950196389632176066748182564424111284226173060149545375;
    uint256 constant betay1  = 9273714375317794467677266057586121723159457661407837803136153277484604187283;
    uint256 constant betay2  = 2712747391765549725423109417933146633758980485301823737333442091462212380536;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 16260924501035203029102346585953037013700300932018035336325461262411068789157;
    uint256 constant deltax2 = 11614287485390537856798796849893421471024870835964542509290658210832819130316;
    uint256 constant deltay1 = 8656582107885588197469967123426865391919115634188618434863816916421027017839;
    uint256 constant deltay2 = 16704294015262172966963545035080921274855256189361014021197871137026701198844;

    
    uint256 constant IC0x = 280289903585725957397541214321444241220684872480458591731502007456290574606;
    uint256 constant IC0y = 4276493595670063136599883881702911550977021241517701423900740019988770806961;
    
    uint256 constant IC1x = 20108348244905582564282625489378509777512999871020817907025656105660062642821;
    uint256 constant IC1y = 20400190723973523298824777658522016322312596371443760156089223233983465774850;
    
    uint256 constant IC2x = 5519489188925474672833029227003313782695496706659686021744779996550822783778;
    uint256 constant IC2y = 12032264666063736533718644800237586252352928733311815454962781045309536811942;
    
    uint256 constant IC3x = 16726064933774726369247940409697624851019136655106800412952970170048673195886;
    uint256 constant IC3y = 20278184216872428290015024394164445401380942821319812228032811856764515079755;
    
    uint256 constant IC4x = 1403198262192717509311997989164561142033161732968970236199321204963093041012;
    uint256 constant IC4y = 21691006059255755016188451296071915377055582476564002244473397535539026290616;
    
    uint256 constant IC5x = 10844513969898067901831926678036330120802740161225035758627894166833338894803;
    uint256 constant IC5y = 5841103746865301277304441240033740307300187788794974183600144077278070353430;
    
    uint256 constant IC6x = 18159557835372948329196419250289458858940285551267641449689187209911095727931;
    uint256 constant IC6y = 4328903449049491806300064050336847146733455704307579546564157439657063869291;
    
    uint256 constant IC7x = 2622041120285631493812102657481025466735911388674965977665317001743087588480;
    uint256 constant IC7y = 11834017655119683744044485808931044661927614570457240547470349085641288110757;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(
        uint256[2] calldata _pA,
        uint256[2][2] calldata _pB,
        uint256[2] calldata _pC,
        uint256[7] calldata _pubSignals
    ) public view override returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
