from aiohttp import web, ClientSession
import os
import asyncio
from tempfile import NamedTemporaryFile
from aiohttp_cors import setup as cors_setup, ResourceOptions
import concurrent.futures
import uuid

app = web.Application(client_max_size=1536 * 1024 * 1024)
# Configure CORS
cors = cors_setup(app, defaults={
    "*": ResourceOptions(
        allow_credentials=True,
        expose_headers="*",
        allow_headers="*",
        allow_methods="*"
    )
})
task_results = {}
processing_tasks = {}

# Create a custom thread pool
task_thread_pool = concurrent.futures.ThreadPoolExecutor(max_workers=4)
WORKER_URL = "http://127.0.0.1:8002/api/internal/process"

async def health_check(request):
    try:
        return web.json_response({
            'status': 'ok',
        })
    except Exception as e:
        return web.json_response({
            'status': 'error',
            'error': str(e)
        }, status=500)

async def process(request):
    try:
        reader = await request.multipart()
        audio_file_path = None
        task_id = None
        name = None
        original_filename = None
        model = None
        llm_url = None

        if not os.path.exists("audio"):
            os.makedirs("audio")

        while True:
            field = await reader.next()
            if field is None:
                break
            if field.name in ("audio", "file"):
                original_filename = field.filename
                # Save the file with a unique name
                file_extension = os.path.splitext(original_filename)[1] if original_filename else ".wav"
                temp_file_path = os.path.join("audio", f"{uuid.uuid4()}{file_extension}")
                with open(temp_file_path, 'wb') as f:
                    while True:
                        chunk = await field.read_chunk()
                        if not chunk:
                            break
                        f.write(chunk)
                audio_file_path = os.path.abspath(temp_file_path)
            elif field.name == "task_id":
                task_id = await field.text()
            elif field.name == "name":
                name = await field.text()
            elif field.name == "model":
                model = await field.text()
            elif field.name == "llmUrl":
                llm_url = await field.text()

        if not audio_file_path:
            return web.json_response({"error": "缺少音频文件", "code": "NO_AUDIO_FILE"}, status=400)
        
        final_task_id = task_id or name or original_filename or os.path.basename(audio_file_path)

        task_results[final_task_id] = {
            "status": "processing",
            "task_id": final_task_id,
            "original_filename": original_filename or os.path.basename(audio_file_path)
        }
        
        asyncio.create_task(call_worker(final_task_id, audio_file_path, model, llm_url))

        return web.json_response({
            "status": "success",
            "task_id": final_task_id,
            "original_filename": original_filename or os.path.basename(audio_file_path)
        })
    except Exception as e:
        return web.json_response({"error": str(e), "code": "PROCESS_ERROR"}, status=500)

async def call_worker(task_id, audio_file_path, model, llm_url):
    try:
        payload = {
            'audio_file_path': audio_file_path,
            'model': model,
            'llm_url': llm_url,
            'task_id': task_id
        }
        async with ClientSession() as session:
            async with session.post(WORKER_URL, json=payload) as response:
                if response.status == 200:
                    result = await response.json()
                    task_results[task_id] = {
                        "status": "completed",
                        "task_id": task_id,
                        "transcript": result.get("transcript"),
                        "summary": result.get("summary"),
                        "original_filename": task_results[task_id].get("original_filename")
                    }
                else:
                    error_text = await response.text()
                    raise Exception(f"Worker request failed with status {response.status}: {error_text}")
    except Exception as e:
        task_results[task_id] = {
            "status": "failed",
            "task_id": task_id,
            "error": str(e)
        }
    finally:
        if os.path.exists(audio_file_path):
            os.remove(audio_file_path)

async def task_status(request):
    try:
        task_id = request.query.get("task_id")
        result = task_results.get(task_id)
        if not result:
            return web.json_response({"status": "not_found", "error": "任务不存在", "code": "TASK_NOT_FOUND"},
                                     status=404)
        return web.json_response({
            "status": result.get("status", "completed"),
            "result": result
        })
    except Exception as e:
        return web.json_response({"error": str(e), "code": "STATUS_ERROR"}, status=500)

app.router.add_post("/api/process", process)
app.router.add_get("/api/task/status", task_status)
app.router.add_get("/api/health", health_check)

if __name__ == "__main__":
    web.run_app(app, host="0.0.0.0", port=8001) 