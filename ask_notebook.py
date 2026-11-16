#!/usr/bin/env python3
import sys
import asyncio
from playwright.async_api import async_playwright

async def ask_via_cdp(query_text):
    async with async_playwright() as p:
        print("🔌 Підключаємося до вашого відкритого Chromium через CDP (порт 9222)...")
        browser = await p.chromium.connect_over_cdp("http://localhost:9222")
        context = browser.contexts[0]
        pages = context.pages
        page = None
        for p_item in pages:
            if "notebook" in p_item.url:
                page = p_item
                break
                
        if not page:
            page = pages[0]
                
        print(f"📄 Активна сторінка: {page.url}")
        
        # NotebookLM chat input usually has aria-label or specific placeholder/class
        chat_box = None
        selectors = [
            "textarea",
            "[contenteditable='true']",
            "input[placeholder*='вопрос']",
            "input[placeholder*='Спросите']",
            "input[placeholder*='Ask']",
            ".query-input-field",
            "input"
        ]
        
        for sel in selectors:
            try:
                el = await page.wait_for_selector(sel, timeout=3000)
                if el and await el.is_visible():
                    chat_box = el
                    break
            except Exception:
                continue
                
        if not chat_box:
            # Fallback: find all text inputs and pick the main chat
            inputs = await page.query_selector_all("textarea, input, [contenteditable='true']")
            for inp in inputs:
                if await inp.is_visible():
                    chat_box = inp
                    break
                    
        if chat_box:
            print(f"💬 Відправляємо запит: '{query_text}'...")
            await chat_box.click()
            await chat_box.fill(query_text)
            await page.keyboard.press("Enter")
            
            print("⏳ Очікуємо відповідь від NotebookLM (25 сек)...")
            await page.wait_for_timeout(25000)
            
            text = await page.inner_text("body")
            print("\n=== ВІДПОВІДЬ NOTEBOOKLM ===")
            print(text[-3500:])
        else:
            print("Не вдалося знайти поле чату.")

if __name__ == "__main__":
    q = sys.argv[1] if len(sys.argv) > 1 else "що таке проэктивнеое многобразие P3"
    asyncio.run(ask_via_cdp(q))
