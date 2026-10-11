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
