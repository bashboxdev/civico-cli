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
