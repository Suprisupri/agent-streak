// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title Agent Streak
/// @notice Daily check-in dApp for Binance Agent ID holders (BNB Chain).
/// @dev Minimal, dependency-free contract: no external imports, so the source
///      is trivially verifiable on BscScan. The contract NEVER holds user funds:
///      there is no payable function, no deposit, no paid mint, no withdraw.
///
///      Agent ID ownership is checked via balanceOf() on the SPACE ID Agent ID
///      contract (ERC-721, non-transferable): 0x60b9262456de011f7d15a54cdd8c48baaa8b022f
///
///      Owner permissions (minimal, see README.md "Owner Permissions"):
///      the owner can ONLY pause / unpause check-ins and badge claims.
///      There is no withdraw, no forced mint, no streak-rule change.

interface IAgentId {
    function balanceOf(address owner) external view returns (uint256);
}

/// @dev Minimal Base64 encoder (no external dependency).
/// @notice Plain-Solidity implementation: easy to audit, and tokenURI is a
///         view function (called off-chain), so gas is not a concern here.
library Base64 {
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";
        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        bytes memory table = bytes(_TABLE);
        uint256 j;
        for (uint256 i = 0; i < len; i += 3) {
            uint256 remaining = len - i;
            uint256 n = uint256(uint8(data[i])) << 16;
            if (remaining > 1) n |= uint256(uint8(data[i + 1])) << 8;
            if (remaining > 2) n |= uint256(uint8(data[i + 2]));
            result[j++] = table[(n >> 18) & 0x3F];
            result[j++] = table[(n >> 12) & 0x3F];
            result[j++] = remaining > 1 ? table[(n >> 6) & 0x3F] : bytes1("=");
            result[j++] = remaining > 2 ? table[n & 0x3F] : bytes1("=");
        }
        return string(result);
    }
}

contract AgentStreak {
    // ------------------------------------------------------------------------
    // Errors
    // ------------------------------------------------------------------------
    error NotAgentIdHolder();
    error AlreadyCheckedIn();
    error InvalidMilestone();
    error InsufficientStreak();
    error BadgeAlreadyClaimed();
    error Soulbound();
    error ContractPaused();
    error NotOwner();
    error TokenDoesNotExist();

    // ------------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------------
    event CheckedIn(address indexed user, uint256 day, uint256 streak);
    event BadgeClaimed(address indexed user, uint256 milestone, uint256 tokenId);
    event Paused(address indexed by);
    event Unpaused(address indexed by);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    // ------------------------------------------------------------------------
    // Constants / immutables
    // ------------------------------------------------------------------------
    IAgentId public immutable agentId;
    address public immutable owner;

    string public constant name = "Agent Streak Badge";
    string public constant symbol = "ASB";

    uint256 public constant MILESTONE_7 = 7;
    uint256 public constant MILESTONE_14 = 14;
    uint256 public constant MILESTONE_30 = 30;

    // ------------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------------
    bool public paused;

    mapping(address => uint256) public currentStreak;
    mapping(address => uint256) public bestStreak;
    mapping(address => uint256) public lastCheckInDay;
    mapping(address => uint256) public totalCheckIns;
    mapping(address => mapping(uint256 => bool)) public hasClaimed;

    uint256 public totalUsers;
    uint256 public totalCheckInsGlobal;

    // Minimal ERC-721 (soulbound) state
    uint256 private _nextTokenId = 1;
    mapping(uint256 => address) private _badgeOwner;
    mapping(uint256 => uint256) private _badgeMilestone;
    mapping(address => uint256) private _badgeBalance;

    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    /// @param agentIdAddress SPACE ID Agent ID contract (BNB Chain mainnet:
    ///        0x60b9262456de011f7d15a54cdd8c48baaa8b022f).
    /// @param ownerAddress Owner of the contract (pause/unpause only). Passed
    ///        explicitly because the production deploy goes through a CREATE2
    ///        factory, so msg.sender at construction is the factory, not the
    ///        owner.
    constructor(address agentIdAddress, address ownerAddress) {
        agentId = IAgentId(agentIdAddress);
        owner = ownerAddress;
    }

    // ------------------------------------------------------------------------
    // Modifiers
    // ------------------------------------------------------------------------
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ------------------------------------------------------------------------
    // Core: check-in
    // ------------------------------------------------------------------------
    /// @notice Check in for the current UTC day. Requires holding an Agent ID.
    /// @dev day = block.timestamp / 86400 (UTC day index).
    function checkIn() external whenNotPaused {
        if (agentId.balanceOf(msg.sender) == 0) revert NotAgentIdHolder();

        uint256 day = block.timestamp / 86400;
        if (lastCheckInDay[msg.sender] == day) revert AlreadyCheckedIn();

        uint256 streak;
        if (lastCheckInDay[msg.sender] == day - 1) {
            streak = currentStreak[msg.sender] + 1;
        } else {
            streak = 1;
        }

        if (totalCheckIns[msg.sender] == 0) {
            totalUsers += 1;
        }

        currentStreak[msg.sender] = streak;
        if (streak > bestStreak[msg.sender]) {
            bestStreak[msg.sender] = streak;
        }
        lastCheckInDay[msg.sender] = day;
        totalCheckIns[msg.sender] += 1;
        totalCheckInsGlobal += 1;

        emit CheckedIn(msg.sender, day, streak);
    }

    // ------------------------------------------------------------------------
    // Core: badges
    // ------------------------------------------------------------------------
    /// @notice Claim a soulbound badge for a streak milestone (7, 14, or 30).
    function claimBadge(uint256 milestone) external whenNotPaused returns (uint256 tokenId) {
        if (!_isValidMilestone(milestone)) revert InvalidMilestone();
        if (bestStreak[msg.sender] < milestone) revert InsufficientStreak();
        if (hasClaimed[msg.sender][milestone]) revert BadgeAlreadyClaimed();

        hasClaimed[msg.sender][milestone] = true;

        tokenId = _nextTokenId++;
        _badgeOwner[tokenId] = msg.sender;
        _badgeMilestone[tokenId] = milestone;
        _badgeBalance[msg.sender] += 1;

        emit Transfer(address(0), msg.sender, tokenId);
        emit BadgeClaimed(msg.sender, milestone, tokenId);
    }

    function _isValidMilestone(uint256 milestone) internal pure returns (bool) {
        return milestone == MILESTONE_7 || milestone == MILESTONE_14 || milestone == MILESTONE_30;
    }

    // ------------------------------------------------------------------------
    // Views
    // ------------------------------------------------------------------------
    function hasBadge(address user, uint256 milestone) external view returns (bool) {
        return hasClaimed[user][milestone];
    }

    function badgeMilestone(uint256 tokenId) external view returns (uint256) {
        if (_badgeOwner[tokenId] == address(0)) revert TokenDoesNotExist();
        return _badgeMilestone[tokenId];
    }

    // ------------------------------------------------------------------------
    // Owner: emergency pause ONLY (see README.md "Owner Permissions")
    // ------------------------------------------------------------------------
    function pause() external onlyOwner {
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(msg.sender);
    }

    // ------------------------------------------------------------------------
    // Minimal ERC-721 (soulbound): transfers & approvals always revert
    // ------------------------------------------------------------------------
    function balanceOf(address account) external view returns (uint256) {
        return _badgeBalance[account];
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        address badgeOwner = _badgeOwner[tokenId];
        if (badgeOwner == address(0)) revert TokenDoesNotExist();
        return badgeOwner;
    }

    function approve(address /*to*/, uint256 /*tokenId*/) external pure {
        revert Soulbound();
    }

    function getApproved(uint256 /*tokenId*/) external pure returns (address) {
        return address(0);
    }

    function setApprovalForAll(address /*operator*/, bool /*approved*/) external pure {
        revert Soulbound();
    }

    function isApprovedForAll(address /*account*/, address /*operator*/) external pure returns (bool) {
        return false;
    }

    function transferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) external pure {
        revert Soulbound();
    }

    function safeTransferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/, bytes calldata /*data*/) external pure {
        revert Soulbound();
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC165
            || interfaceId == 0x80ac58cd // ERC721
            || interfaceId == 0x5b5e139f; // ERC721Metadata
    }

    // ------------------------------------------------------------------------
    // Metadata: fully on-chain JSON (base64 data URI) + on-chain SVG image
    // ------------------------------------------------------------------------
    function tokenURI(uint256 tokenId) external view returns (string memory) {
        if (_badgeOwner[tokenId] == address(0)) revert TokenDoesNotExist();
        uint256 milestone = _badgeMilestone[tokenId];

        string memory milestoneStr = _toString(milestone);
        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512">',
                '<rect width="512" height="512" rx="64" fill="#0b0e11"/>',
                '<circle cx="256" cy="256" r="150" fill="none" stroke="#f0b90b" stroke-width="12"/>',
                '<text x="256" y="232" font-family="sans-serif" font-size="96" font-weight="bold" fill="#f0b90b" text-anchor="middle">',
                milestoneStr,
                '</text>',
                '<text x="256" y="300" font-family="sans-serif" font-size="40" fill="#ffffff" text-anchor="middle">DAY STREAK</text>',
                '<text x="256" y="352" font-family="sans-serif" font-size="24" fill="#848e9c" text-anchor="middle">AGENT STREAK BADGE</text>',
                "</svg>"
            )
        );

        string memory json = string(
            abi.encodePacked(
                unicode'{"name":"Agent Streak Badge — ',
                milestoneStr,
                ' Days","description":"Soulbound badge awarded to an Agent ID holder for a ',
                milestoneStr,
                '-day daily check-in streak on Agent Streak. Non-transferable.","image":"data:image/svg+xml;base64,',
                Base64.encode(bytes(svg)),
                '","attributes":[{"trait_type":"Milestone","value":',
                milestoneStr,
                '},{"trait_type":"Streak Days","value":',
                milestoneStr,
                '},{"trait_type":"Soulbound","value":"Yes"}]}'
            )
        );

        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    // ------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// @notice Reject accidental BNB transfers: this contract never holds funds.
    receive() external payable {
        revert("AgentStreak: no funds accepted");
    }
}
