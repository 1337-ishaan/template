// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@zetachain/protocol-contracts/contracts/evm/tools/ZetaInteractor.sol";
import "@zetachain/protocol-contracts/contracts/evm/interfaces/ZetaInterfaces.sol";

interface MultiChainValueErrors {
    error InvalidMessageType();
}

contract MultiChainValue is
    ZetaInteractor,
    ZetaReceiver,
    MultiChainValueErrors
{
    bytes32 public constant MULTI_CHAIN_VALUE_MESSAGE_TYPE =
        keccak256("CROSS_CHAIN_MULTI_CHAIN_VALUE");

    event MultiChainValueEvent();
    event MultiChainValueRevertedEvent();

    ZetaTokenConsumer private immutable _zetaConsumer;
    IERC20 internal immutable _zetaToken;

    constructor(
        address connectorAddress,
        address zetaTokenAddress,
        address zetaConsumerAddress
    ) ZetaInteractor(connectorAddress) {
        _zetaToken = IERC20(zetaTokenAddress);
        _zetaConsumer = ZetaTokenConsumer(zetaConsumerAddress);
    }

    function sendMessage(uint256 destinationChainId) external payable {
        if (!_isValidChainId(destinationChainId))
            revert InvalidDestinationChainId();

        uint256 crossChainGas = 2 * (10 ** 18);
        uint256 zetaValueAndGas = _zetaConsumer.getZetaFromEth{
            value: msg.value
        }(address(this), crossChainGas);
        _zetaToken.approve(address(connector), zetaValueAndGas);

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
