import csv
import os
import random
import time
import sys
import json
from openai import OpenAI
from dotenv import load_dotenv

# ------------------ Load Environment ------------------
load_dotenv()

# Validate environment early and construct client
API_KEY = os.getenv("OPENAI_API_KEY")
if not API_KEY:
    print("ERROR: OPENAI_API_KEY is not set. Please set it in your environment or .env file.")
    sys.exit(1)

client = OpenAI(
    api_key=API_KEY,
    project=os.getenv("OPENAI_PROJECT_ID")
)

# ------------------ Core Prompts ------------------
BASE_PROMPT = """
You are a conversational support assistant for a mixed-reality environment (Apple Vision Pro) that helps older adults sustain meaningful conversation.
You monitor dialogue and generate subtle, context-aware cues when a pause or hesitation is detected.
Keep every response natural, empathetic, and contextually grounded.
Avoid pronouns like “that” or “it” without context. Reference the actual topic.
Your goal is to help the user continue speaking — not to take over the conversation.
"""

# Path for an editable base prompt file (optional). If present, the text inside will override BASE_PROMPT.
BASE_PROMPT_FILE = os.path.join(os.path.dirname(__file__), "base_prompt.txt")


def get_base_prompt():
    """Return the current base prompt, preferring the file if it exists.

    This allows runtime editing of the base prompt without changing code.
    """
    try:
        if os.path.exists(BASE_PROMPT_FILE):
            with open(BASE_PROMPT_FILE, "r", encoding="utf-8") as f:
                return f.read()
    except Exception:
        pass
    return BASE_PROMPT


def set_base_prompt(text: str):
    """Persist a new base prompt to disk (overwrites file).

    Returns True on success, False on failure.
    """
    try:
        with open(BASE_PROMPT_FILE, "w", encoding="utf-8") as f:
            f.write(text)
        return True
    except Exception as e:
        print(f"Failed to write base prompt file: {e}")
        return False

SUPPORT_LEVELS = {
    1: """Provide very short, minimal suggestions (1 line max). Do not summarize or reframe.
Focus only on the last spoken detail.""",

    2: """Provide a concise suggestion (1–2 sentences) with light context from the last 1–2 utterances.
Gently reference what the user or partner last said.""",

    3: """Provide a warm, context-rich prompt (2–3 sentences).
Briefly summarize multiple relevant details from recent turns before cueing the next thought.
Reflect emotional tone, show gentle curiosity, and invite elaboration naturally."""
}

PROMPT_TYPES = {
    "semantic_completion": """
When Triggered: You pause mid-sentence or seem to be searching for a word.
Goal: Offer a gentle, natural completion cue that helps continue the user’s train of thought.

Rich-context Example:
“You were telling them about your garden — the tomatoes, basil, and rosemary you used to plant. You said the smell always made the yard feel alive. Were you about to mention how you kept the flowers watered?”
""",

    "turn_taking": """
When Triggered: You haven’t responded to your partner’s question or comment.
Goal: Gently cue a response to maintain conversational flow and social reciprocity.

Rich-context Example:
“They just asked about your weekend — you mentioned earlier that you visited your daughter and cooked together. Maybe share a bit about that visit?”
""",

    "reminiscence": """
When Triggered: You lose track of a story or previously mentioned context.
Goal: Help reconnect to the prior topic or person mentioned.

Rich-context Example:
“Earlier you were talking about the trip you took last summer — the one where you visited your sister by the lake. Were you about to describe what you enjoyed most about it?”
""",

    "affective_validation": """
When Triggered: You pause after sharing something emotional or meaningful.
Goal: Encourage gentle reflection or elaboration to promote emotional expression.

Rich-context Example:
“You mentioned how peaceful it felt sitting in your garden after watering the flowers, and how the smell of basil reminded you of home. That sounded special — would you like to tell a bit more about what made those moments meaningful?”
""",

    "conversational_bridging": """
When Triggered: You hesitate or seem unsure how to transition between topics.
Goal: Smoothly bridge to a related idea or follow-up question to keep the dialogue natural.

Rich-context Example:
“You were talking about how much you enjoyed gardening and cooking with what you grew. Maybe you could ask them whether they’ve tried using fresh herbs in their cooking too?”
"""
}

# ------------------ Dynamic Prompt Assembly ------------------
def build_system_prompt(prompt_type, support_level):
    prompt_type_text = PROMPT_TYPES[prompt_type]
    support_level_text = SUPPORT_LEVELS[support_level]

    base = get_base_prompt()

    return f"""{base}

### Support Level
{support_level_text}

### Prompt Type
{prompt_type_text}

### Output Rules
- Avoid meta-language or variable names.
- Use nouns (not pronouns) to anchor your response in topic context.
- Sound like a human conversational partner offering subtle help.
"""

# ------------------ Generation Function ------------------
def generate_conversation_suggestion(recent_utterances, prompt_type, support_level, model="gpt-4.1-mini", retries=3, backoff=1.0):
    # By default build the system prompt here; callers may build and pass the same prompt
    system_prompt = build_system_prompt(prompt_type, support_level)
    user_prompt = f"""
The following transcript represents the recent portion of a live conversation.
A conversational pause has been detected.

Conversation Context:
{recent_utterances}

Please output only one short conversational cue suitable for the user to say next.
"""

    last_exception = None
    for attempt in range(1, retries + 1):
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ]
            )

            # Safely extract content from response
            try:
                content = response.choices[0].message.content.strip()
            except Exception:
                # Fallback for other response shapes
                content = getattr(response, "text", "").strip()

            return content

        except Exception as e:
            last_exception = e
            print(f"API call failed (attempt {attempt}/{retries}): {e}")
            if attempt < retries:
                sleep_time = backoff * (2 ** (attempt - 1))
                print(f"Retrying in {sleep_time:.1f}s...")
                time.sleep(sleep_time)
            else:
                # Last attempt, propagate the exception to caller
                raise

    # If we reach here, raise the last exception
    raise last_exception

# ------------------ CSV Processing ------------------
def process_csv(input_csv, output_csv, seed=None):
    # Seed deterministic random choices
    if seed is None:
        seed = 42
    random.seed(seed)
    print(f"🔢 Random seed set to: {seed}")

    prompt_types = list(PROMPT_TYPES.keys())
    support_levels = list(SUPPORT_LEVELS.keys())

    # Read input rows
    with open(input_csv, newline='', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        input_fieldnames = reader.fieldnames or ["recent_utterances"]
        rows = list(reader)

    # Prepare existing results to avoid duplicates
    existing_keys = set()
    existing_fieldnames = []
    if os.path.exists(output_csv):
        with open(output_csv, newline='', encoding='utf-8') as outf:
            out_reader = csv.DictReader(outf)
            existing_fieldnames = out_reader.fieldnames or []
            for r in out_reader:
                key = (
                    r.get("recent_utterances", ""),
                    r.get("prompt_type", ""),
                    str(r.get("support_level", "")),
                    str(r.get("seed", ""))
                )
                existing_keys.add(key)

    # Determine final fieldnames (union)
    final_fieldnames = list(dict.fromkeys((input_fieldnames or []) + existing_fieldnames))
    for col in ["model_response", "prompt_type", "support_level", "seed", "system_prompt"]:
        if col not in final_fieldnames:
            final_fieldnames.append(col)
    # include latency column for timing metrics
    if "latency_ms" not in final_fieldnames:
        final_fieldnames.append("latency_ms")

    # Collect rows to append
    to_append = []

    for i, row in enumerate(rows, start=1):
        print(f"\n🧩 Processing input {i}/{len(rows)}...")
        recent_utterances = row.get("recent_utterances", "")

        # Choose the prompt type deterministically based on seed and iteration order
        prompt_type = random.choice(prompt_types)

        for level in support_levels:
            key = (recent_utterances, prompt_type, str(level), str(seed))
            if key in existing_keys:
                print(f"→ Skipping existing result for support_level={level}, prompt_type={prompt_type}")
                continue

            print(f"→ Running support level {level} for prompt type '{prompt_type}'")

            row_copy = {fn: (row.get(fn, "") if isinstance(row, dict) else "") for fn in final_fieldnames}
            row_copy["prompt_type"] = prompt_type
            row_copy["support_level"] = level
            row_copy["seed"] = seed

            # Build and record the system prompt for traceability
            system_prompt = build_system_prompt(prompt_type, level)

            try:
                response = generate_conversation_suggestion(recent_utterances, prompt_type, level)
            except Exception as e:
                response = f"Error: {e}"

            row_copy["model_response"] = response
            row_copy["system_prompt"] = system_prompt
            to_append.append(row_copy)

            # Add to existing_keys to avoid duplicates within the same run
            existing_keys.add(key)

            print(f"   ↳ Response: {response}")

    # Append new results to output CSV (create with header if missing)
    write_header = not os.path.exists(output_csv)
    with open(output_csv, "a", newline='', encoding='utf-8') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=final_fieldnames)
        if write_header:
            writer.writeheader()
        if to_append:
            writer.writerows(to_append)

    print(f"\n✅ Completed. {len(to_append)} new results saved to {output_csv}")
    print(f"🔢 Seed used: {seed}")
    return to_append


def process_unprocessed_rows(input_csv, output_csv, seed=None, status_file=None, target_indices=None):
    """Process only rows in `input_csv` that are not yet marked as processed.

    For each unprocessed input row, choose a prompt_type, build the system prompt,
    generate responses for each support level, append results to output_csv, and
    update the input CSV row with `prompt_type`, `processed_at`, and `seed`.
    """
    if seed is None:
        seed = random.randint(1, 10**6)
    random.seed(seed)
    print(f"🔢 Processing unprocessed rows with seed: {seed}")

    # Read input rows
    with open(input_csv, newline='', encoding='utf-8') as infile:
        reader = csv.DictReader(infile)
        input_fieldnames = reader.fieldnames or ["recent_utterances"]
        rows = list(reader)

    # Ensure input_fieldnames include columns we will write back to the input CSV
    for col in ["prompt_type", "seed", "processed_at", "processed"]:
        if col not in input_fieldnames:
            input_fieldnames.append(col)

    # Read existing results to avoid duplicates
    existing_keys = set()
    if os.path.exists(output_csv):
        with open(output_csv, newline='', encoding='utf-8') as outf:
            out_reader = csv.DictReader(outf)
            for r in out_reader:
                key = (
                    r.get("recent_utterances", ""),
                    r.get("prompt_type", ""),
                    str(r.get("support_level", "")),
                    str(r.get("seed", ""))
                )
                existing_keys.add(key)

    # Prepare final fieldnames for output CSV
    final_fieldnames = list(input_fieldnames)
    for col in ["model_response", "prompt_type", "support_level", "seed", "system_prompt"]:
        if col not in final_fieldnames:
            final_fieldnames.append(col)
    # include latency column for timing metrics
    if "latency_ms" not in final_fieldnames:
        final_fieldnames.append("latency_ms")

    to_append = []
    updated_rows = False

    # Precompute total number of tasks (support-level outputs) to process so UI can show progress
    total_tasks = 0
    for idx, row in enumerate(rows):
        # If target_indices is provided, only count tasks for those indices
        if target_indices is not None and idx not in target_indices:
            continue
        processed_marker = row.get("processed_at") or row.get("processed")
        if processed_marker:
            continue
        # count levels that are not already present (approximate)
        for level in list(SUPPORT_LEVELS.keys()):
            total_tasks += 1

    processed_count = 0
    latency_sum = 0.0
    latency_count = 0

    def _maybe_update_status(running=True, last_error=None, last_latency=None):
        if not status_file:
            return
        try:
            s = {
                "current_job_id": None,
                "running": running,
                "started_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
                "finished_at": None,
                "processed_count": processed_count,
                "total_tasks": total_tasks,
                "last_count": processed_count,
                "last_error": last_error,
                "avg_latency_ms": (latency_sum / latency_count) if latency_count else None,
                "last_latency_ms": last_latency
            }
            # Preserve existing current_job_id if present
            if os.path.exists(status_file):
                try:
                    with open(status_file, "r", encoding='utf-8') as sf:
                        existing = json.load(sf)
                        if existing.get("current_job_id"):
                            s["current_job_id"] = existing.get("current_job_id")
                except Exception:
                    pass
            with open(status_file, "w", encoding='utf-8') as sf:
                json.dump(s, sf)
        except Exception:
            pass

    for idx, row in enumerate(rows):
        # If target_indices is provided, skip rows not targeted
        if target_indices is not None and idx not in target_indices:
            continue

        # Consider a row unprocessed if it has no 'processed_at' or 'processed' marker
        processed_marker = row.get("processed_at") or row.get("processed")
        if processed_marker:
            continue

        recent_utterances = row.get("recent_utterances", "")
        prompt_type = random.choice(list(PROMPT_TYPES.keys()))

        for level in list(SUPPORT_LEVELS.keys()):
            key = (recent_utterances, prompt_type, str(level), str(seed))
            if key in existing_keys:
                print(f"→ Skipping existing result for row {idx} support_level={level}")
                continue

            print(f"→ Generating for row {idx} support_level={level} prompt_type={prompt_type}")

            system_prompt = build_system_prompt(prompt_type, level)
            # Time the API call to measure latency
            start_ts = time.time()
            try:
                response = generate_conversation_suggestion(recent_utterances, prompt_type, level)
            except Exception as e:
                response = f"Error: {e}"
            end_ts = time.time()
            latency_ms = int((end_ts - start_ts) * 1000)

            new_row = {fn: (row.get(fn, "") if isinstance(row, dict) else "") for fn in final_fieldnames}
            new_row["prompt_type"] = prompt_type
            new_row["support_level"] = level
            new_row["seed"] = seed
            new_row["model_response"] = response
            new_row["system_prompt"] = system_prompt
            new_row["latency_ms"] = latency_ms
            to_append.append(new_row)

            existing_keys.add(key)

            # Update processed/latency counters and status file
            processed_count += 1
            latency_sum += latency_ms
            latency_count += 1
            _maybe_update_status(running=True, last_error=None, last_latency=latency_ms)

        # Mark input row as processed and persist chosen prompt_type and seed
        rows[idx]["prompt_type"] = prompt_type
        rows[idx]["seed"] = seed
        rows[idx]["processed_at"] = time.strftime("%Y-%m-%dT%H:%M:%S")
        updated_rows = True

    # Append new results to output CSV, but if the existing CSV header is missing any of the
    # final_fieldnames (for example 'system_prompt'), rewrite the entire CSV with the
    # expanded header so readers (csv.DictReader) will see the new column.
    if to_append:
        try:
            if os.path.exists(output_csv):
                # Read existing rows
                with open(output_csv, newline='', encoding='utf-8') as outf:
                    existing_reader = csv.DictReader(outf)
                    existing_fieldnames = existing_reader.fieldnames or []
                    existing_rows = list(existing_reader)

                # If existing header already includes all final_fieldnames, just append
                if set(final_fieldnames).issubset(set(existing_fieldnames)):
                    with open(output_csv, "a", newline='', encoding='utf-8') as outfile:
                        writer = csv.DictWriter(outfile, fieldnames=existing_fieldnames)
                        writer.writerows(to_append)
                else:
                    # Need to rewrite file with expanded header
                    temp_path = output_csv + ".tmp"
                    with open(temp_path, "w", newline='', encoding='utf-8') as tf:
                        writer = csv.DictWriter(tf, fieldnames=final_fieldnames)
                        writer.writeheader()
                        # Write existing rows mapping missing keys to empty string
                        for er in existing_rows:
                            out_row = {k: er.get(k, "") for k in final_fieldnames}
                            writer.writerow(out_row)
                        # Write new appended rows
                        for nr in to_append:
                            out_row = {k: nr.get(k, "") for k in final_fieldnames}
                            writer.writerow(out_row)
                    os.replace(temp_path, output_csv)
            else:
                # File doesn't exist: create and write header + rows
                with open(output_csv, "w", newline='', encoding='utf-8') as outfile:
                    writer = csv.DictWriter(outfile, fieldnames=final_fieldnames)
                    writer.writeheader()
                    writer.writerows(to_append)
        except Exception as e:
            # Record the error to the status file and abort gracefully
            if status_file:
                try:
                    s = {}
                    if os.path.exists(status_file):
                        with open(status_file, 'r', encoding='utf-8') as sf:
                            s = json.load(sf)
                    s.update({
                        'running': False,
                        'last_error': f'CSV write error: {e}',
                        'finished_at': time.strftime("%Y-%m-%dT%H:%M:%S")
                    })
                    with open(status_file, 'w', encoding='utf-8') as sf:
                        json.dump(s, sf)
                except Exception:
                    pass
            raise

    # If we updated input rows, write them back atomically
    # If we updated input rows, write them back atomically
    if updated_rows:
        try:
            temp_path = input_csv + ".tmp"
            with open(temp_path, "w", newline='', encoding='utf-8') as tf:
                writer = csv.DictWriter(tf, fieldnames=input_fieldnames)
                writer.writeheader()
                writer.writerows(rows)
            os.replace(temp_path, input_csv)
        except Exception as e:
            # Log to status file
            if status_file:
                try:
                    s = {}
                    if os.path.exists(status_file):
                        with open(status_file, 'r', encoding='utf-8') as sf:
                            s = json.load(sf)
                    s.update({
                        'running': False,
                        'last_error': f'Input CSV write error: {e}',
                        'finished_at': time.strftime("%Y-%m-%dT%H:%M:%S")
                    })
                    with open(status_file, 'w', encoding='utf-8') as sf:
                        json.dump(s, sf)
                except Exception:
                    pass
            raise

    # Final status update
    _maybe_update_status(running=False, last_error=None, last_latency=(latency_sum / latency_count) if latency_count else None)

    print(f"\n✅ Background processing complete. {len(to_append)} new results appended to {output_csv}")
    return to_append

# ------------------ Run Script ------------------
if __name__ == "__main__":
    # Default, no CLI args: use the repository's CSV filenames and a fixed seed for reproducibility
    input_csv = "llm_tests.csv"
    output_csv = "llm_results.csv"
    results = process_csv(input_csv, output_csv, seed=42)

    print("\n=== FINAL RESULTS ===")
    for row in results:
        print(f"\nPrompt Type: {row.get('prompt_type')}")
        print(f"Support Level: {row.get('support_level')}")
        print(f"Seed: {row.get('seed')}")
        print(f"Model Response: {row.get('model_response')}")
