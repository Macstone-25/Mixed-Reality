from flask import Flask, render_template, request, send_file, abort, redirect, url_for, jsonify
import llm_test
from llm_test import process_csv
import time
import csv
import os

app = Flask(__name__)

CSV_FILE = os.path.join(os.path.dirname(__file__), "llm_results.csv")


def _next_backup_name(base_dir, base_name="llm_results.csv"):
    """Return next backup filename like llm_results_v1.csv, llm_results_v2.csv, ..."""
    prefix = os.path.splitext(base_name)[0]
    existing = [f for f in os.listdir(base_dir) if f.startswith(prefix + "_v") and f.endswith('.csv')]
    max_v = 0
    for f in existing:
        try:
            v = int(f.split('_v')[-1].split('.csv')[0])
            if v > max_v:
                max_v = v
        except Exception:
            continue
    # include a timestamp for easier identification, e.g. llm_results_v3_20251112_162530.csv
    ts = time.strftime("%Y%m%d_%H%M%S")
    return f"{prefix}_v{max_v+1}_{ts}.csv"


def read_csv():
    rows = []
    if not os.path.exists(CSV_FILE):
        return rows
    with open(CSV_FILE, newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def append_test_to_input(recent_utterances):
    """Append a new test row to llm_tests.csv creating the file/header if needed."""
    input_file = os.path.join(os.path.dirname(__file__), "llm_tests.csv")
    header = ["recent_utterances", "prompt_type", "model_response", "processed_at", "seed"]
    write_header = not os.path.exists(input_file)
    with open(input_file, "a", newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=header)
        if write_header:
            writer.writeheader()
        writer.writerow({
            "recent_utterances": recent_utterances,
            "prompt_type": "",
            "model_response": "",
            "processed_at": "",
            "seed": ""
        })

    # Return the 0-based index of the appended row so callers can target it specifically
    try:
        with open(input_file, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
            return len(rows) - 1
    except Exception:
        return None


def read_base_prompt():
    """Return the current base prompt (reads from file via llm_test.get_base_prompt)."""
    try:
        return llm_test.get_base_prompt()
    except Exception:
        return ""





@app.route('/edit_base', methods=['GET', 'POST'])
def edit_base():
    if request.method == 'GET':
        current = read_base_prompt()
        return render_template('edit_base.html', base_prompt=current)

    # POST
    new_prompt = request.form.get('base_prompt', '')
    if new_prompt:
        success = llm_test.set_base_prompt(new_prompt)
        if not success:
            print('Warning: failed to save base prompt')

    return redirect(url_for('index'))

@app.route('/')
def index():
    query = request.args.get("q", "").lower()
    prompt_filter = request.args.get("prompt_type", "")
    support_filter = request.args.get("support_level", "")
    order = request.args.get("order", "asc")
    # Read the full dataset first so filters dropdowns reflect all available values
    all_rows = read_csv()
    queued = request.args.get("queued")

    # Defensive: ensure keys exist and normalize to strings
    def normalize(r, key):
        return (r.get(key) or "") if isinstance(r, dict) else ""

    filtered = all_rows
    if query:
        filtered = [r for r in filtered if query in normalize(r, "recent_utterances").lower() or query in normalize(r, "model_response").lower()]

    if prompt_filter:
        filtered = [r for r in filtered if normalize(r, "prompt_type") == prompt_filter]

    if support_filter:
        filtered = [r for r in filtered if normalize(r, "support_level") == support_filter]

    # Compute filter options from the full dataset so users can always select any available value
    prompt_types = sorted({normalize(r, "prompt_type") for r in all_rows if normalize(r, "prompt_type")})
    support_levels = sorted({normalize(r, "support_level") for r in all_rows if normalize(r, "support_level")})
    llm_base_prompt = read_base_prompt()
    llm_base_prompt = read_base_prompt()
    # Apply ordering (descending shows newest appended rows first)
    if order == "desc":
        filtered = list(reversed(filtered))
    return render_template(
        "index.html",
        rows=filtered,
        query=query,
        prompt_filter=prompt_filter,
        support_filter=support_filter,
        order=order,
        prompt_types=prompt_types,
        support_levels=support_levels,
        queued=queued,
        llm_base_prompt=llm_base_prompt
    )



@app.route('/recent')
def recent_api():
    """Return the most recent N result rows as JSON. Useful for partial-result polling."""
    try:
        count = int(request.args.get('count', '20'))
    except Exception:
        count = 20
    rows = read_csv()
    tail = rows[-count:]
    return jsonify(tail)





@app.route('/download')
def download():
    """Download the raw results CSV."""
    if not os.path.exists(CSV_FILE):
        abort(404, description="Results CSV not found")

    # Use modern Flask param name if available
    try:
        return send_file(CSV_FILE, as_attachment=True, download_name=os.path.basename(CSV_FILE), mimetype='text/csv')
    except TypeError:
        # Fallback for older Flask versions
        return send_file(CSV_FILE, as_attachment=True, attachment_filename=os.path.basename(CSV_FILE), mimetype='text/csv')


@app.route('/run_all', methods=['POST'])
def run_all():
    """Backup current results and regenerate the entire results CSV from the input CSV.

    This is synchronous and may take time depending on the number of inputs and API latency.
    """
    base_dir = os.path.dirname(__file__)
    input_path = os.path.join(base_dir, "llm_tests.csv")

    # If there is no input CSV, nothing to run
    if not os.path.exists(input_path):
        return redirect(url_for('index'))

    # Simple, deterministic backup name using only a timestamp
    timestamp = time.strftime("%Y%m%d_%H%M%S")
    if os.path.exists(CSV_FILE):
        try:
            backup_name = f"llm_results_{timestamp}.csv"
            backup_path = os.path.join(base_dir, backup_name)
            os.replace(CSV_FILE, backup_path)
            print(f"Backed up existing results to {backup_path}")
        except Exception as e:
            print(f"Failed to backup existing results file: {e}")

    # Run a full regeneration (process_csv will create the output file)
    try:
        # Use the same seed that the script uses when run directly
        llm_test.process_csv(input_path, CSV_FILE, seed=42)
    except Exception as e:
        print(f"Full run failed: {e}")

    return redirect(url_for('index'))


@app.route('/add', methods=['POST'])
def add_test():
    """Add a new test conversation via the frontend and trigger processing for new rows.

    This appends the new conversation to `llm_tests.csv` then runs `process_csv` to generate any missing
    results and append them to `llm_results.csv`.
    """
    recent = request.form.get('recent_utterances', '').strip()
    if not recent:
        return redirect(url_for('index'))

    # Append to input CSV and capture the appended row index
    appended_idx = append_test_to_input(recent)

    # Run processing synchronously for the newly appended row(s). Keep it simple: no background thread,
    # no status file updates, and no automatic page refresh. This keeps behavior deterministic and easy to debug.
    input_path = os.path.join(os.path.dirname(__file__), "llm_tests.csv")
    try:
        # Only process the newly added row (appended_idx) if available, otherwise process all unprocessed rows
        target = [appended_idx] if appended_idx is not None else None
        llm_test.process_unprocessed_rows(input_path, CSV_FILE, seed=None, status_file=None, target_indices=target)
    except Exception as e:
        print(f"Synchronous processing failed: {e}")

    # Redirect back to index (no queued param)
    return redirect(url_for('index'))

if __name__ == '__main__':
    app.run(debug=True, port=5000)
