import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_service.dart';
import 'core/app_router.dart';
import 'core/session_service.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = SessionService();
  await session.load();
  runApp(WorkflowIaApp(session: session));
}

class WorkflowIaApp extends StatelessWidget {
  final SessionService session;
  const WorkflowIaApp({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionService>.value(value: session),
        Provider<ApiService>(create: (_) => ApiService(() => session.token)),
      ],
      child: Builder(
        builder: (context) {
          final router = buildRouter(session);
          return MaterialApp.router(
            title: 'Workflow IA',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
