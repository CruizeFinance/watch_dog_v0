// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../../Cruize.sol";

contract CruizeFuzzTest is Cruize {

    address _dydxWallet = 0x94deFb723Fbf9f44696FC871Bfc0B35f5a28D042;
    address _crContract = 0x94deFb723Fbf9f44696FC871Bfc0B35f5a28D042;
    constructor() {
        initialize(_dydxWallet, _crContract);
    }

    function echidna_test_crContract() public view returns(bool) {
        return crContract != address(0);
    }

    function echidna_test_dydxWallet() public view returns(bool) {
        return dydxWallet != address(0);
    }

    function echidna_test_toTreasury() public view returns(bool) {
        return toTreasury == 1000; 
    }

    function echidna_test_borrowRatio() public view returns(bool) {
        return borrowRatio == 2500; 
    }
}