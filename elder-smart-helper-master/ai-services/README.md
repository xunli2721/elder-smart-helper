# AI 服务模块

## 概述
AI 服务模块为 ElderSmartHelper 提供智能能力，包括语音识别、语音合成、图像识别、自然语言处理等功能。本模块设计为可插拔架构，支持本地模型和云端AI服务。

## 功能特性

### 1. 语音识别 (ASR)
- **多语言支持**：中文普通话、方言、英语
- **离线识别**：本地模型，无需网络
- **实时识别**：流式识别，低延迟
- **噪声抑制**：环境噪声过滤
- **说话人分离**：多人对话识别

### 2. 语音合成 (TTS)
- **多种音色**：男声、女声、老年声
- **情感合成**：高兴、平静、紧急等情感
- **语速控制**：可调节语速，适合老年人
- **离线合成**：本地TTS引擎
- **实时合成**：流式语音生成

### 3. 图像识别
- **文字识别** (OCR)：提取图片中的文字
- **二维码识别**：扫描支付码、健康码等
- **物体识别**：识别常用物品
- **场景理解**：理解图片场景
- **人脸检测**：隐私保护模式下的人脸模糊

### 4. 自然语言处理 (NLP)
- **意图识别**：理解用户请求意图
- **情感分析**：分析用户情绪状态
- **实体识别**：提取关键信息
- **对话管理**：多轮对话上下文
- **指令解析**：解析复杂指令

### 5. 安全检测
- **诈骗识别**：识别诈骗信息和电话
- **风险分析**：分析操作风险等级
- **异常检测**：检测异常使用模式
- **内容过滤**：过滤不良信息

## 架构设计

### 服务架构
```
ai-services/
├── core/                 # 核心服务
│   ├── asr/             # 语音识别服务
│   ├── tts/             # 语音合成服务
│   ├── vision/          # 视觉服务
│   ├── nlp/             # 自然语言处理
│   └── security/        # 安全检测服务
├── models/              # AI模型文件
│   ├── asr/             # 语音识别模型
│   ├── tts/             # 语音合成模型
│   ├── ocr/             # 文字识别模型
│   └── fraud/           # 诈骗检测模型
├── api/                 # API接口
│   ├── rest/            # REST API
│   ├── grpc/            # gRPC接口
│   └── websocket/       # WebSocket接口
├── clients/             # 客户端SDK
│   ├── nodejs/          # Node.js客户端
│   ├── python/          # Python客户端
│   └── mobile/          # 移动端SDK
└── utils/               # 工具函数
```

### 部署模式
1. **本地部署**：所有AI服务运行在本地服务器
2. **混合部署**：核心服务本地，部分服务云端
3. **云端部署**：全部使用云端AI服务

## 技术栈

### 核心框架
- **Python 3.8+**：主要开发语言
- **FastAPI**：高性能API框架
- **PyTorch**：深度学习框架
- **TensorFlow**：机器学习框架
- **ONNX Runtime**：模型推理优化

### AI模型库
- **SpeechBrain**：语音处理
- **Coqui TTS**：语音合成
- **EasyOCR**：文字识别
- **Transformers**：自然语言处理
- **OpenCV**：计算机视觉

### 云端服务集成
- **Azure Cognitive Services**
- **Google Cloud AI**
- **阿里云智能语音交互**
- **腾讯云AI**
- **百度AI开放平台**

## 快速开始

### 环境要求
```bash
# Python 3.8+
python --version

# CUDA 11.3+ (GPU加速)
nvidia-smi

# 内存: 16GB+ RAM
# 存储: 50GB+ 可用空间
```

### 安装依赖
```bash
# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# 安装依赖
pip install -r requirements.txt

# 安装PyTorch (根据CUDA版本)
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### 启动服务
```bash
# 开发模式
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 生产模式
gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app

# Docker运行
docker build -t elder-ai-service .
docker run -p 8000:8000 elder-ai-service
```

## API 文档

### 语音识别
```http
POST /api/v1/asr/recognize
Content-Type: multipart/form-data

参数:
- audio: 音频文件 (wav, mp3, m4a)
- language: 语言代码 (zh-CN, en-US)
- model: 模型名称 (general, command, conversation)
- stream: 是否流式识别 (true/false)

响应:
{
  "success": true,
  "data": {
    "text": "识别出的文本",
    "confidence": 0.95,
    "segments": [
      {"text": "片段1", "start": 0.0, "end": 1.5},
      {"text": "片段2", "start": 1.5, "end": 3.0}
    ]
  }
}
```

### 语音合成
```http
POST /api/v1/tts/synthesize
Content-Type: application/json

参数:
{
  "text": "要合成的文本",
  "voice": "zh-CN-XiaoxiaoNeural",
  "speed": 1.0,
  "pitch": 0.0,
  "emotion": "neutral"
}

响应:
{
  "success": true,
  "data": {
    "audio": "base64编码的音频数据",
    "format": "wav",
    "duration": 3.5,
    "sample_rate": 16000
  }
}
```

### 图像识别
```http
POST /api/v1/vision/recognize
Content-Type: multipart/form-data

参数:
- image: 图片文件 (jpg, png)
- task: 识别任务 (ocr, qrcode, object, scene)

响应 (OCR示例):
{
  "success": true,
  "data": {
    "text": "识别出的文字",
    "boxes": [
      {
        "text": "文字块1",
        "confidence": 0.98,
        "bbox": [10, 20, 100, 30]
      }
    ],
    "language": "zh-CN"
  }
}
```

## 模型管理

### 预训练模型
模型存储在 `models/` 目录下：

```
models/
├── asr/
│   ├── wav2vec2-zh-CN/        # 中文语音识别
│   ├── whisper-small/         # 多语言语音识别
│   └── vosk-model-small-cn/   # 离线语音识别
├── tts/
│   ├── fastspeech2-zh-CN/     # 中文语音合成
│   ├── vits-zh-CN/            # 高质量语音合成
│   └── gl-tts/                # 轻量级TTS
├── ocr/
│   ├── paddleocr-zh/          # 中文OCR
│   └── easyocr-multilingual/  # 多语言OCR
└── fraud/
    ├── text-classifier/       # 文本分类
    └── pattern-detector/      # 模式检测
```

### 模型下载
```bash
# 下载所有模型
python scripts/download_models.py --all

# 下载特定模型
python scripts/download_models.py --model asr/wav2vec2-zh-CN

# 从Hugging Face下载
python scripts/download_models.py --hf facebook/wav2vec2-base-zh-CN
```

### 模型更新
```bash
# 检查模型更新
python scripts/check_model_updates.py

# 更新模型
python scripts/update_models.py --model asr/wav2vec2-zh-CN

# 回滚模型
python scripts/rollback_model.py --model asr/wav2vec2-zh-CN --version v1.0.0
```

## 性能优化

### 硬件加速
```python
# 使用GPU加速
import torch
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# 使用TensorRT优化
import tensorrt as trt

# 使用ONNX Runtime优化
import onnxruntime as ort
session = ort.InferenceSession("model.onnx")
```

### 模型量化
```python
# 动态量化
import torch.quantization
quantized_model = torch.quantization.quantize_dynamic(
    model, {torch.nn.Linear}, dtype=torch.qint8
)

# 静态量化
model.qconfig = torch.quantization.get_default_qconfig('fbgemm')
torch.quantization.prepare(model, inplace=True)
# ... 校准过程 ...
torch.quantization.convert(model, inplace=True)
```

### 缓存优化
```python
# 实现结果缓存
from functools import lru_cache
import hashlib

@lru_cache(maxsize=1000)
def recognize_speech(audio_hash, language):
    # 语音识别逻辑
    pass

def get_audio_hash(audio_data):
    return hashlib.md5(audio_data).hexdigest()
```

## 监控和日志

### 性能监控
```python
# 监控指标
import time
from prometheus_client import Counter, Histogram

# 定义指标
asr_requests = Counter('asr_requests_total', 'Total ASR requests')
asr_latency = Histogram('asr_request_latency_seconds', 'ASR request latency')

# 使用装饰器监控
@asr_latency.time()
def recognize(audio_data):
    asr_requests.inc()
    # 识别逻辑
    return result
```

### 日志记录
```python
import logging
import structlog

# 配置结构化日志
structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer()
    ],
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger()

# 记录日志
logger.info("asr_request_received", 
           audio_length=len(audio_data),
           language=language)
```

## 安全考虑

### 数据隐私
```python
# 音频数据脱敏
def anonymize_audio(audio_data):
    # 移除个人身份信息
    # 添加噪声保护
    # 加密存储
    pass

# 结果过滤
def filter_sensitive_content(text):
    sensitive_patterns = [
        r'\b\d{11}\b',  # 手机号
        r'\b\d{18}\b',  # 身份证号
        r'\b\d{16}\b',  # 银行卡号
    ]
    for pattern in sensitive_patterns:
        text = re.sub(pattern, '[REDACTED]', text)
    return text
```

### 访问控制
```python
# API密钥验证
from fastapi import Security, HTTPException
from fastapi.security import APIKeyHeader

api_key_header = APIKeyHeader(name="X-API-Key")

async def verify_api_key(api_key: str = Security(api_key_header)):
    if api_key != os.getenv("AI_SERVICE_API_KEY"):
        raise HTTPException(status_code=403, detail="Invalid API key")
    return api_key
```

## 部署指南

### Docker部署
```dockerfile
# Dockerfile
FROM python:3.9-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 复制模型文件
COPY models/ ./models/

# 复制源代码
COPY . .

# 启动服务
CMD ["gunicorn", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "main:app", "--bind", "0.0.0.0:8000"]
```

### Kubernetes部署
```yaml
# ai-service-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elder-ai-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: elder-ai-service
  template:
    metadata:
      labels:
        app: elder-ai-service
    spec:
      containers:
      - name: ai-service
        image: elder-ai-service:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
            nvidia.com/gpu: 1
          limits:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: 1
        volumeMounts:
        - name: model-storage
          mountPath: /app/models
      volumes:
      - name: model-storage
        persistentVolumeClaim:
          claimName: ai-model-pvc
```

## 故障排除

### 常见问题
1. **模型加载失败**
   ```bash
   # 检查模型文件完整性
   python scripts/verify_models.py
   
   # 重新下载模型
   python scripts/download_models.py --force
   ```

2. **内存不足**
   ```python
   # 启用模型卸载
   model.cpu()
   # 或使用内存映射
   model = torch.load('model.pt', map_location='cpu')
   ```

3. **识别准确率低**
   ```bash
   # 检查音频质量
   python scripts/check_audio_quality.py audio.wav
   
   # 尝试不同模型
   python scripts/benchmark_models.py --task asr
   ```

### 性能调优
```bash
# 性能基准测试
python scripts/benchmark.py --model all --device cpu

# 内存使用分析
python -m memory_profiler main.py

# 性能监控
python scripts/monitor_performance.py --interval 5
```

## 贡献指南

### 开发流程
1. Fork 仓库
2. 创建功能分支
3. 实现功能并添加测试
4. 提交Pull Request
5. 通过代码审查

### 添加新模型
1. 在 `models/` 目录添加模型文件
2. 更新 `models/manifest.json`
3. 添加模型下载脚本
4. 编写模型使用示例
5. 更新API文档

### 测试要求
```bash
# 运行所有测试
pytest tests/ -v

# 运行特定测试
pytest tests/test_asr.py -v

# 覆盖率测试
pytest --cov=ai_services tests/
```

## 许可证
AI服务模块采用 MIT 许可证。部分预训练模型可能有自己的许可证，请在使用前仔细阅读。

## 联系我们
- 项目地址: https://gitee.com/lzbaawso/elder-smart-helper
- AI模块问题: 提交Issue时添加 `[AI]` 标签
- 模型贡献: 欢迎提交Pull Request

---
*智能赋能，温暖相伴*