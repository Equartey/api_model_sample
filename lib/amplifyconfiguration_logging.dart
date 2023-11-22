const loggingconfig = '''{
      "plugins": {
        "cloudWatchLoggerPluginConfiguration": {
            "enable": true,
            "logGroupName": "api-subscription-sample",
            "region": "us-west-2",
            "localStoreMaxSizeInMB": 5,
            "flushIntervalInSeconds": 60,
            "loggingConstraints": {
                "defaultLogLevel": "ERROR",
                "categoryLogLevel": {
                        "AUTH": "WARN",
                        "WebSocketService": "VERBOSE",
                        "WebSocketBloc": "VERBOSE",
                        "API": "VERBOSE"
                }
            }
        }
      }
}''';
