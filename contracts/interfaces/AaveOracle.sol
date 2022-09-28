
pragma solidity ^0.8.0;

interface AaveOracle {
    function setAssetSources(address[] calldata assets, address[] calldata sources)
    external;
    event AssetSourceUpdated(address indexed asset, address indexed source);
}