import 'package:tgsorter/app/features/auth/ports/auth_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart';
import 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart';
import 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart';
import 'package:tgsorter/app/services/td_connection_state.dart';

export 'package:tgsorter/app/features/pipeline/ports/classify_gateway.dart'
    show ClassifyGateway, ClassifyReceipt;
export 'package:tgsorter/app/features/pipeline/ports/media_gateway.dart'
    show MediaGateway;
export 'package:tgsorter/app/features/pipeline/ports/message_read_gateway.dart'
    show MessageReadGateway;
export 'package:tgsorter/app/features/pipeline/ports/recovery_gateway.dart'
    show RecoveryGateway, ClassifyRecoverySummary, RecoverableClassifyGateway;
export 'package:tgsorter/app/features/settings/ports/session_query_gateway.dart'
    show SessionQueryGateway, SelectableChat;

/// 过渡期保留的聚合网关，后续将逐步由 capability interface 替代。
abstract class TelegramGateway
    implements
        AuthGateway,
        SessionQueryGateway,
        MessageReadGateway,
        MediaGateway,
        ClassifyGateway,
        RecoveryGateway {
  Stream<TdConnectionState> get connectionStates;
}
