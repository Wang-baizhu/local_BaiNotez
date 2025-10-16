from aiohttp import web
import asyncio
from faster_whisper import WhisperModel
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
import concurrent.futures
import torch

print("正在加载Whisper模型，请稍候...")
try:
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    if device == "cuda":
        whisper_model = WhisperModel("large-v3", device=device, compute_type="float16")
    else:
        whisper_model = WhisperModel("small", device=device, compute_type="int8")
    print(f"使用{device}Whisper模型加载成功。")
except Exception as e:
    print(f"加载Whisper模型时出错: {e}")
    whisper_model = None

app = web.Application()
# This thread pool is for CPU/GPU-bound tasks in the worker
worker_thread_pool = concurrent.futures.ThreadPoolExecutor(max_workers=2) 

def preprocess_transcript(transcript):
    if not transcript or 'segments' not in transcript:
        raise ValueError("无效的转录数据格式")
    formatted_segments = []
    current_segments = []
    for segment in transcript['segments']:
        start = segment['start']
        end = segment['end']
        text = segment['text'].strip()
        start_minutes = int(start // 60)
        start_seconds = int(start % 60)
        end_minutes = int(end // 60)
        end_seconds = int(end % 60)
        time_str = f"{start_minutes:02d}:{start_seconds:02d} - {end_minutes:02d}:{end_seconds:02d}"
        if current_segments:
            formatted_segments.extend(current_segments)
            current_segments = []
        current_segments.append(f"- {time_str} {text}")
    if current_segments:
        formatted_segments.extend(current_segments)
    full_text = '\n'.join(formatted_segments)
    return full_text

def generate_prompt(text):
    return f'''请对以下音频转录文本进行总结：
    {text}

    总结要求：
    1. 以 Markdown 格式返回(不使用```markdown```包裹)
    2. 如果有学习任务或安排要求，标注时间点（MM:SS）。
    3. 只包含课程内容，不编造未提及的内容。
    4. 给出具体的知识点或操作要点。
    5. 不同部分用---分隔。
    '''

def call_llm(prompt, model, llm_url,apiKey):
    chat = ChatOpenAI(model=model or "gemma2:latest", temperature=0.7, streaming=False, api_key=apiKey or "ollama",
                      base_url=llm_url or "http://127.0.0.1:11434/v1")
    print(f"已使用配置:\nmodel:{model}\napi_key:{apiKey}\nbase_url:{llm_url}")
    messages = [
        SystemMessage(content="你是一个专业的音频转录内容总结助手，擅长对音频转录文本进行结构化总结。"),
        HumanMessage(content=prompt)
    ]
    response = chat(messages)
    return response.content

async def internal_process(request):
    if whisper_model is None:
        return web.json_response({"error": "Whisper model is not available.", "code": "MODEL_LOAD_ERROR"}, status=500)
        
    loop = asyncio.get_event_loop()
    try:
        data = await request.json()
        audio_file = data.get('audio_file_path')
        llmmodel = data.get('model')
        llm_url = data.get('llm_url')
        # Remove /chat/completions suffix if it exists
        if llm_url and llm_url.endswith('/chat/completions'):
            llm_url = llm_url[:-len('/chat/completions')]
        apiKey = data.get('apiKey')

        if not audio_file:
            return web.json_response({"error": "Missing audio_file_path"}, status=400)

        # Whisper transcription (in thread pool)
        def whisper_task():
            segments, info = whisper_model.transcribe(audio_file,beam_size=5)
            return segments, info
        print("转录任务开始")

        segments, info = await loop.run_in_executor(worker_thread_pool, whisper_task)
        print("转录任务完成")
        transcript_segments = []
        for seg in segments:
            transcript_segments.append({
                'start': seg.start,
                'end': seg.end,
                'text': seg.text,
            })
        transcript = {
            'language': info.language,
            'segments': transcript_segments
        }

        # Generate summary (in thread pool)
        full_text = preprocess_transcript(transcript)
        prompt = generate_prompt(full_text)

        print("总结任务开始")
        def llm_task():
            return call_llm(prompt, llmmodel, llm_url, apiKey)

        summary_text = await loop.run_in_executor(worker_thread_pool, llm_task)
        print("总结任务完成")

        summary = {
            "summary": summary_text,
            "language": transcript.get("language", "zh"),
        }
        
        result = {
            "transcript": transcript,
            "summary": summary,
        }
        
        return web.json_response(result)

    except Exception as e:
        return web.json_response({"error": str(e), "code": "WORKER_PROCESS_ERROR"}, status=500)


app.router.add_post("/api/internal/process", internal_process)

if __name__ == "__main__":
    web.run_app(app, host="0.0.0.0", port=8002) 