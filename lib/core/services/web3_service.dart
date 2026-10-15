// lib/core/services/web3_service.dart
import 'dart:developer';
import 'dart:math' as math;
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';

/// خدمة الـ Web3 السيادية لإدارة الهوية وتوثيق الطوارئ على شبكة Arbitrum Sepolia
class Web3Service {
  Web3Service._();
  static final Web3Service instance = Web3Service._();

  Web3Client? _client;
  EthPrivateKey? _credentials;
  DeployedContract? _impactContract;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// العنوان الست عشري القياسي (EIP-55 Checksum Address)
  String get walletAddressHex =>
      _credentials?.address.hexEip55 ??
      '0x0000000000000000000000000000000000000000';

  String get shortAddress {
    final addr = walletAddressHex;
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  // ABI المصغر الخاص بعقد BeaconImpactPool
  static const String _contractAbiJson = '''[
    {"inputs":[{"internalType":"int64","name":"latitudeE6","type":"int64"},{"internalType":"int64","name":"longitudeE6","type":"int64"},{"internalType":"uint8","name":"batteryLevel","type":"uint8"}],"name":"attestEmergencySos","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"sponsorPool","outputs":[],"stateMutability":"payable","type":"function"},
    {"inputs":[{"internalType":"string","name":"featureType","type":"string"}],"name":"logAiInferenceImpact","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"totalFundsSponsored","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"totalSosAttestations","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"totalAiQueriesSubsidized","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
  ]''';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final httpClient = http.Client();
      _client = Web3Client(ApiConstants.web3RpcUrl, httpClient);

      // توليد مفتاح تشفير ذاتي للمحفظة السيادية (Sovereign Burner Wallet)
      final rng = math.Random.secure();
      _credentials = EthPrivateKey.createRandom(rng);

      if (ApiConstants.impactContractAddress.isNotEmpty &&
          ApiConstants.impactContractAddress !=
              '0x0000000000000000000000000000000000000000') {
        _impactContract = DeployedContract(
          ContractAbi.fromJson(_contractAbiJson, 'BeaconImpactPool'),
          EthereumAddress.fromHex(ApiConstants.impactContractAddress),
        );
      }

      _isInitialized = true;
      log('Web3Service: Connected to Arbitrum Sepolia. Wallet: $walletAddressHex');
    } catch (e, st) {
      log('Web3Service: Init error: $e', stackTrace: st);
    }
  }

  /// جلب رصيد المحفظة بالـ ETH على شبكة الاختبار
  Future<double> getBalanceEth() async {
    if (!_isInitialized || _client == null || _credentials == null) return 0.0;
    try {
      final amount = await _client!.getBalance(_credentials!.address);
      // التحويل الرياضي المباشر: 1 ETH = 10^18 Wei
      return amount.getInWei.toDouble() / 1e18;
    } catch (e) {
      log('Web3Service: Error fetching balance: $e');
      return 0.0;
    }
  }

  /// توثيق استغاثة الطوارئ على Arbitrum Sepolia (On-chain Attestation)
  Future<String?> attestEmergencySosOnChain({
    required double latitude,
    required double longitude,
    int batteryLevel = 100,
  }) async {
    log('Web3Service: 🛰️ Broadcasting on-chain SOS attestation to Arbitrum ($latitude, $longitude)...');
    try {
      if (_client != null && _credentials != null && _impactContract != null) {
        final function = _impactContract!.function('attestEmergencySos');
        final latE6 = BigInt.from((latitude * 1e6).round());
        final lngE6 = BigInt.from((longitude * 1e6).round());
        final batt = BigInt.from(batteryLevel);

        final txHash = await _client!.sendTransaction(
          _credentials!,
          Transaction.callContract(
            contract: _impactContract!,
            function: function,
            parameters: [latE6, lngE6, batt],
          ),
          chainId: 421614, // Arbitrum Sepolia Chain ID
        );
        log('Web3Service: ✅ SOS Attested On-Chain. Tx: $txHash');
        return txHash;
      } else {
        final simulatedTxHash =
            '0x${math.Random().nextInt(1000000).toRadixString(16).padLeft(64, 'e')}';
        log('Web3Service: Simulated On-chain Attestation: $simulatedTxHash');
        return simulatedTxHash;
      }
    } catch (e) {
      log('Web3Service: On-chain attestation warning (Non-blocking): $e');
      return null;
    }
  }

  /// توثيق استهلاك فحص الرؤية كـ Proof of Impact على شبكة Arbitrum Sepolia
  Future<void> logAiImpactOnChain(String featureType) async {
    log('Web3Service: 🛰️ Logging AI impact on-chain: $featureType');
    try {
      if (_client != null && _credentials != null && _impactContract != null) {
        final function = _impactContract!.function('logAiInferenceImpact');
        await _client!.sendTransaction(
          _credentials!,
          Transaction.callContract(
            contract: _impactContract!,
            function: function,
            parameters: [featureType],
          ),
          chainId: 421614,
        );
      }
    } catch (e) {
      log('Web3Service: logAiImpactOnChain warning (Non-blocking): $e');
    }
  }
}