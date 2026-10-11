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
