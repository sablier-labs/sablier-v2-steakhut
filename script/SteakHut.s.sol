// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

import { ISablierV2LockupDynamic } from "@sablier/v2-core/src/interfaces/ISablierV2LockupDynamic.sol";
import { LockupDynamic } from "@sablier/v2-core/src/types/DataTypes.sol";
import { UD2x18 } from "@sablier/v2-core/src/types/Math.sol";
import { IERC20 } from "@sablier/v2-core/src/types/Tokens.sol";
import { BaseScript } from "@sablier/v2-core-script/Base.s.sol";
import { ISablierV2ProxyTarget } from "@sablier/v2-periphery/src/interfaces/ISablierV2ProxyTarget.sol";
import { Batch } from "@sablier/v2-periphery/src/types/DataTypes.sol";
import { IPRBProxy, IPRBProxyPlugin, IPRBProxyRegistry } from "@sablier/v2-periphery/src/types/Proxy.sol";

contract SteakHutScript is BaseScript {
    /*//////////////////////////////////////////////////////////////////////////
                                    STEAK PARAMS
    //////////////////////////////////////////////////////////////////////////*/

    // The subtracted amounts represented the 5% that had been streamed in previous streams.
    uint128 public constant AMOUNT_0 = 320_901.64e18 - 16_045.082e18;
    uint128 public constant AMOUNT_1 = 122_950.82e18 - 6147.541e18;
    uint128 public constant AMOUNT_2 = 81_967.21e18 - 4098.3605e18;
    uint128 public constant AMOUNT_3 = 32_786.89e18 - 1639.3445e18;
    uint128 public constant AMOUNT_4 = 8196.72e18 - 409.836e18;
    uint128 public constant AMOUNT_5 = 8196.72e18 - 409.836e18;
    IERC20 public constant STEAK = IERC20(0xb279f8DD152B99Ec1D84A489D32c35bC0C7F5674);
    uint128 public constant TOTAL_TRANSFER_AMOUNT = 575_000e18;

    /*//////////////////////////////////////////////////////////////////////////
                                   SABLIER PARAMS
    //////////////////////////////////////////////////////////////////////////*/

    UD2x18 public constant ONE = UD2x18.wrap(1e18);

    // Check the address: https://prbproxy.com/
    IPRBProxyRegistry public constant PROXY_REGISTRY = IPRBProxyRegistry(0x584009E9eDe26e212182c9745F5c000191296a78);

    // Check the addresses in the docs: https://docs.sablier.com/contracts/v2/deployments
    ISablierV2LockupDynamic public constant SABLIER_LOCKUP_DYNAMIC =
        ISablierV2LockupDynamic(0x665d1C8337F1035cfBe13DD94bB669110b975f5F);
    address public constant SABLIER_PROXY_PLUGIN = 0x17167A7e2763121e263B4331B700a1BF9113b387;
    ISablierV2ProxyTarget public immutable SABLIER_PROXY_TARGET =
        ISablierV2ProxyTarget(0xD87d75ceE7b7c5B9FAC5F9b37C55B53F682B9058);

    /*//////////////////////////////////////////////////////////////////////////
                                    SCRIPT LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function run() public virtual broadcast returns (uint256[] memory streamIds) {
        // Deploy an instance of PRBProxy. For more info, see:
        // https://docs.sablier.com/contracts/v2/guides/proxy-architecture/overview
        IPRBProxy proxy = PROXY_REGISTRY.getProxy({ user: broadcaster });
        if (address(proxy) == address(0)) {
            proxy = PROXY_REGISTRY.deployAndInstallPlugin({ plugin: IPRBProxyPlugin(SABLIER_PROXY_PLUGIN) });
        }

        // Approve the proxy to transfer $STEAK
        uint256 allowance = STEAK.allowance({ owner: broadcaster, spender: address(proxy) });
        if (allowance < TOTAL_TRANSFER_AMOUNT) {
            STEAK.approve({ spender: address(proxy), amount: TOTAL_TRANSFER_AMOUNT });
        }

        // Get the batch data
        Batch.CreateWithDeltas[] memory batch = getBatch(address(proxy));

        // Encode the data for the proxy
        bytes memory data = abi.encodeCall(
            SABLIER_PROXY_TARGET.batchCreateWithDeltas, (SABLIER_LOCKUP_DYNAMIC, STEAK, batch, bytes(""))
        );

        // Create a batch of streams via the proxy and Sablier's proxy target
        bytes memory response = proxy.execute(address(SABLIER_PROXY_TARGET), data);
        streamIds = abi.decode(response, (uint256[]));
    }

    function getSegmentsForUser(uint256 userIndex) public pure returns (LockupDynamic.SegmentWithDelta[] memory) {
        uint128 secondAmount;
        uint128 thirdAmount;

        if (userIndex == 0) {
            secondAmount = 101_597.459224e18; // 31.66% of 320,901.64
            thirdAmount = AMOUNT_0 - secondAmount; // remainder
        } else if (userIndex == 1) {
            secondAmount = 38_926.229612e18; // 31.66% of 122,950.82
            thirdAmount = AMOUNT_1 - secondAmount; // remainder
        } else if (userIndex == 2) {
            secondAmount = 25_950.818686e18; // 31.66% of 81,967.21
            thirdAmount = AMOUNT_2 - secondAmount; // remainder
        } else if (userIndex == 3) {
            secondAmount = 10_380.329374e18; // 31.66% of 32,786.89
            thirdAmount = AMOUNT_3 - secondAmount; // remainder
        } else if (userIndex == 4) {
            secondAmount = 2595.081552e18; // 31% of 8196.72
            thirdAmount = AMOUNT_4 - secondAmount; // remainder
        } else if (userIndex == 5) {
            secondAmount = 2595.081552e18; // 31% of 8196.72
            thirdAmount = AMOUNT_5 - secondAmount; // remainder
        } else {
            revert("Invalid user index");
        }

        // The following three segments will produce the following effect:
        //
        //   - 31.66% unlock after 1 year cliff
        //   - 63.34% linear streaming for 6 months
        //
        // Recall that 5% had been paid in previous streams.
        //
        // For more guidance, see https://docs.sablier.com/concepts/protocol/stream-types#lockup-dynamic
        LockupDynamic.SegmentWithDelta[] memory segments = new LockupDynamic.SegmentWithDelta[](3);
        segments[0] = (LockupDynamic.SegmentWithDelta({ amount: 0, delta: 31_449_599 seconds, exponent: ONE }));
        segments[1] =
            (LockupDynamic.SegmentWithDelta({ amount: secondAmount, delta: 31_449_600 seconds, exponent: ONE }));
        segments[2] = (
            LockupDynamic.SegmentWithDelta({
                amount: thirdAmount,
                delta: 15_778_476 seconds, // ~6 months
                exponent: ONE
            })
        );
        return segments;
    }

    function getBatch(address proxy) public pure returns (Batch.CreateWithDeltas[] memory) {
        Batch.CreateWithDeltas[] memory batch = new Batch.CreateWithDeltas[](6);

        batch[0].sender = address(proxy);
        batch[0].recipient = address(0xa912A42A40BE74A0ab8a1C9a4f970590AC733Fe7);
        batch[0].totalAmount = AMOUNT_0;
        batch[0].cancelable = true;
        batch[0].segments = getSegmentsForUser({ userIndex: 0 });

        batch[1].sender = address(proxy);
        batch[1].recipient = address(0xd24fa760E600081370c2730365B646A0bE46FCd0);
        batch[1].totalAmount = AMOUNT_1;
        batch[1].cancelable = true;
        batch[1].segments = getSegmentsForUser({ userIndex: 1 });

        batch[2].sender = address(proxy);
        batch[2].recipient = address(0xfBADAAb2950349a6AD82B2Eb9060E0cd008d4d2C);
        batch[2].totalAmount = AMOUNT_2;
        batch[2].cancelable = true;
        batch[2].segments = getSegmentsForUser({ userIndex: 2 });

        batch[3].sender = address(proxy);
        batch[3].recipient = address(0x17ECe27ffb9053C797e1Aea6eebc4F9A9BcD6828);
        batch[3].totalAmount = AMOUNT_3;
        batch[3].cancelable = true;
        batch[3].segments = getSegmentsForUser({ userIndex: 3 });

        batch[4].sender = address(proxy);
        batch[4].recipient = address(0xED6bbDA3b9bDcF9Da51D24493c3Cd4F7141A6b7e);
        batch[4].totalAmount = AMOUNT_4;
        batch[4].cancelable = true;
        batch[4].segments = getSegmentsForUser({ userIndex: 4 });

        batch[5].sender = address(proxy);
        batch[5].recipient = address(0x11519Af72D6a9f9eE339afD0Aa9925d199a8cc79);
        batch[5].totalAmount = AMOUNT_5;
        batch[5].cancelable = true;
        batch[5].segments = getSegmentsForUser({ userIndex: 5 });

        return batch;
    }
}
