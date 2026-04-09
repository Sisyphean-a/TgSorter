import 'package:tgsorter/app/services/td_auth_state.dart';

/// Pipeline 所需的最小授权状态能力接口（capability port）。
///
/// 注意：pipeline 只关心授权是否 ready，因此只暴露状态流，
/// 不应依赖包含 start/restart/submit 的完整 AuthGateway。
abstract class AuthStateGateway {
  Stream<TdAuthState> get authStates;
}
