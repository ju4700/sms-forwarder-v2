# Signed payment receipt protocol (v2)

This contract is implemented by the Android fork and Qabasic's `POST /api/payments/sms`. Provisioning and server-side verification are required; a forwarded JSON object alone must never approve an order.

## Provision a receiving device

Use a dedicated receiving-wallet phone/SIM. The configured wallet number binds the phone to your server registry; it is operator-provided, not SIM attestation. Only receiving bKash receipts are supported. Nagad remains manual.

Generate a random 32-byte secret as 64 hexadecimal characters, outside git:

```sh
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

In Qabasic's server environment, set:

```dotenv
BKASH_PERSONAL_NUMBER="YOUR_11_DIGIT_RECEIVING_NUMBER"
PAYMENT_SMS_DEVICES='[{"id":"payment-phone-1","secret":"YOUR_64_HEX_SECRET","provider":"bkash","receivingAccount":"YOUR_11_DIGIT_RECEIVING_NUMBER"}]'
PAYMENT_SMS_AUTO_APPROVE="off"
```

Use the same device ID, secret and receiving number in the Android app, with `https://YOUR_DOMAIN/api/payments/sms`. Never use `NEXT_PUBLIC_` variables for these secrets. The server rejects missing/malformed provisioning and wallet numbers that differ from the checkout receiving number.

Rotate secrets on both server and phone together. Revoke a device by removing it from the registry. Pending receipts cannot be relabeled to another device/wallet.

## Request authentication

Headers:

- `Content-Type: application/json; charset=utf-8`
- `X-Device-Id`: provisioned device ID.
- `X-Timestamp`: Unix time in **seconds**, decimal string; maximum clock difference five minutes.
- `X-Nonce`: a fresh UUID v4 for every HTTP attempt, including retries.
- `X-Signature: v1=<lowercase HMAC-SHA256 hex>`
- `X-Idempotency-Key`: lowercase SHA256 of `bkash|<receivingAccount>|<transactionId>`.

The HMAC key is the **UTF-8 text of the 64 hexadecimal secret characters**, not the hex-decoded bytes. Sign the following exact UTF-8 string, joined with LF and with **no trailing newline**:

```text
v1
POST
/api/payments/sms
<deviceId>
<timestamp>
<nonce>
<lowercase SHA256 hex of the exact HTTP body bytes>
```

The receiver must authenticate the original bytes before decoding JSON, compare signatures in constant time, and atomically reserve `(deviceId, nonce)` in shared durable storage. An idempotency key is not authentication. The same transaction delivered with a fresh nonce returns the stored receipt without duplicate fulfillment. A replayed nonce or conflicting transaction details returns 409.

HTTPS is mandatory on Android; credentials, query strings and fragments in endpoint URLs are rejected. The app never follows redirects. Keep the phone's clock synchronized.

## Payload

```json
{
  "schemaVersion": "2.0",
  "provider": "bkash",
  "currency": "BDT",
  "idempotencyKey": "<64 lowercase hex characters>",
  "transactionId": "DCI99TCKLX",
  "payerAccount": "01712345678",
  "amountMinor": 29900,
  "receivingAccount": "<provisioned receiving number>",
  "smsSender": "bKash",
  "receivedAt": 1791266460000,
  "paidAt": 1791266400000,
  "reference": "QB123",
  "rawSms": "You have received Tk 299.00 from 01712345678. Ref QB123. Fee Tk 0.00. Balance Tk 458.97. TrxID DCI99TCKLX at 06/10/2026 12:00"
}
```

Money is integer paisa (`29900 = BDT 299.00`). Event times are Unix **milliseconds**. SMS-local dates are interpreted in Asia/Dhaka (UTC+06:00). The raw receipt is reparsed on the server and every supplied field must agree. Request bodies are limited to 8 KiB; matching SMS text to 4 KiB. Sender addresses must equal bKash (case insensitive) or 16247. Complete incoming-credit formats only; outgoing payments/bills/embedded receipt text are rejected. Receipts outside the 48-hour ingestion window require manual wallet review.

The raw receipt text travels only to your configured server. Qabasic stores normalized fields and the receipt-text hash, without retaining raw SMS text, fee or balance. Application error responses/logs do not include financial query parameters.

## Approval behavior

With `PAYMENT_SMS_AUTO_APPROVE=off`, ingestion stores evidence and the admin payment queue displays matching receipts. Continue checking the wallet app before manual approval.

With `on`, automatic approval requires all of:

- A currently provisioned receiving device and matching configured wallet.
- Pending customer submission for the same provider/TrxID, payer number, actual received amount and BDT currency.
- Pending, unexpired order; receipt time within the order payment window (five-minute allowance for SMS minute precision).
- An unused receipt. Failed/rejected payments and closed/expired orders stay in manual review.

Receipt consumption, audit log, payment success, order payment, entitlements, gift codes and earnings commit in one database transaction. Conflicting or mismatched receipts do not overwrite evidence. The customer submission path also attempts matching, so either arrival order works.

Response 200 means the **receipt was accepted**; it does not necessarily mean an order was paid:

```json
{"success":true,"receiptId":"<uuid>","status":"received"}
```

`status` becomes `approved` after consumption. Delivery status on the phone describes delivery, not provider confirmation. 408/425/429/5xx and network failures retry with bounded backoff; other errors require operator attention. Long-press a failed receipt in the phone app to mark it handled **only after** resolving it manually in the wallet/store. This archives the local retry; it does not approve a server order.

Daily housekeeping removes nonce reservations older than one day and unmatched receipts older than seven days. Used financial evidence remains with the payment; payer numbers are masked during customer anonymization. Phone history retains at most 100 completed receipts for seven days. Unresolved receipts are not evicted.

## Deployment and validation

1. Apply the committed Qabasic migrations before deploying the new backend. The preview migrations are applied for tests; production rollout remains a separate operation.
2. Configure the server registry and keep automatic approval off.
3. Build with your protected release keystore and install on the receiving phone.
4. Check actual incoming receipt formats, wallet/SIM identity, signing, timezone and exact paisa values.
5. Validate online delivery, airplane-mode recovery, app background/kill/reboot, duplicate SMS/retries, wrong sender, outgoing payment and mismatched amount.
6. Compare accepted receipts with wallet transactions. Enable automatic approval only after the real-phone checks pass. Remove any device from the registry or set auto approval off to stop automation.

The automated tests cover parsing, signature parity between Kotlin/Node, authenticated encryption/tampering, concurrency/retention, HTTP validation, replay protection and database transaction rollback. They do not replace real device/carrier checks.

SMS labels and phone reports are not independent cryptographic proof from the wallet provider. Device compromise, carrier spoofing and incorrect provisioning remain outside this protocol's guarantees. Keep manual review and periodic wallet reconciliation available.
