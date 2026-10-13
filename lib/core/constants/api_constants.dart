// lib/core/constants/api_constants.dart
class ApiConstants {
  static const String openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );

  static const String oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: '',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  // 🌐 Web3 Social Impact Constants (Arbitrum Sepolia Testnet)
  static const String web3RpcUrl = String.fromEnvironment(
    'WEB3_RPC_URL',
    defaultValue: 'https://sepolia-rollup.arbitrum.io/rpc',
  );

  static const String impactContractAddress = String.fromEnvironment(
    'IMPACT_CONTRACT_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000', // سنحدثه فور نشر العقد
  );
}