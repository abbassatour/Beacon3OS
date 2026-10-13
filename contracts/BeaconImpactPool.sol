// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title BeaconImpactPool
 * @notice Sovereign Public Goods & Emergency Attestation Contract for BeaconOS
 * @dev Deployed on Arbitrum Sepolia L2 for sub-cent, ultra-fast social good transactions
 */
contract BeaconImpactPool {
    address public owner;
    uint256 public totalFundsSponsored;
    uint256 public totalSosAttestations;
    uint256 public totalAiQueriesSubsidized;

    // Events for Indexers, Block Explorers & Hackathon Judges
    event PoolSponsored(address indexed sponsor, uint256 amountWei, uint256 timestamp);
    event AiInferenceSubsidized(address indexed user, string featureType, uint256 timestamp);
    event EmergencySosAttested(
        address indexed user,
        int64 latitudeE6,
        int64 longitudeE6,
        uint8 batteryLevel,
        uint256 timestamp
    );

    mapping(address => uint256) public userSubsidies;
    mapping(address => uint256) public sponsorContributions;

    constructor() {
        owner = msg.sender;
    }

    /// @notice تبرع الداعمين لكفالة جلسات الذكاء الاصطناعي للمكفوفين
    function sponsorPool() external payable {
        require(msg.value > 0, "Sponsorship must be greater than 0");
        totalFundsSponsored += msg.value;
        sponsorContributions[msg.sender] += msg.value;
        emit PoolSponsored(msg.sender, msg.value, block.timestamp);
    }

    /// @notice إثبات الأثر: توثيق جلسة فحص كاميرا مدعومة من الصندوق
    function logAiInferenceImpact(string calldata featureType) external {
        totalAiQueriesSubsidized++;
        userSubsidies[msg.sender]++;
        emit AiInferenceSubsidized(msg.sender, featureType, block.timestamp);
    }

    /// @notice توثيق استغاثة طوارئ غير قابلة للتعديل أو الحذف من أي جهة
    function attestEmergencySos(
        int64 latitudeE6,
        int64 longitudeE6,
        uint8 batteryLevel
    ) external {
        totalSosAttestations++;
        emit EmergencySosAttested(
            msg.sender,
            latitudeE6,
            longitudeE6,
            batteryLevel,
            block.timestamp
        );
    }

    /// @notice استقبال التبرعات المباشرة للمحفظة
    receive() external payable {
        totalFundsSponsored += msg.value;
        sponsorContributions[msg.sender] += msg.value;
        emit PoolSponsored(msg.sender, msg.value, block.timestamp);
    }
}