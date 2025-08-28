// Minimal shims so editor doesn't complain if types aren't installed locally.
declare var process: { env: Record<string, string | undefined> };
declare var console: { log: (...args: any[]) => void; error: (...args: any[]) => void; warn: (...args: any[]) => void };

declare module 'firebase-functions' {
  const anyExport: any;
  export = anyExport;
}

declare module 'firebase-admin' {
  const anyExport: any;
  export = anyExport;
}

declare module 'firebase-admin/messaging' {
  const anyExport: any;
  export = anyExport;
}

declare module '@google-cloud/vertexai' {
  export const VertexAI: any;
}

declare module '@google-cloud/bigquery' {
  export class BigQuery { constructor(...args: any[]); dataset: any; dataset(id: string): any; }
}
