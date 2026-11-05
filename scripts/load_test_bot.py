#!/usr/bin/env python3
"""
Load Test Bot v2: Simulate 200 students completing an exam concurrently.
Uses Supabase Management API /database/query (bypasses REST auth entirely).
"""
import asyncio
import time
import json
import os
import aiohttp

SUPABASE_REF = "yukqngrtgevveimhrwke"
MGMT_TOKEN = "sbp_fce55249edfaabc241f23ea86e4fd406f5db52f6"
UJIAN_ID = "2e28c7b0-7b40-40e8-8399-33dd4c7e5ad1"
MGMT_URL = f"https://api.supabase.com/v1/projects/{SUPABASE_REF}/database/query"

HEADERS = {
    "Authorization": f"Bearer {MGMT_TOKEN}",
    "Content-Type": "application/json",
}

async def run_sql(session, sql, label=""):
    payload = {"query": sql}
    async with session.post(MGMT_URL, headers=HEADERS, json=payload) as resp:
        text = await resp.text()
        if resp.status not in (200, 201):
            return None, f"{label}: HTTP {resp.status} - {text[:200]}"
        try:
            return json.loads(text), None
        except Exception as e:
            return None, f"{label}: JSON parse error - {e}"

async def simulate_student(session, siswa_id, soal_ids, student_idx):
    start = time.time()
    errors = []

    # 1. Start exam
    start_sql = f"""
    INSERT INTO peserta_ujian (ujian_id, siswa_id, status, started_at, token_used)
    VALUES ('{UJIAN_ID}'::uuid, '{siswa_id}'::uuid, 'mengikuti', NOW(), 'BOT_TEST')
    ON CONFLICT (ujian_id, siswa_id) DO UPDATE SET status = 'mengikuti', token_used = 'BOT_TEST'
    RETURNING id;
    """
    result, err = await run_sql(session, start_sql, f"S{student_idx}-start")
    if err:
        errors.append(err)
        return {"status": "fail_start", "latency": time.time() - start, "errors": errors}

    peserta_id = result[0]["id"] if result else None
    if not peserta_id:
        errors.append(f"S{student_idx}: No peserta_id returned")
        return {"status": "fail_start", "latency": time.time() - start, "errors": errors}

    # 2. Batch insert answers
    answer_values = []
    for soal_id in soal_ids:
        answer_values.append(
            f"('{peserta_id}'::uuid, '{soal_id}'::uuid, 'A', false, 0, 'dijawab', NOW())"
        )
    values_str = ",\n".join(answer_values)
    answer_sql = f"""
    INSERT INTO jawaban_siswa (peserta_ujian_id, soal_id, jawaban, ragu_ragu, waktu_detik, status, updated_at)
    VALUES {values_str}
    ON CONFLICT (peserta_ujian_id, soal_id) DO UPDATE SET jawaban = 'A', ragu_ragu = false;
    """
    _, err = await run_sql(session, answer_sql, f"S{student_idx}-answers")
    if err:
        errors.append(err)

    # 3. Submit exam
    submit_sql = f"""
    UPDATE peserta_ujian
    SET status = 'selesai', finished_at = NOW()
    WHERE id = '{peserta_id}'::uuid
    RETURNING status;
    """
    result, err = await run_sql(session, submit_sql, f"S{student_idx}-submit")
    if err:
        errors.append(err)
        return {"status": "fail_submit", "latency": time.time() - start, "errors": errors}

    latency = time.time() - start
    status = "success" if not errors else "partial"
    return {"status": status, "latency": latency, "errors": errors}

async def main():
    print("=" * 60)
    print("LOAD TEST BOT v2 - Management API Direct SQL")
    print("=" * 60)

    # Concurrency limiter: max 20 simultaneous requests to avoid 429
    SEM_LIMIT = 20
    sem = asyncio.Semaphore(SEM_LIMIT)

    async def throttled_student(session, sid, soal_ids, idx):
        async with sem:
            return await simulate_student(session, sid, soal_ids, idx)

    async with aiohttp.ClientSession() as session:
        fetch_sql = f"""
        SELECT s.id as siswa_id
        FROM siswa s
        JOIN peserta_ujian pu ON pu.siswa_id = s.id
        WHERE pu.ujian_id = '{UJIAN_ID}'::uuid AND s.aktive_ok = true
        LIMIT 200;
        """
        result, err = await run_sql(session, fetch_sql, "fetch-peserta")
        if err or not result:
            print(f"FATAL: Cannot fetch peserta: {err}")
            return

        siswa_ids = [r["siswa_id"] for r in result]
        print(f"Peserta loaded: {len(siswa_ids)} students")

        soal_sql = f"""
        SELECT unnest(soal_list) as soal_id
        FROM ujian WHERE id = '{UJIAN_ID}'::uuid;
        """
        result, err = await run_sql(session, soal_sql, "fetch-soal")
        if err or not result:
            print(f"FATAL: Cannot fetch soal: {err}")
            return

        soal_ids = [r["soal_id"] for r in result]
        print(f"Soal loaded: {len(soal_ids)} questions per student")
        print(f"Total ops: {len(siswa_ids)} x {len(soal_ids)} = {len(siswa_ids) * len(soal_ids)} answer inserts")
        print("-" * 60)
        print("Starting concurrent load test...")
        print()

        start_total = time.time()
        tasks = [throttled_student(session, sid, soal_ids, i) for i, sid in enumerate(siswa_ids)]
        results = await asyncio.gather(*tasks, return_exceptions=True)
        total_time = time.time() - start_total

        success = sum(1 for r in results if isinstance(r, dict) and r.get("status") == "success")
        partial = sum(1 for r in results if isinstance(r, dict) and r.get("status") == "partial")
        failed = sum(1 for r in results if isinstance(r, dict) and r.get("status", "").startswith("fail"))
        exceptions = sum(1 for r in results if not isinstance(r, dict))
        latencies = [r["latency"] for r in results if isinstance(r, dict) and "latency" in r]

        avg_lat = sum(latencies) / len(latencies) if latencies else 0
        max_lat = max(latencies) if latencies else 0
        min_lat = min(latencies) if latencies else 0
        p95_lat = sorted(latencies)[int(len(latencies) * 0.95)] if latencies else 0

        print("=" * 60)
        print("LOAD TEST RESULTS")
        print("=" * 60)
        print(f"Students: {len(siswa_ids)}")
        print(f"Success: {success}")
        print(f"Partial: {partial}")
        print(f"Failed: {failed}")
        print(f"Exceptions: {exceptions}")
        print(f"Total Time: {total_time:.2f}s")
        print(f"Avg Latency: {avg_lat:.2f}s")
        print(f"Min Latency: {min_lat:.2f}s")
        print(f"P95 Latency: {p95_lat:.2f}s")
        print(f"Max Latency: {max_lat:.2f}s")
        print(f"Throughput: {len(siswa_ids)/total_time:.2f} students/sec")
        print(f"Answer Inserts: {len(siswa_ids)*len(soal_ids)} in {total_time:.2f}s ({len(siswa_ids)*len(soal_ids)/total_time:.1f} ops/sec)")
        print("=" * 60)

        error_samples = []
        for i, r in enumerate(results):
            if isinstance(r, dict) and r.get("errors"):
                error_samples.append((i, r["errors"]))
            elif not isinstance(r, dict):
                error_samples.append((i, [str(r)]))
        if error_samples:
            print("\nSample errors (first 5):")
            for idx, errs in error_samples[:5]:
                print(f"  Student {idx}: {'; '.join(str(e)[:120] for e in errs)}")

if __name__ == "__main__":
    asyncio.run(main())