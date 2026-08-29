// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title VulnerableVault — buidl-kit EVM test fixture
/// @notice INTENTIONALLY VULNERABLE. DO NOT DEPLOY. Standalone (no imports) so
///         the evm-security-auditor can run against it with zero setup.
///         A share-based ETH vault: deposit ETH for shares, withdraw shares for
///         the proportional ETH minus a fee. Three primary bugs are seeded; see
///         ANSWERS.md (do NOT feed ANSWERS.md to the reviewer).
contract VulnerableVault {
    address public owner;
    address public feeRecipient;
    uint256 public totalShares;
    uint256 public feeBps; // fee taken on withdraw, in basis points

    mapping(address => uint256) public shares;

    constructor(address feeRecipient_) {
        owner = msg.sender;
        feeRecipient = feeRecipient_;
        feeBps = 100; // 1%
    }

    /// @notice Deposit ETH and mint shares proportional to current backing.
    function deposit() external payable {
        require(msg.value > 0, "zero deposit");

        uint256 minted;
        if (totalShares == 0) {
            minted = msg.value; // first deposit: 1 wei = 1 share
        } else {
            // BUG 3 (share accounting): proportional mint against raw balance.
            // Integer division rounds `minted` down — a small deposit into a
            // vault with large backing mints 0 shares while the ETH stays in,
            // inflating every existing holder. The first depositor can also be
            // front-run and the price inflated by force-sent ETH, since
            // `backing` reads address(this).balance with no virtual offset and
            // no minimum-shares floor.
            uint256 backing = address(this).balance - msg.value;
            minted = (msg.value * totalShares) / backing;
        }

        shares[msg.sender] += minted;
        totalShares += minted;
    }

    /// @notice Burn `shareAmount` shares and withdraw the proportional ETH minus fee.
    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "insufficient shares");

        uint256 gross = (shareAmount * address(this).balance) / totalShares;
        uint256 fee = (gross * feeBps) / 10_000;
        uint256 net = gross - fee;

        // BUG 1 (reentrancy / CEI violation): value is sent to the caller
        // BEFORE `shares` and `totalShares` are updated, so a contract caller
        // can re-enter withdraw() with its balance still intact and drain the
        // vault. No reentrancy guard anywhere in this contract.
        (bool ok, ) = msg.sender.call{value: net}("");
        require(ok, "eth transfer failed");

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        (bool feeOk, ) = feeRecipient.call{value: fee}("");
        require(feeOk, "fee transfer failed");
    }

    /// @notice Point the fee stream at a new address.
    /// BUG 2 (missing access control): no owner check — anyone can redirect all
    /// future fees to themselves (and set up a second reentrancy surface via the
    /// fee callback in withdraw()).
    function setFeeRecipient(address newRecipient) external {
        feeRecipient = newRecipient;
    }

    /// @notice Adjust the withdraw fee. Correctly guarded — here as a contrast
    ///         to setFeeRecipient above.
    function setFeeBps(uint256 newFeeBps) external {
        require(msg.sender == owner, "only owner");
        require(newFeeBps <= 1_000, "fee too high"); // max 10%
        feeBps = newFeeBps;
    }

    receive() external payable {}
}
