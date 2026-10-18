const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "/granolaisdead";
export default {
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  poweredByHeader: false,
  // The web app is gone (GranolaIsDead is a native Mac app now). Old app/login URLs land on the marketing page.
  async redirects() {
    return ["/app", "/app/:path*", "/login", "/api/session/:path*"].map((source) => ({ source, destination: "/", permanent: true }));
  },
  // PostHog reverse proxy (<basePath>/ingest → us.i.posthog.com) so ad blockers don't drop analytics.
  skipTrailingSlashRedirect: true,
  async rewrites() { return [{ source: "/ingest/static/:path*", destination: "https://us-assets.i.posthog.com/static/:path*" }, { source: "/ingest/:path*", destination: "https://us.i.posthog.com/:path*" }]; },
};
