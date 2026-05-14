# SMS Forwarder

<img width="1000" height="1000" alt="SMS Forwarder" src="https://github.com/user-attachments/assets/168b8dc7-6d9e-4734-9a3c-a341ea242bf4" />

SMS Forwarder is a Flutter and Android SMS utility for capturing transaction messages, organizing them locally, and forwarding matched messages to a configured API endpoint.

## Features

- Capture incoming SMS messages on Android
- Forward only messages that match saved rules
- Keep a local inbox and conversation history
- View delivery logs and queue status
- Retry failed deliveries manually
- Configure transaction rules with template or regex filters
- Support a persistent foreground mode for stronger reliability

## Screens

- **Home**: configure endpoint, permissions, and delivery status
- **Messages**: view imported SMS inbox and conversations
- **Logs**: inspect forwarding history and delivery events
- **Policy**: view app policy information

## Requirements

- Android device or emulator
- SMS permissions granted
- Recommended: set the app as the default SMS app for best capture reliability
- A valid HTTPS API endpoint that accepts POST requests

## Installation

### From a release APK

1. Download the latest release APK.
2. Install it on your Android device.
3. Open the app and grant the required permissions.

### From source

```bash
flutter pub get
flutter build apk --release
```

## First-Time Setup

1. Open the app.
2. Grant SMS permissions when prompted.
3. Set your API endpoint on the **Home** screen.
4. Add or enable at least one capture rule on the **Messages** tab.
5. If needed, enable **Foreground reliability mode** for stronger background delivery.
6. Optionally set the app as your default SMS app for better capture behavior.

## How It Works

1. Incoming SMS messages are captured by Android.
2. The app checks your active rules.
3. Matching messages are queued for delivery.
4. The worker sends the parsed transaction data to your API endpoint.
5. Delivery status is shown in the app and in the logs.

## Rule Types

### Template rules

Use built-in templates for common transaction providers such as:

- bKash
- Rocket
- DBBL

### Regex rules

Use custom sender and body patterns when you need precise filtering.

## API Payload

Matched messages are sent as JSON using HTTP POST. The payload includes:

- schema version
- idempotency key
- sender number
- amount
- transaction ID
- reference
- local and UTC timestamps
- metadata such as fee, balance, and raw SMS text

## Reliability Notes

- Use **Foreground reliability mode** if you want stronger background behavior.
- Keep battery optimization disabled for best results.
- If a message is not forwarded, check the rule configuration and the logs.
- If the app is installed fresh, re-enter your API endpoint and re-check your rules.

## Manual Retry

If a message is still pending or failed, you can retry it from the **Home** screen using the per-message **Send** button.

## Building a Release APK

```bash
flutter build apk --release
```

The release APK will be created at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## License

This project is licensed under the BSD 3-Clause License. See [LICENSE](LICENSE) for details.

## Disclaimer

This project is intended for lawful personal or internal use. Make sure you have permission to capture and forward messages on any device where you install it.

## License

This project is licensed under the BSD 3-Clause License.
It is free to use, modify, and redistribute, while retaining the copyright and license notices.
