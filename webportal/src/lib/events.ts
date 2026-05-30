const encoder = new TextEncoder();

type Controller = ReadableStreamDefaultController<Uint8Array>;

type EventBus = {
  listeners: Map<string, Set<Controller>>;
};

function getBus(): EventBus {
  const globalBus = (globalThis as { __portalEventBus?: EventBus }).__portalEventBus;
  if (globalBus) {
    return globalBus;
  }

  const bus: EventBus = {
    listeners: new Map(),
  };
  (globalThis as { __portalEventBus?: EventBus }).__portalEventBus = bus;
  return bus;
}

export function subscribe(deviceId: string, controller: Controller): () => void {
  const bus = getBus();
  const set = bus.listeners.get(deviceId) ?? new Set();
  set.add(controller);
  bus.listeners.set(deviceId, set);

  return () => {
    const current = bus.listeners.get(deviceId);
    if (!current) {
      return;
    }
    current.delete(controller);
    if (current.size == 0) {
      bus.listeners.delete(deviceId);
    }
  };
}

export function publishMessage(deviceId: string, payload: unknown): void {
  const bus = getBus();
  const listeners = bus.listeners.get(deviceId);
  if (!listeners) {
    return;
  }

  const message = `event: message\ndata: ${JSON.stringify(payload)}\n\n`;
  const data = encoder.encode(message);

  for (const listener of listeners) {
    try {
      listener.enqueue(data);
    } catch {
      // ignore broken connections
    }
  }
}

export function publishStatus(deviceId: string, payload: unknown): void {
  const bus = getBus();
  const listeners = bus.listeners.get(deviceId);
  if (!listeners) {
    return;
  }

  const message = `event: status\ndata: ${JSON.stringify(payload)}\n\n`;
  const data = encoder.encode(message);

  for (const listener of listeners) {
    try {
      listener.enqueue(data);
    } catch {
      // ignore broken connections
    }
  }
}

export function ssePing(controller: Controller): void {
  controller.enqueue(encoder.encode("event: ping\ndata: {}\n\n"));
}
