// lib/core/services/web3_service.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart' as web3;

/// خدمة الـ Web3 السيادية لإدارة الهوية الرقمية اللامركزية (DID)
/// وتوثيق الاستغاثة ورعاية الذكاء الاصطناعي على شبكة Arbitrum Sepolia L2.
class Web3Service {
  Web3Service._();
  static final Web3Service instance = Web3Service._();

  web3.Web3Client? _client;
  web3.EthPrivateKey? _credentials;
  web3.DeployedContract? _impactContract;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// العنوان الست عشري القياسي بصيغة EIP-55 الصريحة
  String get walletAddressHex =>
      _credentials?.address.hexEip55 ??
      _credentials?.address.hex ??
      '0x0000000000000000000000000000000000000000';

  /// اسم مختصر للمحفظة لعرضه في شاشات الـ HUD وغرفة المعيشة
  String get shortAddress {
    final addr = walletAddressHex;
    if (addr.length < 10) return addr;
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
  }

  /// 🌐 معرّف الهوية اللامركزية القياسي W3C CAIP-10 DID لشبكة Arbitrum Sepolia (Chain ID: 421614)
  String get didIdentifier => 'did:pkh:eip155:421614:$walletAddressHex';

  /// تصدير المفتاح الخاص للمستخدم للنسخ الاحتياطي وإثبات السيادة الكاملة
  String? get privateKeyHex {
    if (_credentials == null) return null;
    return '0x${_credentials!.privateKeyInt.toRadixString(16).padLeft(64, '0')}';
  }

  // ABI المصغر الخاص بعقد الصندوق الاجتماعي BeaconImpactPool
  static const String _contractAbiJson = '''[
    {"inputs":[{"internalType":"int64","name":"latitudeE6","type":"int64"},{"internalType":"int64","name":"longitudeE6","type":"int64"},{"internalType":"uint8","name":"batteryLevel","type":"uint8"}],"name":"attestEmergencySos","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"sponsorPool","outputs":[],"stateMutability":"payable","type":"function"},
    {"inputs":[{"internalType":"string","name":"featureType","type":"string"}],"name":"logAiInferenceImpact","outputs":[],"stateMutability":"nonpayable","type":"function"},
    {"inputs":[],"name":"totalFundsSponsored","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"totalSosAttestations","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},
    {"inputs":[],"name":"totalAiQueriesSubsidized","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"}
  ]''';

  /// تهيئة المحفظة السيادية مع استرجاع المفتاح المحفوظ دائماً
  Future<void> initialize({
    String? explicitPrivateKeyHex,
  }) async {
    if (_isInitialized && explicitPrivateKeyHex == null) return;

    try {
      final httpClient = http.Client();
      _client = web3.Web3Client(ApiConstants.web3RpcUrl, httpClient);

      // 1. محاولة تحميل المفتاح الخاص المحفوظ مسبقاً في التخزين السيادي
      var storedKey = explicitPrivateKeyHex ?? await _loadStoredKey();

      if (storedKey == null || storedKey.trim().isEmpty) {
        // توليد هوية سيادية جديدة لأول مرة وحفظها دائماً
        final rng = math.Random.secure();
        final newCred = web3.EthPrivateKey.createRandom(rng);
        storedKey =
            '0x${newCred.privateKeyInt.toRadixString(16).padLeft(64, '0')}';

        await _persistKey(storedKey);
        _credentials = newCred;
        log('Web3Service: 🆕 Generated & Persisted NEW Sovereign DID: $walletAddressHex');
      } else {
        final cleanHex = storedKey.startsWith('0x')
            ? storedKey.substring(2)
            : storedKey;
        _credentials = web3.EthPrivateKey.fromHex(cleanHex);
        log('Web3Service: 🗝️ Restored PERSISTENT Sovereign DID: $walletAddressHex');
      }

      // 2. ربط العقد الذكي على شبكة Arbitrum Sepolia
      final contractAddress = ApiConstants.impactContractAddress.trim();
      if (contractAddress.isNotEmpty &&
          contractAddress != '0x0000000000000000000000000000000000000000') {
        _impactContract = web3.DeployedContract(
          web3.ContractAbi.fromJson(_contractAbiJson, 'BeaconImpactPool'),
          web3.EthereumAddress.fromHex(contractAddress),
        );
      }

      _isInitialized = true;
      log('Web3Service: Connected to Arbitrum Sepolia. DID: $didIdentifier');
    } catch (e, st) {
      log('Web3Service: Init error: $e', stackTrace: st);
    }
  }

  /// استيراد مفتاح خاص محدد
  Future<bool> importPrivateKey(String keyHex) async {
    try {
      final clean = keyHex.trim();
      final hexBody = clean.startsWith('0x') ? clean.substring(2) : clean;
      final newCred = web3.EthPrivateKey.fromHex(hexBody);

      final fullHex = '0x$hexBody';
      await _persistKey(fullHex);

      _credentials = newCred;
      log('Web3Service: 📥 Imported new Sovereign DID: $walletAddressHex');
      return true;
    } catch (e) {
      log('Web3Service: Failed to import private key: $e');
      return false;
    }
  }

  /// استرجاع المفتاح من الملف المحلي المحمي
  Future<String?> _loadStoredKey() async {
    try {
      final file = _getFallbackFile();
      if (file != null && await file.exists()) {
        final content = (await file.readAsString()).trim();
        if (content.isNotEmpty) {
          log('Web3Service: 📂 Loaded sovereign identity key from: ${file.path}');
          return content;
        }
      }
    } catch (e) {
      log('Web3Service: File key read note: $e');
    }
    return null;
  }

  /// حفظ المفتاح في الملف المحلي المحمي
  Future<void> _persistKey(String keyHex) async {
    try {
      final file = _getFallbackFile();
      if (file != null) {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await file.writeAsString(keyHex, flush: true);
        log('Web3Service: 💾 Successfully persisted sovereign identity key to: ${file.path}');
      }
    } catch (e) {
      log('Web3Service: File key write note: $e');
    }
  }

  /// تحديد مسار الملف الآمن ديناميكياً مع دعم جميع النكهات (Development, Staging, Production)
  File? _getFallbackFile() {
    try {
      if (Platform.isAndroid) {
        return _resolveAndroidKeyFile();
      } else if (Platform.isIOS) {
        final home = Platform.environment['HOME'] ?? '.';
        return File('$home/Documents/sovereign_identity.key');
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'] ?? '.';
        return File('$appData/BeaconOS/sovereign_identity.key');
      } else {
        final home = Platform.environment['HOME'] ?? '.';
        return File('$home/.beacon_os/sovereign_identity.key');
      }
    } catch (_) {
      return null;
    }
  }

  /// اكتشاف مسار التطبيق الفعلي على أندرويد بدقة دون الاعتماد على مسار ثابت
  File _resolveAndroidKeyFile() {
    String? packageName;
    try {
      final cmdline = File('/proc/self/cmdline');
      if (cmdline.existsSync()) {
        final content = cmdline.readAsStringSync();
        final parts = content.split('\x00');
        if (parts.isNotEmpty && parts.first.trim().isNotEmpty) {
          packageName = parts.first.trim();
        }
      }
    } catch (_) {}

    // فحص النكهات المحتملة بالترتيب
    final candidates = [
      if (packageName != null) packageName,
      'com.beaconos.beacon_os.dev',
      'com.beaconos.beacon_os.stg',
      'com.beaconos.beacon_os',
    ];

    for (final pkg in candidates) {
      // فحص مجلدات التطبيق الحقيقية التي يمتلك صلاحية الوصول إليها
      for (final subDir in ['files', 'app_flutter']) {
        final userDir = Directory('/data/user/0/$pkg/$subDir');
        if (userDir.existsSync()) {
          return File('${userDir.path}/sovereign_identity.key');
        }
        final dataDir = Directory('/data/data/$pkg/$subDir');
        if (dataDir.existsSync()) {
          return File('${dataDir.path}/sovereign_identity.key');
        }
      }
    }

    // إذا لم تكن المجلدات الفرعية قد أُنشئت بعد، نعتمد المجلد الأساسي للحزمة النشطة
    final targetPkg = packageName ?? 'com.beaconos.beacon_os.dev';
    return File('/data/user/0/$targetPkg/files/sovereign_identity.key');
  }

  /// جلب رصيد المحفظة بالـ ETH على شبكة Arbitrum Sepolia
  Future<double> getBalanceEth() async {
    if (!_isInitialized || _client == null || _credentials == null) return 0.0;
    try {
      final amount = await _client!.getBalance(_credentials!.address);
      return amount.getInWei.toDouble() / 1e18;
    } catch (e) {
      log('Web3Service: Error fetching balance: $e');
      return 0.0;
    }
  }

  /// توثيق استغاثة الطوارئ SOS على Arbitrum Sepolia
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
          web3.Transaction.callContract(
            contract: _impactContract!,
            function: function,
            parameters: [latE6, lngE6, batt],
          ),
          chainId: 421614,
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
          web3.Transaction.callContract(
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