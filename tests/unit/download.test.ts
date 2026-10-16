import { describe, it, expect } from "vitest";
import { GET } from "@/app/download/route";
import config from "@/next.config.mjs";

describe("/download", () => {
  it("307s to the latest GitHub release DMG", () => {
    const res = GET();
    expect(res.status).toBe(307);
    expect(res.headers.get("location")).toBe("https://github.com/tommy-muckstack/granolaisdead/releases/latest/download/GranolaIsDead.dmg");
  });
});

describe("old web-app URLs", () => {
  it("permanently redirect to the marketing page", async () => {
    const rules = await config.redirects();
    for (const source of ["/app", "/app/:path*", "/login", "/api/session/:path*"]) expect(rules).toContainEqual({ source, destination: "/", permanent: true });
  });
});
