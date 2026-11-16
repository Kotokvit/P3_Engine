#!/usr/bin/env python3
import sys
import asyncio
import urllib.parse
from playwright.async_api import async_playwright

async def perform_search(query):
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://localhost:9222")
        context = browser.contexts[0]
        page = None
        for p_item in context.pages:
            if "google.com/search" in p_item.url or "google.com" in p_item.url:
                page = p_item
                break
        if not page:
            page = await context.new_page()
            
        print(f"🔍 Виконуємо пошук у вашому браузері: '{query}'...")
        encoded = urllib.parse.quote(query)
        await page.goto(f"https://www.google.com/search?q={encoded}", wait_until="domcontentloaded")
        await page.wait_for_timeout(3000)
        print("✅ Пошуковий запит відкрито на вашому екрані!")

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else "quaternion SO(3) RP3 projective manifold orbital resonance physics"
    asyncio.run(perform_search(q))
