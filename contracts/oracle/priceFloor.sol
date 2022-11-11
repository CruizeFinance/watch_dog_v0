// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";

contract APIConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    uint256 private fee;

    uint256 public btc;
    uint256 public eth;

    event RequestEthPriceFloor(bytes32 indexed requestId, uint256 eth);
    event RequestBtcPriceFloor(bytes32 indexed requestId, uint256 btc);
    /**
     * @notice Initialize the link token and target oracle
     *
     * Goerli Testnet details:
     * Link Token: 0x326C977E6efc84E512bB9C30f76E30c160eD06FB
     * Oracle: 0xCC79157eb46F5624204f47AB42b3906cAA40eaB7 (Chainlink DevRel)
     * jobId: ca98366cc7314957b8c012c72f05aeeb
     *
     */
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x326C977E6efc84E512bB9C30f76E30c160eD06FB);
        setChainlinkOracle(0xCC79157eb46F5624204f47AB42b3906cAA40eaB7);
        jobId = "ca98366cc7314957b8c012c72f05aeeb";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    function requestEthPriceFloor() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.setETH.selector);

        // Set the URL to perform the GET request on
        req.add("get", "https://test.trident.cruize.finance/cruize_operations/price_floor?format=json");
        req.add("path", "result,ethereum");
        req.addInt("times", 1e8); 

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function requestBtcPriceFloor() public returns (bytes32 requestId) {
        Chainlink.Request memory req = buildChainlinkRequest(jobId, address(this), this.setBTC.selector);

        // Set the URL to perform the GET request on
        req.add("get", "https://test.trident.cruize.finance/cruize_operations/price_floor?format=json");
        req.add("path", "result,bitcoin");
        req.addInt("times", 1e8); 

        // Sends the request
        return sendChainlinkRequest(req, fee);
    }

    function setETH(
        bytes32 requestId,
        uint256 ethResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestEthPriceFloor(requestId, ethResponse);
        eth = ethResponse;
    }

    function setBTC(
        bytes32 requestId,
        uint256 btcResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestBtcPriceFloor(requestId, btcResponse);
        btc = btcResponse;
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(link.transfer(msg.sender, link.balanceOf(address(this))), "Unable to transfer");
    }
}

