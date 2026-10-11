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
