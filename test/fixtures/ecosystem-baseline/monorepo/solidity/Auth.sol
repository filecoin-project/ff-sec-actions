pragma solidity ^0.8.13;

contract Auth {
    address owner;
    function privileged() external view {
        // ruleid: filecoin.solidity.tx-origin-authorization
        require(tx.origin == owner, "owner only");
    }
}
