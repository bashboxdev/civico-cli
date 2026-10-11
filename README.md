🏛️ Cívico CLI (civico-cli)
Cívico CLI is an open-source, privacy-first Terminal User Interface (TUI) client and REST API service written in Go, designed for digital discourse and civic deliberation.

Inspired by democratic engagement platforms like Voxit and Pol.is, civico-cli provides a non-addictive, distraction-free terminal interface where citizens can express agreement, disagreement, or pass on public policy statements to build democratic consensus.

✨ Key Features
Privacy-First & Non-Addictive: Anonymous interaction model. No attention-seeking algorithms, tracking cookies, or toxic comment threads.

Rich Terminal Interface: Interactive TUI powered by Bubble Tea and Lip Gloss.

Full-Stack Go Architecture: Includes both a REST API server backed by SQLite and a CLI tool built with Cobra.

Debian & Linux Standard: Structured following standard Go project layouts (cmd/, internal/) for maintainability and native Linux packaging.

🏗️ Architecture & Project Structure
Plaintext
civico-cli/
├── cmd/
│   ├── civico/           # CLI / TUI Application Entrypoint
│   └── civico-server/    # REST API Server Entrypoint
├── internal/
│   ├── api/              # HTTP Client for Voxit/Civico REST API
│   ├── cli/              # Cobra Command Definitions
│   ├── server/           # HTTP Handlers & SQLite Persistence
│   └── tui/              # Bubble Tea Model & Terminal Rendering
├── go.mod
└── go.sum
🚀 Getting Started
Prerequisites
Go 1.21 or higher installed on your system.

Installation
Clone the repository and build the binaries:

Bash
git clone https://github.com/bashboxdev/civico-cli.git
cd civico-cli

# Build binaries
go build -o bin/civico-server ./cmd/civico-server
go build -o bin/civico ./cmd/civico
🏃 Usage
1. Start the API Server
In one terminal window, launch the backend REST server:

Bash
./bin/civico-server
# Or using go run:
# go run ./cmd/civico-server
Note: The server initializes civico.db using SQLite and exposes public deliberation endpoints at http://localhost:8080.

2. Run the Interactive TUI Client
In a second terminal window, connect the client to the server:

Bash
./bin/civico interactive --url http://localhost:8080
# Or using go run:
# go run ./cmd/civico interactive --url http://localhost:8080
🎮 Keyboard Controls
A / ◀ Left Arrow: Agree with statement

D / ▶ Right Arrow: Disagree with statement

P / Space: Pass / Neutral

Q / Ctrl+C: Quit application

📄 License
This project is open-source software licensed under the GNU Affero General Public License v3.0 (AGPLv3).
