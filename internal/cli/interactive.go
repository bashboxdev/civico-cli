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
