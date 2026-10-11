#!/bin/bash
set -e

echo "🚀 Creando estructura de carpetas para civico-cli..."
mkdir -p cmd/civico cmd/civico-server internal/api internal/cli internal/server internal/tui

echo "📦 Inicializando módulo Go..."
go mod init github.com/alfonso/civico-cli

echo "📥 Descargando dependencias..."
go get github.com/spf13/cobra@latest
go get github.com/charmbracelet/bubbletea@latest
go get github.com/charmbracelet/lipgloss@latest
go get github.com/mattn/go-sqlite3@latest

echo "📝 Escribiendo internal/api/client.go..."
cat << 'EOT' > internal/api/client.go
package api

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type VoteType int

const (
	VotePass VoteType = iota
	VoteAgree
	VoteDisagree
)

type Statement struct {
	ID        string `json:"id"`
	PollID    string `json:"poll_id"`
	Content   string `json:"content"`
	Agrees    int    `json:"agrees"`
	Disagrees int    `json:"disagrees"`
	Passes    int    `json:"passes"`
}

type Poll struct {
	ID          string      `json:"id"`
	Title       string      `json:"title"`
	Description string      `json:"description"`
	Statements  []Statement `json:"statements"`
}

type VotePayload struct {
	StatementID string   `json:"statement_id"`
	Vote        VoteType `json:"vote"`
}

type Client struct {
	BaseURL    string
	HTTPClient *http.Client
}

func NewClient(baseURL string) *Client {
	return &Client{
		BaseURL: baseURL,
		HTTPClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

func (c *Client) GetActivePolls(ctx context.Context) ([]Poll, error) {
	url := fmt.Sprintf("%s/api/v1/polls/active", c.BaseURL)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, fmt.Errorf("error al crear solicitud: %w", err)
	}
	req.Header.Set("Accept", "application/json")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("error al conectar con la API (%s): %w", c.BaseURL, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("respuesta de la API no válida, código HTTP: %d", resp.StatusCode)
	}

	var polls []Poll
	if err := json.NewDecoder(resp.Body).Decode(&polls); err != nil {
		return nil, fmt.Errorf("error al decodificar respuesta JSON: %w", err)
	}

	return polls, nil
}

func (c *Client) SubmitVote(ctx context.Context, statementID string, vote VoteType) error {
	url := fmt.Sprintf("%s/api/v1/votes", c.BaseURL)

	payload := VotePayload{
		StatementID: statementID,
		Vote:        vote,
	}

	body, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("error serializando voto: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewBuffer(body))
	if err != nil {
		return fmt.Errorf("error creando petición de voto: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return fmt.Errorf("error al enviar el voto: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		return fmt.Errorf("el servidor rechazó el voto con código: %d", resp.StatusCode)
	}

	return nil
}
EOT

echo "📝 Escribiendo internal/tui/model.go..."
cat << 'EOT' > internal/tui/model.go
package tui

import (
	"context"
	"fmt"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/alfonso/civico-cli/internal/api"
)

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#3B82F6")).
			MarginBottom(1)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("#2563EB")).
			Padding(1, 2).
			Margin(1, 0)

	instructionStyle = lipgloss.NewStyle().
				Foreground(lipgloss.Color("#9CA3AF")).
				MarginTop(1)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("#EF4444")).
			Bold(true)
)

type Model struct {
	poll         api.Poll
	currentIndex int
	client       *api.Client
	done         bool
	err          error
}

func NewModel(poll api.Poll, client *api.Client) Model {
	return Model{
		poll:         poll,
		currentIndex: 0,
		client:       client,
	}
}

func (m Model) Init() tea.Cmd {
	return nil
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			return m, tea.Quit
		case "a", "left":
			m.voteCurrent(api.VoteAgree)
		case "d", "right":
			m.voteCurrent(api.VoteDisagree)
		case "p", "space":
			m.voteCurrent(api.VotePass)
		}
	}

	return m, nil
}

func (m *Model) voteCurrent(vote api.VoteType) {
	if m.currentIndex < len(m.poll.Statements) {
		currentStmt := m.poll.Statements[m.currentIndex]
		err := m.client.SubmitVote(context.Background(), currentStmt.ID, vote)
		if err != nil {
			m.err = err
			return
		}

		m.currentIndex++
		if m.currentIndex >= len(m.poll.Statements) {
			m.done = true
		}
	}
}

func (m Model) View() string {
	if m.err != nil {
		return errorStyle.Render(fmt.Sprintf("\n❌ Error durante la comunicación con el servidor: %v\n\nPresiona 'q' para salir.\n", m.err))
	}

	if m.done {
		return titleStyle.Render("✨ ¡Gracias por participar en la deliberación cívica!") +
			"\nTus respuestas fueron registradas en el servidor sin cookies ni rastreo de identidad.\n\nPresiona 'q' para salir.\n"
	}

	currentStmt := m.poll.Statements[m.currentIndex]

	header := titleStyle.Render(fmt.Sprintf("🏛️  CÍVICO — %s", m.poll.Title))
	content := fmt.Sprintf("Afirmación %d/%d:\n\n\"%s\"",
		m.currentIndex+1, len(m.poll.Statements), currentStmt.Content)

	instructions := instructionStyle.Render(
		"[A / ◀] De acuerdo   |   [D / ▶] En desacuerdo   |   [P / Espacio] Pasar   |   [Q] Salir",
	)

	return fmt.Sprintf("%s\n%s\n%s\n", header, boxStyle.Render(content), instructions)
}
EOT

echo "📝 Escribiendo internal/cli/root.go..."
cat << 'EOT' > internal/cli/root.go
package cli

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var ServerURL string

var rootCmd = &cobra.Command{
	Use:   "civico",
	Short: "civico-cli — Herramienta en la terminal para deliberación cívica",
	Long:  `Cívico CLI te permite explorar consultas cívicas públicas, votar afirmaciones y construir consensos sin sesgos ni polarización.`,
}

func Execute() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.PersistentFlags().StringVarP(&ServerURL, "url", "u", "http://localhost:8080", "URL base de la API de Cívico")
}
EOT

echo "📝 Escribiendo internal/cli/interactive.go..."
cat << 'EOT' > internal/cli/interactive.go
package cli

import (
	"context"
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/spf13/cobra"
	"github.com/alfonso/civico-cli/internal/api"
	"github.com/alfonso/civico-cli/internal/tui"
)

var interactiveCmd = &cobra.Command{
	Use:   "interactive",
	Short: "Inicia el modo interactivo (TUI) para deliberar sobre la consulta activa",
	Run: func(cmd *cobra.Command, args []string) {
		client := api.NewClient(ServerURL)

		fmt.Printf("🌐 Conectando al servidor cívico en %s...\n", ServerURL)
		polls, err := client.GetActivePolls(context.Background())
		if err != nil {
			fmt.Printf("❌ Error al obtener datos de la API: %v\n", err)
			os.Exit(1)
		}

		if len(polls) == 0 {
			fmt.Println("ℹ️ No se encontraron consultas cívicas activas en este servidor.")
			os.Exit(0)
		}

		p := tea.NewProgram(tui.NewModel(polls[0], client))
		if _, err := p.Run(); err != nil {
			fmt.Printf("❌ Error en la interfaz interactiva: %v\n", err)
			os.Exit(1)
		}
	},
}

func init() {
	rootCmd.AddCommand(interactiveCmd)
}
EOT

echo "📝 Escribiendo cmd/civico/main.go..."
cat << 'EOT' > cmd/civico/main.go
package main

import "github.com/alfonso/civico-cli/internal/cli"

func main() {
	cli.Execute()
}
EOT

echo "📝 Escribiendo internal/server/server.go..."
cat << 'EOT' > internal/server/server.go
package server

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"

	_ "github.com/mattn/go-sqlite3"
	"github.com/alfonso/civico-cli/internal/api"
)

type Server struct {
	db   *sql.DB
	port string
}

func NewServer(port string, dbPath string) (*Server, error) {
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("error abriendo la base de datos: %w", err)
	}

	s := &Server{
		db:   db,
		port: port,
	}

	if err := s.initSchema(); err != nil {
		return nil, fmt.Errorf("error inicializando esquema: %w", err)
	}

	return s, nil
}

func (s *Server) initSchema() error {
	schema := `
	CREATE TABLE IF NOT EXISTS polls (
		id TEXT PRIMARY KEY,
		title TEXT NOT NULL,
		description TEXT NOT NULL
	);

	CREATE TABLE IF NOT EXISTS statements (
		id TEXT PRIMARY KEY,
		poll_id TEXT NOT NULL,
		content TEXT NOT NULL,
		agrees INTEGER DEFAULT 0,
		disagrees INTEGER DEFAULT 0,
		passes INTEGER DEFAULT 0,
		FOREIGN KEY(poll_id) REFERENCES polls(id)
	);

	CREATE TABLE IF NOT EXISTS votes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		statement_id TEXT NOT NULL,
		vote_type INTEGER NOT NULL,
		created_at DATETIME DEFAULT CURRENT_TIMESTAMP
	);
	`
	_, err := s.db.Exec(schema)
	if err != nil {
		return err
	}

	var count int
	s.db.QueryRow("SELECT COUNT(*) FROM polls").Scan(&count)
	if count == 0 {
		_, _ = s.db.Exec(`INSERT INTO polls (id, title, description) VALUES 
			('poll-1', 'Uso de Software Libre en la Administración Pública', 'Consulta abierta sobre estándares de soberanía tecnológica e intangibilidad de datos.')`)

		_, _ = s.db.Exec(`INSERT INTO statements (id, poll_id, content) VALUES 
			('stmt-1', 'poll-1', 'Toda solución tecnológica contratada por el Estado debe ofrecer código fuente auditable.'),
			('stmt-2', 'poll-1', 'Las aplicaciones de participación cívica deben estar libres de mecanismos adictivos de retención.'),
			('stmt-3', 'poll-1', 'Se debe priorizar la interoperabilidad mediante formatos abiertos en lugar de licencias propietarias.')`)
	}

	return nil
}

func (s *Server) Start() error {
	http.HandleFunc("/api/v1/polls/active", s.handleGetActivePolls)
	http.HandleFunc("/api/v1/votes", s.handlePostVote)

	log.Printf("🚀 Servidor Cívico API iniciado en http://localhost:%s\n", s.port)
	return http.ListenAndServe(":"+s.port, nil)
}

func (s *Server) handleGetActivePolls(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Método no permitido", http.StatusMethodNotAllowed)
		return
	}

	rows, err := s.db.Query("SELECT id, title, description FROM polls LIMIT 1")
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var polls []api.Poll
	for rows.Next() {
		var p api.Poll
		if err := rows.Scan(&p.ID, &p.Title, &p.Description); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		stmtRows, err := s.db.Query("SELECT id, poll_id, content, agrees, disagrees, passes FROM statements WHERE poll_id = ?", p.ID)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		for stmtRows.Next() {
			var st api.Statement
			if err := stmtRows.Scan(&st.ID, &st.PollID, &st.Content, &st.Agrees, &st.Disagrees, &st.Passes); err != nil {
				stmtRows.Close()
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}
			p.Statements = append(p.Statements, st)
		}
		stmtRows.Close()

		polls = append(polls, p)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(polls)
}

func (s *Server) handlePostVote(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Método no permitido", http.StatusMethodNotAllowed)
		return
	}

	var payload api.VotePayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "JSON no válido", http.StatusBadRequest)
		return
	}

	_, err := s.db.Exec("INSERT INTO votes (statement_id, vote_type) VALUES (?, ?)", payload.StatementID, payload.Vote)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	var column string
	switch payload.Vote {
	case api.VoteAgree:
		column = "agrees"
	case api.VoteDisagree:
		column = "disagrees"
	case api.VotePass:
		column = "passes"
	}

	if column != "" {
		query := fmt.Sprintf("UPDATE statements SET %s = %s + 1 WHERE id = ?", column, column)
		_, _ = s.db.Exec(query, payload.StatementID)
	}

	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]string{"status": "voto_registrado"})
}
EOT

echo "📝 Escribiendo cmd/civico-server/main.go..."
cat << 'EOT' > cmd/civico-server/main.go
package main

import (
	"log"
	"github.com/alfonso/civico-cli/internal/server"
)

func main() {
	srv, err := server.NewServer("8080", "civico.db")
	if err != nil {
		log.Fatalf("Fatal: %v", err)
	}

	if err := srv.Start(); err != nil {
		log.Fatalf("Fatal ejecutando servidor: %v", err)
	}
}
EOT

echo "🧹 Limpiando dependencias del módulo..."
go mod tidy

echo "🎉 ¡Proyecto creado con éxito!"
echo "Para compilar un archivo .zip para respaldo, puedes ejecutar: zip -r civico-cli.zip ."
