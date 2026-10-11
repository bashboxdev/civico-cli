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
