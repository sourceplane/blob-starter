import { beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";

// A minimal in-memory R2 bucket: what the routes need and nothing more.
const objects = new Map<string, { body: ArrayBuffer; contentType: string }>();
const store = {
  put: vi.fn(async (key: string, body: ArrayBuffer, opts: { httpMetadata: { contentType: string } }) => {
    objects.set(key, { body, contentType: opts.httpMetadata.contentType });
    return { key, size: body.byteLength };
  }),
  get: vi.fn(async (key: string) => {
    const o = objects.get(key);
    if (!o) return null;
    return {
      body: new Blob([o.body]).stream(),
      size: o.body.byteLength,
      httpEtag: '"etag"',
      httpMetadata: { contentType: o.contentType },
    };
  }),
};
vi.mock("@opennextjs/cloudflare", () => ({
  getCloudflareContext: async () => ({ env: { BLOB: store } }),
}));

beforeEach(() => {
  objects.clear();
  store.put.mockClear();
  store.get.mockClear();
});

describe("lib/blob/server", () => {
  it("accepts images only", async () => {
    const { isAllowedContentType } = await import("@/lib/blob/server");
    expect(isAllowedContentType("image/png")).toBe(true);
    expect(isAllowedContentType("image/webp")).toBe(true);
    expect(isAllowedContentType("application/pdf")).toBe(false);
    expect(isAllowedContentType(null)).toBe(false);
  });

  it("adds a random suffix before the extension, like Blob's addRandomSuffix", async () => {
    const { withRandomSuffix } = await import("@/lib/blob/server");
    expect(withRandomSuffix("photo.png", "abcdef12-3456-7890-abcd-ef1234567890")).toBe(
      "photo-abcdef1234567890abcdef1234567890".slice(0, 36) + ".png",
    );
    expect(withRandomSuffix("photo", "abc")).toBe("photo-abc");
    expect(withRandomSuffix("photo.png")).not.toBe(withRandomSuffix("photo.png"));
  });
});

describe("PUT /api/upload", () => {
  const put = async (init: { pathname?: string; type?: string; body?: BodyInit; length?: string }) => {
    const { PUT } = await import("@/app/api/upload/route");
    const url = new URL("https://app.example.com/api/upload");
    if (init.pathname) url.searchParams.set("pathname", init.pathname);
    const headers = new Headers();
    if (init.type) headers.set("content-type", init.type);
    if (init.length) headers.set("content-length", init.length);
    const req = new Request(url, { method: "PUT", headers, body: init.body ?? null, duplex: "half" } as RequestInit);
    return PUT(req);
  };

  it("rejects a missing pathname, a non-image and an oversized file", async () => {
    expect((await put({ type: "image/png", body: "x" })).status).toBe(400);
    expect((await put({ pathname: "a.pdf", type: "application/pdf", body: "x" })).status).toBe(400);
    const res = await put({ pathname: "a.png", type: "image/png", body: "x", length: String(51 * 1024 * 1024) });
    expect(res.status).toBe(400);
    expect(store.put).not.toHaveBeenCalled();
  });

  it("stores an image under a suffixed pathname and returns it", async () => {
    const res = await put({ pathname: "photo.png", type: "image/png", body: new Uint8Array([1, 2, 3]) });
    expect(res.status).toBe(200);
    const json = (await res.json()) as { pathname: string; contentType: string; size: number };
    expect(json.pathname).toMatch(/^photo-[0-9a-f]+\.png$/);
    expect(json.contentType).toBe("image/png");
    expect(json.size).toBe(3);
    expect(objects.has(json.pathname)).toBe(true);
  });
});

describe("GET /api/blob", () => {
  it("404s a pathname that is not in the bucket and 400s a missing one", async () => {
    const { GET } = await import("@/app/api/blob/route");
    expect((await GET(new NextRequest("https://app.example.com/api/blob"))).status).toBe(400);
    expect((await GET(new NextRequest("https://app.example.com/api/blob?pathname=nope.png"))).status).toBe(404);
  });

  it("streams a stored object with its content type", async () => {
    objects.set("photo-1.png", { body: new Uint8Array([9, 8, 7]).buffer, contentType: "image/png" });
    const { GET } = await import("@/app/api/blob/route");
    const res = await GET(new NextRequest("https://app.example.com/api/blob?pathname=photo-1.png"));
    expect(res.status).toBe(200);
    expect(res.headers.get("content-type")).toBe("image/png");
    expect(res.headers.get("x-content-type-options")).toBe("nosniff");
    expect(new Uint8Array(await res.arrayBuffer())).toEqual(new Uint8Array([9, 8, 7]));
  });
});
