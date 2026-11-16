#!/usr/bin/env python3
import sys
import asyncio
from playwright.async_api import async_playwright

NOTEBOOK_CANON = "08109264-caad-4605-b369-11f543c1ff62"
NOTEBOOK_POLER = "ed037bba-7b37-4291-8cf4-d2698036dbe3"

async def check_notebook(topic, notebook_id=NOTEBOOK_CANON):
    print(f"📖 [Пайплайн Крок 1] Запитуємо канон у NotebookLM...")
    async with async_playwright() as p:
        browser = await p.chromium.connect_over_cdp("http://localhost:9222")
        context = browser.contexts[0]
        page = None
        for p_item in context.pages:
            if notebook_id in p_item.url:
                page = p_item
                break
        if not page:
            page = await context.new_page()
            await page.goto(f"https://notebooklm.google.com/notebook/{notebook_id}?authuser=1")
            await page.wait_for_timeout(3000)
            
        await page.bring_to_front()
        
        # Exact chat selector
        chat_box = None
        for sel in ["textarea", "[contenteditable='true']", "input[placeholder*='вопрос']", "input[placeholder*='Спросите']"]:
            try:
                el = await page.wait_for_selector(sel, timeout=3000)
                if el and await el.is_visible():
                    chat_box = el
                    break
            except Exception:
                continue
                
        if not chat_box:
            inputs = await page.query_selector_all("textarea, input, [contenteditable='true']")
            for inp in inputs:
                if await inp.is_visible():
                    chat_box = inp
                    break
                    
        if chat_box:
            query = f"Какие точные расчеты, формулы, параметры и константы уже зафиксированы в каноне по теме: {topic}?"
            print(f"💬 Запит до канону: '{query}'")
            await chat_box.click()
            await chat_box.fill(query)
            await page.keyboard.press("Enter")
            print("⏳ Очікуємо відповідь (22 сек)...")
            await page.wait_for_timeout(22000)
            text = await page.inner_text("body")
            print("\n=== ВІДПОВІДЬ З NOTEBOOKLM ===")
            print(text[-3500:])
        else:
            print("Поле чату не знайдено.")

if __name__ == "__main__":
    t = sys.argv[1] if len(sys.argv) > 1 else "Печать Нокс, 5 когтей, адамантит и шунтирование энергии"
    asyncio.run(check_notebook(t))
