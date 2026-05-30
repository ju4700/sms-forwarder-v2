"use client";

import { useEffect, useMemo, useState } from "react";
import styles from "../../portal.module.css";

type Message = {
  id?: number;
  address: string;
  body: string;
  direction: "incoming" | "outgoing";
  sentAt: string;
};

type Props = {
  params: {
    deviceId: string;
  };
};

function formatTime(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return new Intl.DateTimeFormat("en", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

export default function PortalPage({ params }: Props) {
  const deviceId = params.deviceId;
  const [pin, setPin] = useState("");
  const [verified, setVerified] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [status, setStatus] = useState("Enter PIN");
  const [error, setError] = useState("");
  const [online, setOnline] = useState(true);

  const latestMessage = useMemo(() => messages[0], [messages]);

  async function fetchMessages() {
    const response = await fetch(`/api/messages?deviceId=${deviceId}&limit=200`);
    if (!response.ok) {
      setError("Failed to load messages.");
      return;
    }

    const data = (await response.json()) as { messages: Message[] };
    setMessages(data.messages ?? []);
  }

  async function verifyPin() {
    setError("");
    setStatus("Verifying");

    const response = await fetch("/api/pin/verify", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ deviceId, pin }),
    });

    if (!response.ok) {
      setError("Invalid PIN. Try again.");
      setStatus("Enter PIN");
      return;
    }

    setVerified(true);
    setStatus("Connected");
    await fetchMessages();
  }

  useEffect(() => {
    if (!verified) {
      return;
    }

    const source = new EventSource(`/api/portal/stream?deviceId=${deviceId}`);

    const onMessage = (event: MessageEvent) => {
      try {
        const payload = JSON.parse(event.data) as Message;
        setMessages((current) => [payload, ...current]);
        setOnline(true);
      } catch {
        setOnline(false);
      }
    };

    const onStatus = (event: MessageEvent) => {
      try {
        const payload = JSON.parse(event.data) as { lastSeenAt?: string };
        if (payload.lastSeenAt) {
          setStatus(`Last seen ${formatTime(payload.lastSeenAt)}`);
        }
      } catch {
        return;
      }
    };

    source.addEventListener("message", onMessage);
    source.addEventListener("status", onStatus);
    source.onerror = () => setOnline(false);

    return () => {
      source.removeEventListener("message", onMessage);
      source.removeEventListener("status", onStatus);
      source.close();
    };
  }, [deviceId, verified]);

  useEffect(() => {
    if (!verified) {
      return;
    }

    const interval = setInterval(() => {
      void fetchMessages();
    }, 15000);

    return () => clearInterval(interval);
  }, [verified]);

  return (
    <div className={styles.page}>
      <div className={styles.shell}>
        <div className={styles.topBar}>
          <div className={styles.brand}>
            <div className={styles.title}>Portal Messages</div>
            <div className={styles.subtitle}>Device: {deviceId}</div>
          </div>
          <div className={styles.statusPill}>{online ? "Live" : "Offline"}</div>
        </div>

        {!verified ? (
          <section className={styles.card}>
            <div className={styles.cardTitle}>Enter your PIN</div>
            <div className={styles.helper}>
              The PIN appears on your phone after pairing.
            </div>
            <input
              className={styles.input}
              value={pin}
              onChange={(event) => setPin(event.target.value)}
              placeholder="6-digit PIN"
              inputMode="numeric"
            />
            <div className={styles.actions}>
              <button className={styles.button} onClick={verifyPin} type="button">
                Unlock messages
              </button>
            </div>
            {error ? <div className={styles.helper}>{error}</div> : null}
          </section>
        ) : (
          <section className={styles.card}>
            <div className={styles.cardTitle}>Messages</div>
            <div className={styles.helper}>{status}</div>

            {messages.length == 0 ? (
              <div className={styles.empty}>No messages yet.</div>
            ) : (
              <div className={styles.messageList}>
                {messages.map((message, index) => (
                  <div key={`${message.sentAt}-${index}`} className={styles.messageCard}>
                    <div className={styles.messageMeta}>
                      <span>{message.address}</span>
                      <span>{formatTime(message.sentAt)}</span>
                    </div>
                    <div className={styles.messageBody}>{message.body}</div>
                  </div>
                ))}
              </div>
            )}

            {latestMessage ? (
              <div className={styles.helper}>
                Latest message: {formatTime(latestMessage.sentAt)}
              </div>
            ) : null}
          </section>
        )}
      </div>
    </div>
  );
 }
