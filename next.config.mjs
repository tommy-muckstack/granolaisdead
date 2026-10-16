const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "/granolaisdead";
export default {
  basePath,
  env: { NEXT_PUBLIC_BASE_PATH: basePath },
  poweredByHeader: false,
  // The web app is gone (GranolaIsDead is a native Mac app now). Old app/login URLs land on the marketing page.
  async redirects() {
    return ["/app", "/app/:path*", "/login", "/api/session/:path*"].map((source) => ({ source, destination: "/", permanent: true }));
  },
};
