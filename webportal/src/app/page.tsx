"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { QRCodeCanvas } from "qrcode.react";
import styles from "./portal.module.css";

type PairingStart = {
  pairingId: string;
  expiresAt: string;
  qrPayload: string;
};

type PairingStatus = {
  status: "pending" | "claimed" | "expired" | "missing";
  deviceId?: string;
};

export default function Home() {
  const router = useRouter();
  const [pairing, setPairing] = useState<PairingStart | null>(null);
  const [pairingStatus, setPairingStatus] = useState<string>("Ready");
  const [pairingError, setPairingError] = useState<string>("");
  const [pin, setPin] = useState<string>("");
  const [pinStatus, setPinStatus] = useState<string>("Enter PIN");
  const [pinError, setPinError] = useState<string>("");

  async function startPairing() {
    setPairingError("");
    setPairingStatus("Generating QR");
    setPairing(null);

    try {
      const response = await fetch("/api/pairing/start", {
        method: "POST",
      });

      if (!response.ok) {
        let message = "Failed to create a pairing session.";
        try {
          const data = (await response.json()) as { error?: string };
          if (data.error) {
            message = data.error;
          }
        } catch {
          // Ignore JSON parsing errors and fall back to the default message.
        }
        setPairingError(message);
        setPairingStatus("Error");
        return;
      }

      const payload = (await response.json()) as PairingStart;
      setPairing(payload);
      setPairingStatus("Waiting for scan");
    } catch {
      setPairingError("Failed to reach the pairing service.");
      setPairingStatus("Offline");
    }
  }

  async function verifyPin() {
    setPinError("");
    setPinStatus("Verifying");

    const response = await fetch("/api/pin/verify", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ pin }),
    });

    if (!response.ok) {
      let message = "Invalid PIN. Try again.";
      try {
        const payload = (await response.json()) as { error?: string };
        if (payload.error) {
          message = payload.error;
        }
      } catch {
        // Ignore JSON parsing errors and fall back to the default message.
      }
      setPinError(message);
      setPinStatus("Enter PIN");
      return;
    }

    const payload = (await response.json()) as { deviceId?: string };
    const deviceId = payload.deviceId?.toString().trim() ?? "";
    if (!deviceId) {
      setPinError("Unable to resolve a device for this PIN.");
      setPinStatus("Enter PIN");
      return;
    }

    setPinStatus("Unlocked");
    router.push(`/p/${deviceId}`);
  }

  useEffect(() => {
    if (!pairing) {
      return;
    }

    const interval = setInterval(async () => {
      try {
        const response = await fetch(`/api/pairing/status?pairingId=${pairing.pairingId}`);
        if (!response.ok) {
          return;
        }
        const data = (await response.json()) as PairingStatus;
        if (data.status == "claimed" && data.deviceId) {
          setPairingStatus("Paired");
        }
        if (data.status == "expired") {
          setPairingStatus("Expired");
        }
      } catch {
        setPairingStatus("Offline");
      }
    }, 2000);

    return () => clearInterval(interval);
  }, [pairing]);

  return (
    <div className={styles.page}>
      <div className={styles.shell}>
        <div className={styles.topBar}>
          <div className={styles.brand}>
            <div className={styles.title}>SMS Portal</div>
            <div className={styles.subtitle}>
              Enter your PIN to unlock messages or pair a phone.
            </div>
          </div>
          <div className={styles.statusPill}>{pairing ? pairingStatus : "Ready"}</div>
        </div>

        <div className={styles.grid}>
          <section className={styles.card}>
            <div className={styles.cardTitle}>Unlock messages</div>
            <div className={styles.helper}>
              Enter the 8-digit PIN shown on your phone to unlock messages.
            </div>
            <input
              className={styles.input}
              value={pin}
              onChange={(event) => setPin(event.target.value.replace(/\D/g, ""))}
              placeholder="8-digit PIN"
              inputMode="numeric"
              maxLength={8}
            />
            <div className={styles.actions}>
              <button className={styles.button} type="button" onClick={verifyPin}>
                Unlock messages
              </button>
            </div>
            {pinError ? <div className={styles.helper}>{pinError}</div> : null}
            <div className={styles.helper}>{pinStatus}</div>
          </section>

          <section className={`${styles.card} ${styles.cardMuted}`}>
            <div className={styles.cardTitle}>Pair a phone</div>
            <div className={styles.helper}>
              Scan the QR code on your phone to generate a new PIN.
            </div>

            <div className={styles.qrBox}>
              {pairing ? (
                <QRCodeCanvas value={pairing.qrPayload} size={220} />
              ) : (
                <div className={styles.helper}>Tap “Pair a phone” to start.</div>
              )}
            </div>

            {pairing ? (
              <p className={styles.helper}>
                Pairing code: <span className={styles.code}>{pairing.pairingId}</span>
              </p>
            ) : null}

            {pairingStatus === "Paired" ? (
              <div className={styles.helper}>Paired. Enter the PIN on the left.</div>
            ) : null}

            <div className={styles.actions}>
              <button className={styles.button} type="button" onClick={startPairing}>
                {pairing ? "Refresh QR" : "Pair a phone"}
              </button>
            </div>
            {pairingError ? <p className={styles.helper}>{pairingError}</p> : null}
          </section>
        </div>
      </div>
    </div>
  );
}
