import asyncio
import shutil
from pathlib import Path

from playwright.async_api import Page, async_playwright, expect

BASE_URL = "http://localhost:8000"
DEFAULT_TIMEOUT = 10000  # 10 seconds in ms
SCREENSHOT_PATH = "test_screenshots"


async def test_dashboard_cards(page: Page) -> None:
    await page.goto(f"{BASE_URL}/", timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Active Agents")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Running Tasks")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Cracked Hashes (24h)")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Resource Usage")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.locator(".text-2xl.font-semibold.text-gray-900")).to_have_count(
        3, timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("View all agents")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("View all tasks")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("View all results")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("View metrics")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await page.screenshot(path=f"{SCREENSHOT_PATH}/dashboard_cards.png")


async def test_recent_activity(page: Page) -> None:
    await page.goto(f"{BASE_URL}/", timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Recent Activity")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(
        page.get_by_text("Latest events from agents and tasks.")
    ).to_be_visible(timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Time", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Event", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Details", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await page.screenshot(path=f"{SCREENSHOT_PATH}/recent_activity.png")


async def test_active_tasks(page: Page) -> None:
    await page.goto(f"{BASE_URL}/", timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Active Tasks")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(
        page.get_by_text("Currently running password cracking tasks.")
    ).to_be_visible(timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Task", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Agent", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Progress", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("ETA", exact=True)).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await page.screenshot(path=f"{SCREENSHOT_PATH}/active_tasks.png")


async def test_attack_editor_modal(page: Page) -> None:
    await page.goto(f"{BASE_URL}/attacks/editor-modal", timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("New Attack")).to_be_visible(timeout=DEFAULT_TIMEOUT)
    await expect(page.locator("#attack-editor-form")).to_be_visible(
        timeout=DEFAULT_TIMEOUT
    )
    await expect(page.get_by_text("Attack Mode")).to_be_visible(timeout=DEFAULT_TIMEOUT)
    attack_mode_dropdown = page.get_by_label("Attack Mode")
    await expect(attack_mode_dropdown).to_be_visible(timeout=DEFAULT_TIMEOUT)
    dropdown_html = await attack_mode_dropdown.inner_html()
    assert "Dictionary" in dropdown_html
    assert "Mask" in dropdown_html
    assert "Brute Force" in dropdown_html
    await expect(page.get_by_text("Save Attack")).to_be_visible(timeout=DEFAULT_TIMEOUT)
    await expect(page.get_by_text("Cancel")).to_be_visible(timeout=DEFAULT_TIMEOUT)
    await page.screenshot(path=f"{SCREENSHOT_PATH}/attack_editor_modal.png")


async def run() -> None:
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        await test_dashboard_cards(page)
        await test_recent_activity(page)
        await test_active_tasks(page)
        await test_attack_editor_modal(page)
        await browser.close()


if __name__ == "__main__":
    if Path(SCREENSHOT_PATH).exists():
        shutil.rmtree(SCREENSHOT_PATH)
    Path(SCREENSHOT_PATH).mkdir(parents=True, exist_ok=True)
    asyncio.run(run())
