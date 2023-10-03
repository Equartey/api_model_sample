import 'dart:async';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';

import 'amplifyconfiguration.dart';
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
  try {
    await Amplify.configure(amplifyconfig);
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
    WidgetsBinding.instance.addObserver(this);
    subscribe();
    listenToApiHub();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        subscribe();
        break;
      case AppLifecycleState.paused:
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

  List<Item> itemsList = [];
  String _hubConnectionStatus = "";
  void subscribe() {
    final subscriptionRequest = ModelSubscriptions.onCreate(Item.classType);
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        persistentFooterButtons: [
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
              style: const TextStyle(color: Colors.white),
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
    );
  }
}
