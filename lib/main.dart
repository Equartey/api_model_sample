import 'dart:async';
import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_logging_cloudwatch/amplify_logging_cloudwatch.dart';
import 'package:flutter/material.dart';

import 'amplifyconfiguration.dart';
import 'amplifyconfiguration_logging.dart';
import 'models/ModelProvider.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AmplifyLogger().logLevel = LogLevel.verbose;
  await configureAmplify();
  runApp(const DebugApp());
}

Future<void> configureAmplify() async {
  final apiPlugin = AmplifyAPI(modelProvider: ModelProvider.instance);
  final authPlugin = AmplifyAuthCognito();
  await Amplify.addPlugins([
    apiPlugin,
    authPlugin,
  ]);

  final amplifyConfigWithLogging = AmplifyConfig.fromJson(
    jsonDecode(amplifyconfig) as Map<String, dynamic>,
  ).copyWith(
    logging: LoggingConfig.fromJson(
      jsonDecode(loggingconfig) as Map<String, dynamic>,
    ),
  );

  final config = const JsonEncoder().convert(amplifyConfigWithLogging.toJson());

  try {
    await Amplify.configure(config);
  } on AmplifyAlreadyConfiguredException {
    safePrint(
        'Tried to reconfigure Amplify; this can occur when your app restarts on Android.');
  } on Exception catch (e) {
    safePrint("Exception when configuring amplify: $e");
  }
}

class DebugApp extends StatelessWidget {
  const DebugApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      title: 'Debug App',
      theme: ThemeData.dark(),
      home: const MyList(),
    );
  }
}

class MyList extends StatefulWidget {
  const MyList({super.key});

  @override
  State<MyList> createState() => _MyListState();
}

class _MyListState extends State<MyList> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    _plugin.enable();
    WidgetsBinding.instance.addObserver(this);
    subscribe();
    listenToApiHub();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AmplifyLogger('API').log(LogLevel.verbose, 'AppLifecycleState: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        // Todo: fetch data for missed messages
        subscribe();
        break;
      case AppLifecycleState.paused:
        // case AppLifecycleState.detached:
        // unsubscribe anytime when the app is not in the foreground
        unsubscribe();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unsubscribe();
    super.dispose();
  }

  StreamSubscription<GraphQLResponse<Item>>? _itemsSubscription;
  final _plugin = AmplifyLogger().getPlugin<AmplifyCloudWatchLoggerPlugin>()!;

  List<Item> itemsList = [];
  String _hubConnectionStatus = "";
  final subscriptionRequest = ModelSubscriptions.onCreate(
      Item.classType); // move me out of subscribe function

  void subscribe() {
    safePrint('Subscribing...');
    final Stream<GraphQLResponse<Item>> operation = Amplify.API.subscribe(
      subscriptionRequest,
      onEstablished: () => safePrint('Subscription established'),
    );
    _itemsSubscription ??= operation.listen(
      (event) {
        safePrint('Subscription event data received: ${event.data}');
        if (event.data != null) {
          if (mounted) {
            setState(() {
              itemsList.insert(0, event.data!);
            });
          }
        }
      },
      onError: (Object e) =>
          scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(
          "Error in stream: ${e.toString()}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
      )),
    );
  }

  void listenToApiHub() {
    Amplify.Hub.listen(HubChannel.Api, (event) {
      if (event is SubscriptionHubEvent) {
        if (mounted) {
          setState(() {
            _hubConnectionStatus = event.status.name;
          });
        }
      }
    });
  }

  Future<void> unsubscribe() async {
    await _itemsSubscription?.cancel();
    _itemsSubscription = null;
  }

  void mimicAppOffAndOn({required int count}) async {
    for (var i = 0; i < count; i++) {
      unsubscribe();
      subscribe();
    }
  }

  Future<void> createItem() async {
    final item = Item();
    final req = ModelMutations.create(item);

    final response = await Amplify.API.mutate(request: req).response;

    safePrint('Mutation result: ${response}');
  }

  void _flushLogs() {
    _plugin.flushLogs();
  }

  void _poke() {
    AmplifyLogger('API').log(LogLevel.verbose, 'Hello World!');
  }

  @override
  Widget build(BuildContext context) {
    return Authenticator(
      child: MaterialApp(
        builder: Authenticator.builder(),
        home: Scaffold(
          persistentFooterButtons: [
            FloatingActionButton(
              onPressed: () => _poke(),
              backgroundColor: Colors.amber,
              child: const Text("poke"),
            ),
            FloatingActionButton(
              onPressed: () => _flushLogs(),
              backgroundColor: Colors.amber,
              child: const Text("Flush"),
            ),
            FloatingActionButton(
              onPressed: () => createItem(),
              backgroundColor: Colors.green,
              child: const Text("Create"),
            ),
            FloatingActionButton(
              onPressed: () => subscribe(),
              backgroundColor: Colors.blue,
              child: const Text("subscribe"),
            ),
            FloatingActionButton(
              onPressed: () => mimicAppOffAndOn(count: 3),
              backgroundColor: Colors.blue,
              child: const Text("Mimic"),
            ),
            FloatingActionButton(
              onPressed: unsubscribe,
              backgroundColor: Colors.red,
              child: const Text("Unsubscribe"),
            ),
          ],
          body: Column(
            children: [
              Text(
                "Connection Status: $_hubConnectionStatus",
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(
                height: 20,
              ),
              Expanded(
                  child: ListView.builder(
                itemBuilder: (context, index) => ListTile(
                  title: Text(
                    itemsList[index].id,
                  ),
                ),
                itemCount: itemsList.length,
              ))
            ],
          ),
        ),
      ),
    );
  }
}
