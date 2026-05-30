"use client";

import { useEffect, useMemo, useState } from "react";
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
  const [pairing, setPairing] = useState<PairingStart | null>(null);
  const [deviceId, setDeviceId] = useState<string>("");
  const [status, setStatus] = useState<string>("Starting");
  const [error, setError] = useState<string>("");

  const portalLink = useMemo(() => {
    if (!deviceId) {
      return "";
    }
    return `/p/${deviceId}`;
  }, [deviceId]);

  async function startPairing() {
    setError("");
    setStatus("Generating QR");
    setDeviceId("");
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
        setError(message);
        setStatus("Error");
        return;
      }

      const payload = (await response.json()) as PairingStart;
      setPairing(payload);
      setStatus("Waiting for scan");
    } catch {
      setError("Failed to reach the pairing service.");
      setStatus("Offline");
    }
  }

  useEffect(() => {
    const saved = localStorage.getItem("portalDeviceId");
    if (saved) {
      setDeviceId(saved);
      setStatus("Previously paired");
    }
    void startPairing();
  }, []);

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
          setDeviceId(data.deviceId);
          localStorage.setItem("portalDeviceId", data.deviceId);
          setStatus("Paired");
        }
        if (data.status == "expired") {
          setStatus("Expired");
        }
      } catch {
        setStatus("Offline");
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
              Pair a phone to view messages securely in your browser.
            </div>
          </div>
          <div className={styles.statusPill}>{status}</div>
        </div>

        <div className={styles.grid}>
          <section className={styles.card}>
            <div className={styles.cardTitle}>1. Scan this QR code</div>
            <div className={styles.helper}>
              Open the Portal screen on your phone and scan the QR to pair.
            </div>

            <div className={styles.qrBox}>
              {pairing ? (
                <QRCodeCanvas value={pairing.qrPayload} size={220} />
              ) : (
                <div className={styles.helper}>Preparing QR code...</div>
              )}
            </div>

            {pairing ? (
              <p className={styles.helper}>
                Pairing code: <span className={styles.code}>{pairing.pairingId}</span>
              </p>
            ) : null}

            <div className={styles.actions}>
              <button className={styles.button} type="button" onClick={startPairing}>
                Refresh QR
              </button>
              {portalLink ? (
                <a className={`${styles.button} ${styles.buttonSecondary}`} href={portalLink}>
                  Open portal
                </a>
              ) : null}
            </div>
            {error ? <p className={styles.helper}>{error}</p> : null}
          </section>

          <section className={`${styles.card} ${styles.cardMuted}`}>
            <div className={styles.cardTitle}>2. Confirm PIN on device</div>
            <div className={styles.helper}>
              After pairing, the phone shows a PIN. You will need that PIN to
              access the messages.
            </div>

            {deviceId ? (
              <div className={styles.helper}>
                Device linked: <span className={styles.code}>{deviceId}</span>
              </div>
            ) : (
              <div className={styles.helper}>Waiting for device confirmation.</div>
            )}

            <div className={styles.actions}>
              <a
                className={`${styles.button} ${styles.buttonSecondary}`}
                href="https://support.google.com/android/answer/9777309"
                target="_blank"
                rel="noreferrer"
              >
                Battery tips
              </a>
            </div>
          </section>
        </div>
      </div>
    </div>
  );
}
