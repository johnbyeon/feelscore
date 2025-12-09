import os
import sys
import json
import pika
import random
from dotenv import load_dotenv
from sqlalchemy import create_engine, Column, Integer, String, Boolean, Enum, ForeignKey, text
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.dialects.mysql import BIGINT
from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
import time
load_dotenv()

# Configuration
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_USER = os.getenv("DB_USER", "root")
DB_PASSWORD = os.getenv("DB_PASSWORD", "password")
DB_NAME = os.getenv("DB_NAME", "feelscore")

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "localhost")
RABBITMQ_PORT = int(os.getenv("RABBITMQ_PORT", 5672))
RABBITMQ_USER = os.getenv("RABBITMQ_USER", "guest")
RABBITMQ_PASS = os.getenv("RABBITMQ_PASS", "guest")

# AI Model Configuration (Ollama)
OLLAMA_MODEL = "exaone3.5:7.8b"

# Database Setup
DATABASE_URL = f"mysql+pymysql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL, echo=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Entity Definitions
class PostEmotion(Base):
    __tablename__ = "post_emotions"

    id = Column("analysis_id", BIGINT, primary_key=True, autoincrement=True)
    post_id = Column(BIGINT, nullable=False)
    
    # Emotion Scores
    joy_score = Column(Integer, nullable=False, default=0)
    sadness_score = Column(Integer, nullable=False, default=0)
    anger_score = Column(Integer, nullable=False, default=0)
    fear_score = Column(Integer, nullable=False, default=0)
    disgust_score = Column(Integer, nullable=False, default=0)
    surprise_score = Column(Integer, nullable=False, default=0)
    contempt_score = Column(Integer, nullable=False, default=0)
    love_score = Column(Integer, nullable=False, default=0)
    anticipation_score = Column(Integer, nullable=False, default=0) # Added
    trust_score = Column(Integer, nullable=False, default=0)       # Added
    neutral_score = Column(Integer, nullable=False, default=0)

    dominant_emotion = Column(String(50), nullable=False, default="NEUTRAL")
    is_analyzed = Column(Boolean, nullable=False, default=False)

# Initialize Ollama Chain
llm = None
chain = None

def init_ollama():
    global llm, chain
    print(f"Initializing Ollama with model: {OLLAMA_MODEL}...")
    try:
        llm = ChatOllama(
            model=OLLAMA_MODEL,
            temperature=0.1,
            format="json",
            num_ctx=2048,
            num_predict=512,
            timeout=120
        )
        
        template = """
너는 한국 인터넷 문화를 완벽하게 이해하는 감정 분석가야.
입력된 텍스트의 감정을 1~10점 척도로 분석해서 JSON으로 출력해.

[분석 기준]
1. "박제", "주접" = Love/Joy (Anger 아님)
2. "혼나다", "돈쭐" = 칭찬/걱정의 반어법 (Neutral/Love)
3. 비속어/혐오표현 = Disgust/Anger
4. "기대된다", "설렌다" = Anticipation
5. "믿는다", "응원한다" = Trust

출력 형식 (JSON Only):
{{
    "scores": {{ "joy": int, "sadness": int, "anger": int, "fear": int, "disgust": int, "surprise": int, "contempt": int, "love": int, "anticipation": int, "trust": int, "neutral": int }},
    "primary": "string"
}}

입력 텍스트: "{text}"
"""
        prompt = ChatPromptTemplate.from_template(template)
        chain = prompt | llm | StrOutputParser()
        print("Ollama initialized successfully!")
    except Exception as e:
        print(f"Failed to initialize Ollama: {e}")
        llm = None

# RabbitMQ Connection
def connect_rabbitmq():
    credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
    parameters = pika.ConnectionParameters(host=RABBITMQ_HOST, port=RABBITMQ_PORT, credentials=credentials)
    return pika.BlockingConnection(parameters)

# Analysis Logic (Ollama)
def analyze_emotion(content):
    print(f"Analyzing content: {content[:50]}...")
    
    if chain is None:
        return analyze_emotion_mock(content)

    try:
        # Synchronous invocation
        raw_res = chain.invoke({"text": content})
        result = json.loads(raw_res.strip())
        
        scores = result.get("scores", {})
        # Normalize keys
        scores = {k.lower(): int(v) for k, v in scores.items()}
        
        # Calculate dominant emotion from scores
        if scores:
            dominant = max(scores, key=scores.get).upper()
        else:
            dominant = "NEUTRAL"
            
        return scores, dominant

    except Exception as e:
        print(f"Error during AI analysis: {e}")
        return analyze_emotion_mock(content)

def analyze_emotion_mock(content):
    print("Using Mock Analysis logic.")
    scores = {
        "joy": random.randint(0, 10),
        "sadness": random.randint(0, 10),
        "anger": random.randint(0, 10),
        "fear": random.randint(0, 10),
        "disgust": random.randint(0, 10),
        "surprise": random.randint(0, 10),
        "contempt": random.randint(0, 10),
        "love": random.randint(0, 10),
        "anticipation": random.randint(0, 10),
        "trust": random.randint(0, 10),
        "neutral": random.randint(0, 5)
    }
    dominant = max(scores, key=scores.get).upper()
    return scores, dominant

# Message Consumer Callback
def callback(ch, method, properties, body):
    try:
        message = json.loads(body)
        post_id = message.get("postId")
        content = message.get("content")
        
        print(f" [x] Received Post ID: {post_id}")
        
        if not post_id:
            print("Invalid message: missing postId")
            ch.basic_ack(delivery_tag=method.delivery_tag)
            return

        # 1. Analyze
        scores, dominant = analyze_emotion(content)
        
        # 2. Save to DB
        db = SessionLocal()
        try:
            existing = db.query(PostEmotion).filter(PostEmotion.post_id == post_id).first()
            
            if existing:
                print(f"Updating existing analysis for Post ID {post_id}")
                existing.joy_score = scores.get("joy", 0)
                existing.sadness_score = scores.get("sadness", 0)
                existing.anger_score = scores.get("anger", 0)
                existing.fear_score = scores.get("fear", 0)
                existing.disgust_score = scores.get("disgust", 0)
                existing.surprise_score = scores.get("surprise", 0)
                existing.contempt_score = scores.get("contempt", 0)
                existing.love_score = scores.get("love", 0)
                existing.anticipation_score = scores.get("anticipation", 0)
                existing.trust_score = scores.get("trust", 0)
                existing.neutral_score = scores.get("neutral", 0)
                existing.dominant_emotion = dominant
                existing.is_analyzed = True
            else:
                print(f"Creating new analysis for Post ID {post_id}")
                new_emotion = PostEmotion(
                    post_id=post_id,
                    joy_score=scores.get("joy", 0),
                    sadness_score=scores.get("sadness", 0),
                    anger_score=scores.get("anger", 0),
                    fear_score=scores.get("fear", 0),
                    disgust_score=scores.get("disgust", 0),
                    surprise_score=scores.get("surprise", 0),
                    contempt_score=scores.get("contempt", 0),
                    love_score=scores.get("love", 0),
                    anticipation_score=scores.get("anticipation", 0),
                    trust_score=scores.get("trust", 0),
                    neutral_score=scores.get("neutral", 0),
                    dominant_emotion=dominant,
                    is_analyzed=True
                )
                db.add(new_emotion)
            
            db.commit()
            print(f" [v] Saved analysis for Post ID {post_id}")
            
            # 3. Publish Completion Event
            completion_message = json.dumps({"postId": post_id})
            ch.basic_publish(
                exchange='',
                routing_key='q.post.analysis.complete',
                properties=pika.BasicProperties(
                    content_type='application/json'
                ),
                body=completion_message
            )
            print(f" [>] Sent completion event for Post ID {post_id}")
            
        except Exception as e:
            print(f"Error saving to DB: {e}")
            db.rollback()
        finally:
            db.close()

        # 4. Acknowledge
        ch.basic_ack(delivery_tag=method.delivery_tag)
        
    except Exception as e:
        print(f"Error processing message: {e}")
        # ch.basic_nack(delivery_tag=method.delivery_tag)



# Main Loop
if __name__ == "__main__":
    init_ollama() # Initialize Ollama
    
    while True:
        try:
            print(f" [*] Connecting to RabbitMQ at {RABBITMQ_HOST}:{RABBITMQ_PORT}...")
            connection = connect_rabbitmq()
            channel = connection.channel()
            
            channel.queue_declare(queue='q.post.analysis', durable=True)
            channel.queue_declare(queue='q.post.analysis.complete', durable=True) # Declare completion queue
            
            print(' [*] Waiting for messages in q.post.analysis. To exit press CTRL+C')
            
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue='q.post.analysis', on_message_callback=callback)
            
            channel.start_consuming()
        except pika.exceptions.AMQPConnectionError as e:
            print(f" [!] Connection failed: {e}")
            print(" [!] Retrying in 10 seconds...")
            time.sleep(10)
        except KeyboardInterrupt:
            print('Interrupted')
            try:
                if 'connection' in locals() and connection.is_open:
                    connection.close()
                sys.exit(0)
            except SystemExit:
                os._exit(0)
        except Exception as e:
            print(f" [!] Unexpected error: {e}")
            print(" [!] Retrying in 10 seconds...")
            time.sleep(10)
