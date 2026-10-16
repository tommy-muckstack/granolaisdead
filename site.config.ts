// Site-wide constants for the GranolaIsDead marketing site. The product is the native Mac app in mac/; the website only links to it.
export const GH = "https://github.com/tommy-muckstack/granolaisdead";
/** Latest signed + notarized DMG on GitHub Releases (served via /download). */
export const DOWNLOAD_URL = `${GH}/releases/latest/download/GranolaIsDead.dmg`;
export const REQUIREMENTS = "macOS 14.2+ · Apple silicon & Intel · Free & open source";
export const site = {
  slug: "granolaisdead", name: "GranolaIsDead", replaces: "Granola", repo: GH,
  description: "A free, open-source Mac app for AI meeting notes. Records your mic and system audio without a meeting bot, transcribes on-device, and writes enhanced notes on your Mac. No account, no subscription.",
};

/** The /download route as a plain href (basePath included). Never a Next <Link>: prefetching it follows the 307 to GitHub. */
export const DL = `${process.env.NEXT_PUBLIC_BASE_PATH ?? "/granolaisdead"}/download`;
