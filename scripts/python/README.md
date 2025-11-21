# LLM Conversational Cue Testing Suite

This project runs automated prompts against an OpenAI model to generate context-aware conversational cues for older adults, then displays results in a small Flask dashboard.

Quick start

1. Copy your OpenAI credentials into a `.env` file in the project root:

```
OPENAI_API_KEY=sk-...
OPENAI_PROJECT_ID=optional
```

2. Install dependencies (recommended in a venv):

```bash
python -m pip install -r requirements.txt
```

3. Start the Flask dashboard:

```bash
python app.py
```

Open http://127.0.0.1:5000 in your browser. Use the filter form and the "Download CSV" button to inspect results.

Notes

- The runner will exit early if `OPENAI_API_KEY` is not set; this prevents accidental API errors.
- The HTML dashboard reads `llm_results.csv` and displays the table with available filters computed from the full dataset.
- To change the model used for generation, pass `--model` to `llm_test.py`.
