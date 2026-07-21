# <PRODUCT> — Integrasi Vendor Eksternal

> Kontrak SHAPE tiap layanan pihak-ketiga (pembayaran, email, kurir, pajak, dst).
> TANPA nilai secret — hanya NAMA env var. Entri diisi `add-integration` saat sebuah
> fitur butuh vendor baru (dipicu `fanout` → VENDOR NEW). Dibaca `plan` (promote kontrak),
> `security-critic` (baseline), `ship` (runbook deploy).
>
> Belum ada vendor — daftar tumbuh just-in-time lewat add-integration.
>
> Bentuk tiap entri (ditambah add-integration):
>
>     ## <vendor>
>     Arah         : outbound | inbound | both
>     Dipakai      : <ringkas; mis. proses pembayaran>
>     Endpoint     : <base URL pattern (outbound) / path webhook (inbound) — SHAPE, bukan rahasia>
>     Receiver app : <nama app dari apps[] yang menerima webhook — hanya bila Arah memuat inbound>
>     Idempotency  : <bentuk key; mis. header Idempotency-Key tiap request outbound>
>     Mode         : test | live (per environment)
>     Secret env   : <NAMA env var — tanpa nilai>
>     Retry        : <kebijakan; mis. backoff 3x>
>     Signature    : <algo verifikasi inbound; mis. HMAC-SHA256 — hanya bila inbound>
>     Wrapped by   : <package opsional yang membungkus vendor ini — opsional>
