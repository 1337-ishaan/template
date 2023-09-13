 // SPDX-License-Identifier: MIT
 pragma solidity 0.8.7;
 
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
 // highlight-next-line
import "@zetachain/protocol-contracts/contracts/evm/Zeta.eth.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";
 
/**
 * @dev Custom errors for contract MultiChainValue
 */
 interface MultiChainValueErrors {
    error InvalidMessageType();
    // highlight-start
    error ErrorTransferringZeta();
    error ChainIdAlreadyEnabled();
    error ChainIdNotAvailable();
    error InvalidZetaValueAndGas();
    // highlight-end
}


 
/**
 * @dev MultiChainValue goal is to send Zeta token across all supported chains
 * Extends the logic defined in ZetaInteractor to handle multichain standards
 */

contract MultiChainValue is
    ZetaInteractor,
    ZetaReceiver,
    MultiChainValueErrors
{
    bytes32 public constant MULTI_CHAIN_VALUE_MESSAGE_TYPE =
        keccak256("MULTI_CHAIN_VALUE");
 
    event MultiChainValueEvent();
    event MultiChainValueRevertedEvent();
 
    //highlight-next-line
    address public _zetaToken;

    // @dev map of valid chains to send Zeta
    // highlight-next-line
    mapping(uint256 => bool) public availableChainIds;
 
    // @dev Constructor calls ZetaInteractor's constructor to setup Connector address and current chain
    constructor(
        address connectorAddress,
        address zetaTokenAddress
    ) ZetaInteractor(connectorAddress) {
         // highlight-next-line
        if (zetaTokenAddress == address(0)) revert ZetaCommonErrors.InvalidAddress();

        // hightlight-next-line
        _zetaToken = zetaTokenAddress;
    }

    /**
     * @dev Whitelist a chain to send Zeta
     */

    function sendMessage(uint256 destinationChainId, uint256 zetaValueAndGas) external payable {
    // highlight-next-line
        if (!availableChainIds[destinationChainId]) revert InvalidDestinationChainId();
        //remove-next-line
        // _zetaToken.approve(address(connector), zetaValueAndGas);

        // highlight-next-line   
        if (zetaValueAndGas == 0) revert InvalidZetaValueAndGas();

        // highlight-start
        bool success1 = ZetaEth(_zetaToken).approve(
            address(connector),
            zetaValueAndGas
        );
        bool success2 = ZetaEth(_zetaToken).transferFrom(
             msg.sender,
             address(this),
             zetaValueAndGas
        );
        if (!(success1 && success2)) revert ErrorTransferringZeta();
        // highlight-end

        connector.send(
             ZetaInterfaces.SendInput({
                destinationChainId: destinationChainId,
                destinationAddress: interactorsByChainId[destinationChainId],
                destinationGasLimit: 300000,
                message: abi.encode(MULTI_CHAIN_VALUE_MESSAGE_TYPE),
                zetaValueAndGas: zetaValueAndGas,
                zetaParams: abi.encode("")
            })
        );

}

    /**
     * @dev Whitelist a chain to send Zeta
     */
    // highlight-start
    function addAvailableChainId(
        uint256 destinationChainId
    ) external onlyOwner {
        if (availableChainIds[destinationChainId])
            revert ChainIdAlreadyEnabled();

        availableChainIds[destinationChainId] = true;
     }
    // highlight-end
 

    /**
     * @dev Blacklist a chain to send Zeta
     */
    // highlight-start
    function removeAvailableChainId(
        uint256 destinationChainId
    ) external onlyOwner {
        if (!availableChainIds[destinationChainId])
            revert ChainIdNotAvailable();

        delete availableChainIds[destinationChainId];
    }
    // highlight-end

    /**
     * @dev If the destination chain is a valid chain, send the Zeta tokens to that chain
     */
    function onZetaMessage(
        ZetaInterfaces.ZetaMessage calldata zetaMessage
    ) external override isValidMessageCall(zetaMessage) {
        (bytes32 messageType) = abi.decode(
            zetaMessage.message, (bytes32)
        );

        if (messageType != MULTI_CHAIN_VALUE_MESSAGE_TYPE)
            revert InvalidMessageType();

        emit MultiChainValueEvent();
    }

    function onZetaRevert(
        ZetaInterfaces.ZetaRevert calldata zetaRevert
    ) external override isValidRevertCall(zetaRevert) {
        (bytes32 messageType) = abi.decode(
            zetaRevert.message,
            (bytes32)
        );

        if (messageType != MULTI_CHAIN_VALUE_MESSAGE_TYPE)
            revert InvalidMessageType();

        emit MultiChainValueRevertedEvent();
    }
}
