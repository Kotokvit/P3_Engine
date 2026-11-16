#!/usr/bin/env python3
import urllib.request
import re

NOTEBOOK_ID = "08109264-caad-4605-b369-11f543c1ff62"
COOKIE_HEADER = 'SEARCH_SAMESITE=CgQIyaEB; SID=g.a000Bgk-U4Zp3qjYcdclXhQLkVqlR6B8bD7RCfqkjlRuBshvYlJG3HeTNP_Q9t3LDpDIodegEwACgYKARcSARUSFQHGX2MizCae12zLtk-G4lfmC7TPzxoVAUF8yKpoPFt-0fxHLRje3m7RmgRW0076; __Secure-1PSID=g.a000Bgk-U4Zp3qjYcdclXhQLkVqlR6B8bD7RCfqkjlRuBshvYlJGQRJlvkrovvm3peFmWEls2AACgYKARQSARUSFQHGX2Mih-at8OMGP0Q5-AqmiBrPJBoVAUF8yKpbJAdNMMiCvAcaHo25n-DA0076; __Secure-3PSID=g.a000Bgk-U4Zp3qjYcdclXhQLkVqlR6B8bD7RCfqkjlRuBshvYlJGOF33B9xwU9OdBRt0nIjPCAACgYKAfcSARUSFQHGX2MiYifQwJS8a98IwTiig-IvTxoVAUF8yKrVVcgq0xDLmoJCoISzTihP0076; HSID=AjUafVQ0-bmZQRY_U; SSID=AeQqjyZDkZzTPEGAN; APISID=RV6xtuQbT58U4rri/A_bV7rznZErnL7Owz; SAPISID=7fw4yaIekg0iRw-C/AAxyI8vsI4QZw8yM1; __Secure-1PAPISID=7fw4yaIekg0iRw-C/AAxyI8vsI4QZw8yM1; __Secure-3PAPISID=7fw4yaIekg0iRw-C/AAxyI8vsI4QZw8yM1; OSID=g.a000Bwk-U2j2vYh1Lt-Eu1r3YGza47yHaDPMB_TkSKYTc2MaG7H5yG0TLj84cBANWcEPawQ0GQACgYKAfMSARUSFQHGX2MiwW81eAJYNRPbLjRZn7wpSBoVAUF8yKovsMr3ySjrTFbOuEF7dGIX0076; __Secure-OSID=g.a000Bwk-U2j2vYh1Lt-Eu1r3YGza47yHaDPMB_TkSKYTc2MaG7H5fYNo2kiHkYPC9OyH3LdfuAACgYKAeQSARUSFQHGX2Mikg5ab5HTmct55Nb2dxDnVRoVAUF8yKp5dj3B0BS29D_ldWF06QsN0076; _gcl_au=1.1.1948553216.1787143027; AEC=AdJVEatqZqxNbWuVDKp9M9JYc8hXTkctykjDjAOr96YcDvsewhn8AyvYVg; NID=534=fzyn1GtJTqzzDT2Gir9FBfqBdypomOe2o_OzqY2sCW-gqbctu_3m08ImNAcSbHT9rX-O-r0TvV4dPs_NeNwx7NYviQLwP4G_0CRULARqbNVl8HzWWa0z6ct_-D6gzfyJ32jJA5BknZidCCvlBOGy0bT51AC8LErsVuBhZmcsexF8vKCcOSJUBfFpUxsCm5kVyGsq9yWXWKJtbFuHjNnFXs4hJdIRYzFdzsnHqogq_9BfCXDQ_7q_qCnpeLD5iv_zZ1rAE0c6WzzcS3o7u8u29zZ3X_So9dlTNZi4fomm28WCLudDicY9jeFxvJ1PUI4zsEGv_sr2_HeLeVUnb0tgBlpwsP6ixl4dNDH4usKWtDOa2wYQeQlXfQHDXFaW6IAhoxWre5OlkeomhyNPNa_BE5TOLieCAyKdu7NVAzlCAgnGWuicGCEs83SK2XPVXTcaW3e-OcSNngxi_mH6T9RSoYfT8u0DcRfRin9A5YCOdUrHjNVRyhWa3vYpK_k3zP-Yd_OsmAR5dfabvxt6CkB3JXl9ByLuUufZKXR0rF23sR4rgJy_4l8v5mK0Qb3S6C5PBKfL-OFQA2lnFaonwRbBkkv0VuTi-4BFtxf9HWtbJEaxk5ppkbQetkRr_nZwUBj1GvjX5N4cDT1wY4eUyhX6KimzI0Z7ZDXTQmzrInarLpeg6EqZLy_7rg0hW9g2wow4SPW4R5hjND18XPv1pC2DvTIZNUwFhk6hopTualGKqXEN4GKcGjjM9qFFjpMHJOK2k2FHkJCPWoc65cDcy6buqYqvGot1P32XgPp4r4W9Gpm9yPJjTQQ0GmLp6Ly_ajIo8xh8g4zBz4i8PmEEGEZOeL8KzFWAXrn0vP8nUH7j6Dj0gGGRDNJtT9WC16_mVZvCM8pResbK8_0ycGKOCQDc59qx-okoyi23wzHCFmFq1l-urb3AahhHdxhYov56o_lojXyag3I3VMdD4UsaQZe0FanIV9Fsfzd9osDX-n5rp8RcynwjbTPCpfpkpNtJ3FMfMZM-aLDBqd1SlWbgh_V2XPuE6IEkas5XNvdAOYACsQRcB8PNF3GSxRuYxquLTkAPiLSX7Pjk418DuaiGXFpkAtmuXUhmLB_Mtd7KE9r69rAGEmq6d71J6FmWjXJxUK21z0bSpLE9zdGMAqQqrm2zY555jcZ-QH3fcetiCZBqIDVgkSQ2W92fW2rWKOW2y-8kSp62M4M0o35RQPTT-_eRpinRDbZBzy4kHKadStWNzZtJRbGvXtIapFq-NV78zjxMjOcas5mTKB9wlFJaEuPU8NQw8bE5nCNC066NORxjQijGMFua4JaaQM2qHb_nRBQ7CzkmY_dyLQUT4phD4X7bK4bDwwrWlmzoDtA; _ga=GA1.1.1078215136.1787427311; _ga_W0LDH41ZCB=GS2.1.s1787427311$o1$g1$t1787427331$j40$l0$h0; __Secure-1PSIDTS=sidts-CjEBXMw41epjWaUHxQVrJ4hiafuHjWH1CGeFWApS7XZ__vSX02LNgJVV0e-hlrEgI-crEAA; __Secure-3PSIDTS=sidts-CjEBXMw41epjWaUHxQVrJ4hiafuHjWH1CGeFWApS7XZ__vSX02LNgJVV0e-hlrEgI-crEAA; SIDCC=AKEyXzV17yLb9DbMQSmOSoJyOvT5HFMTfirBNQcSLuR66e9fFcWnu4y7HJ-eFIdtuBbQog8uMGd0; __Secure-1PSIDCC=AKEyXzVnyO841v55XI3bvn9ayku2lj8BCJ95upQ0hX7bGAyMNXvw441A9ToPU7eF4VjvGqdplv0; __Secure-3PSIDCC=AKEyXzVscVkNIqBbgcot0ezkFvAYdv5G1csim0iWfNxg_GrDPjUavu1RIFuXPIZSM75xF_Idxhg'

url = f"https://notebook.google.com/notebook/{NOTEBOOK_ID}?authuser=1"
headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36",
    "Cookie": COOKIE_HEADER
}
req = urllib.request.Request(url, headers=headers)
with urllib.request.urlopen(req) as resp:
    html = resp.read().decode("utf-8", errors="ignore")
    # find at (X-Goog-Update) or SNlM0e or f.sid or similar
    matches = re.findall(r'"(FdrFJe|SNlM0e)":"(.*?)"', html)
    print("Found tokens:", matches)
    at_match = re.search(r'WIZ_global_data\s*=\s*(\{.*?\});', html)
    if at_match:
        print("Found WIZ_global_data!")
        wiz = at_match.group(1)
        for key in ["SNlM0e", "FdrFJe", "oBG7Re"]:
            m = re.search(rf'"{key}":"(.*?)"', wiz)
            if m:
                print(f"{key}: {m.group(1)}")
