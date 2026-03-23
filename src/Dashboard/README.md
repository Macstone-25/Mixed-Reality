# Capstone Dashboard

A Next.js dashboard for session and event tracking.

## Prerequisites

- Node.js (v18 or higher)
- npm

## Installation

```bash
npm install
```

## Development

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Production Build

```bash
npm run build
npm start
```

## Linting

```bash
npm run lint
```

## Data Metrics

The dashboard tracks and displays the following data from research sessions:

### Primary Metrics (Direct Measurements)

- **Session ID**: Unique identifier for each session
- **Start Time**: Timestamp when session began
- **End Time**: Timestamp when session ended
- **Duration**: Length of session (minutes and seconds)
- **Intervention Count**: Number of system interventions in the session
- **Prompt Count**: Number of prompts issued during the session
- **Average Latency**: Mean response time across events (in seconds)
- **Error Count**: Number of errors encountered during session
- **Transcript Chunks**: Number of speech segments captured
- **Session Notes**: Additional session annotations

### Derived Metrics (Calculated)

- **Conversation Coherence**: Calculated as `100 - ((interventions / transcript chunks) * 100)` - represents the quality of conversation flow
- **Percentage of Sessions with Errors**: Aggregated across all sessions
- **Average Interventions**: Mean interventions per session
- **Average Latency (Overall)**: Mean latency across all sessions

### Event-Level Data

Each event (intervention or prompt) includes:
- **Event ID**: Unique event identifier
- **Type**: Either "intervention" or "prompt"
- **Message**: Description of the event
- **Latency**: Response time for prompts (seconds)
- **Timestamp**: When the event occurred
- **Transcript Index**: Reference to transcript line (if applicable)

### Session Inputs

- **Transcript**: Array of speech segment strings (dialogue lines and system annotations)
- **Configuration Settings**:
  - Model (e.g., gpt-4-turbo, gpt-4, gpt-3.5-turbo)
  - Context window size (tokens)
  - Temperature parameter
  - System prompt template
  - Trigger thresholds (coherence drop, topic drift, etc.)

### Data Sources

Data is currently sourced from mock data. To integrate real data, update the functions in `src/lib/mockData.ts`:
- Replace with CSV parsing for session data
- Replace with Events.log parsing for event streams
- Replace with Experiment.json parsing for configuration data
