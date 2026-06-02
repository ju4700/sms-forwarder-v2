"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import styles from "../../portal.module.css";

type Message = {
  id?: number;
  address: string;
  body: string;
  direction: "incoming" | "outgoing";
  sentAt: string;
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

export default function PortalPage() {
  const params = useParams<{ deviceId?: string | string[] }>();
  const deviceIdParam = params?.deviceId;
  const deviceId = Array.isArray(deviceIdParam)
    ? deviceIdParam[0] ?? ""
    : (deviceIdParam ?? "");
  const [authorized, setAuthorized] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [status, setStatus] = useState("Checking session");
  const [error, setError] = useState("");
  const [online, setOnline] = useState(true);

  const latestMessage = useMemo(() => messages[0], [messages]);

  async function fetchMessages(): Promise<boolean> {
    const response = await fetch(`/api/messages?deviceId=${deviceId}&limit=200`);
    if (!response.ok) {
      let message = "Enter your PIN on the main page to unlock messages.";
      try {
        const payload = (await response.json()) as { error?: string };
        if (payload.error && payload.error !== "unauthorized" && payload.error !== "forbidden") {
          message = payload.error;
        }
      } catch {
        // Ignore JSON parsing errors and fall back to the default message.
      }
      setError(message);
      return false;
    }

    const data = (await response.json()) as { messages: Message[] };
    setMessages(data.messages ?? []);
    return true;
  }

  useEffect(() => {
    let active = true;
    setError("");
    setStatus("Checking session");

    void (async () => {
      if (!deviceId) {
        setAuthorized(false);
        setStatus("Missing device id");
        setOnline(false);
        return;
      }
      // Sometimes the session cookie is set just before we land on this page.
      // Do a couple quick retries so we don't get stuck on the unlock screen.
      let ok = false;
      for (let attempt = 1; attempt <= 3; attempt++) {
        ok = await fetchMessages();
        if (ok) break;
        await new Promise((resolve) => setTimeout(resolve, attempt * 300));
      }
      if (!active) {
        return;
      }
      if (ok) {
        setAuthorized(true);
        setStatus("Connected");
        setOnline(true);
      } else {
        setAuthorized(false);
        setStatus("Enter PIN on the main page");
        setOnline(false);
      }
    })();

    return () => {
      active = false;
    };
  }, [deviceId]);

  useEffect(() => {
    if (!authorized) {
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
  }, [deviceId, authorized]);

  useEffect(() => {
    if (!authorized) {
      return;
    }

    const interval = setInterval(() => {
      void fetchMessages();
    }, 15000);

    return () => clearInterval(interval);
  }, [authorized]);

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

        {!authorized ? (
          <section className={styles.card}>
            <div className={styles.cardTitle}>Unlock required</div>
            <div className={styles.helper}>
              Enter your PIN on the main page to unlock this device.
            </div>
            <div className={styles.actions}>
              <a className={styles.button} href="/">
                Go to PIN entry
              </a>
            </div>
            {error ? <div className={styles.helper}>{error}</div> : null}
            <div className={styles.helper}>{status}</div>
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
