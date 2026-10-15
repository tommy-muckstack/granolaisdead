// Drives the real app (production build, demo account) to capture product shots AND smoke-test the meeting-notes flow.
import fs from "node:fs"; import assert from "node:assert/strict";
import { withApp, demoPage, out } from "./shotlib.mjs";
const dir = out("granolaisdead"); const pub = new URL("../public/home/", import.meta.url).pathname; fs.mkdirSync(pub, { recursive: true });
const save = async (page, name) => { await page.screenshot({ path: `${dir}/${name}.png` }); fs.copyFileSync(`${dir}/${name}.png`, `${pub}${name}.png`); };
await withApp("granolaisdead", async ({ base, browser }) => {
  const { ctx, page } = await demoPage(browser, base, { w: 1440, h: 900 });
  await page.getByTestId("empty").waitFor(); await page.screenshot({ path: `${dir}/home-app-empty.png` });
  // blank note: enhance is disabled until there is something to enhance
  await page.getByTestId("empty").getByRole("button", { name: "New note" }).click(); await page.waitForURL(/\/app\/notes\//); assert.ok(await page.getByRole("button", { name: /Enhance notes/ }).isDisabled());
  await page.getByLabel("Note title").fill("Throwaway"); await page.getByLabel("My notes").fill("x"); assert.ok(await page.getByRole("button", { name: /Enhance notes/ }).isEnabled());
  // sample meeting
  await page.goto(base + "/app"); await page.getByRole("button", { name: "Try a sample meeting" }).click(); await page.waitForURL(/\/app\/notes\//);
  await page.getByLabel("My notes").waitFor(); assert.equal(await page.getByLabel("Note title").inputValue(), "Launch sync"); await page.waitForTimeout(400); await save(page, "notes");
  await page.getByRole("tab", { name: "Transcript" }).click(); await page.getByLabel("Transcript").waitFor(); assert.match(await page.getByLabel("Transcript").inputValue(), /Maya: Thanks for joining/); await page.waitForTimeout(300); await save(page, "transcript");
  // enhance
  await page.getByRole("button", { name: /✦ Enhance notes/ }).click(); await page.getByTestId("enhanced").waitFor();
  const mine = await page.locator('[data-mine="true"]').allInnerTexts(); assert.equal(mine.length, 4); assert.match(mine[0], /^Onboarding flow done, conversion up/);
  assert.ok((await page.locator('[data-mine="false"]').count()) >= 2, "transcript-derived lines are marked");
  const colors = await page.evaluate(() => [document.querySelector('[data-mine="true"]'), document.querySelector('[data-mine="false"]')].map(e => getComputedStyle(e).color)); assert.notEqual(colors[0], colors[1], "my lines and AI lines differ in color");
  assert.ok((await page.getByTestId("actions").locator("li").count()) >= 4); await page.waitForTimeout(300); await save(page, "enhanced");
  // tick an action, scroll to actions, persists across reload
  const first = page.getByTestId("actions").locator("li").first(); await first.getByRole("checkbox").check(); await first.scrollIntoViewIfNeeded(); await page.getByTestId("actions").scrollIntoViewIfNeeded(); await page.waitForTimeout(300); await save(page, "actions");
  assert.ok((await page.getByTestId("actions").locator("li.done").count()) === 1);
  assert.match(await page.getByTestId("actions").innerText(), /Priya/); assert.match(await page.getByTestId("actions").innerText(), /by thursday/i);
  // markdown export
  const href = await page.getByRole("link", { name: "Download .md" }).getAttribute("href"); const md = decodeURIComponent(href.split(",")[1]); assert.match(md, /^# Launch sync/); assert.match(md, /## Action items/); assert.match(md, /- \[ \] .*\(Priya\)/);
  // ask
  await page.getByLabel("Ask about this meeting").fill("Who is booking the legal review?"); await page.keyboard.press("Enter"); await page.getByTestId("chat").getByText(/Priya: Yes, I will book the legal review/).waitFor();
  await page.getByLabel("Ask about this meeting").fill("What about quantum entanglement budget?"); await page.keyboard.press("Enter"); await page.getByText("I couldn't find that in this meeting's notes or transcript.").waitFor(); await page.waitForTimeout(300);
  await page.getByLabel("Ask about this meeting").fill("Who is booking the legal review?"); await page.keyboard.press("Enter"); await page.waitForTimeout(200); await save(page, "ask");
  // reload keeps everything
  await page.reload(); await page.getByTestId("enhanced").waitFor(); assert.equal(await page.getByTestId("actions").locator("li.done").count(), 1, "ticked action persists");
  // template changes sections on re-enhance
  await page.getByLabel("Template").selectOption("standup"); await page.getByRole("button", { name: "Re-enhance" }).click(); await page.waitForTimeout(300); const heads = await page.locator(".gn__doc h2").allInnerTexts(); assert.ok(heads.some(h => /Yesterday|Today|Blockers/.test(h)), `standup sections: ${heads}`);
  // sidebar lists notes; delete
  assert.ok((await page.getByTestId("list").getByRole("link").count()) >= 2); page.once("dialog", d => d.accept()); await page.getByRole("button", { name: "Delete" }).click(); await page.waitForURL(/\/app$/);
  await page.getByRole("link", { name: /Throwaway/ }).waitFor(); await page.getByRole("link", { name: /Launch sync/ }).waitFor({ state: "detached", timeout: 3000 });
  // marketing + login
  const m = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage(); await m.goto(base + "/app"); await m.waitForURL(/\/login/);
  await m.goto(base); await m.waitForTimeout(500); await m.screenshot({ path: `${dir}/home-top.png` }); await m.screenshot({ path: `${dir}/home-full.png`, fullPage: true });
  await m.goto(base + "/#pricing"); await m.waitForTimeout(300); await m.screenshot({ path: `${dir}/home-pricing.png` }); await m.goto(base + "/login"); await m.waitForTimeout(300); await m.screenshot({ path: `${dir}/login.png` });
  console.log("granolaisdead shots + smoke OK");
}, {});
