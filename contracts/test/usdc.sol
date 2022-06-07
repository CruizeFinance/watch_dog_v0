import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() ERC20("USDC","USDC"){
        _mint(msg.sender, 100000 ether);
    }
}