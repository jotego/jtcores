// Package prompt provides terminal prompt helpers used by jtutil commands.
package prompt

import (
	"bufio"
	"io"
)

type Source interface {
	// ReadLine returns the next input line. The bool is false on end of input.
	ReadLine() (string, bool, error)
	// Close releases the resources associated with the source.
	Close() error
}

// ScannerSource reads prompt lines from a bufio.Scanner source.
type ScannerSource struct {
	scanner *bufio.Scanner
	closer  io.Closer
}

// PromptSource reads prompt lines from an interactive terminal prompt reader.
type PromptSource struct {
	prompt *Terminal
}

// NewScannerSource creates a Source backed by a bufio.Scanner.
func NewScannerSource(scanner *bufio.Scanner, closer io.Closer) Source {
	return &ScannerSource{
		scanner: scanner,
		closer:  closer,
	}
}

// ReadLine reads the next line from the scanner source.
func (s *ScannerSource) ReadLine() (string, bool, error) {
	if s.scanner.Scan() {
		return s.scanner.Text(), true, nil
	}
	if err := s.scanner.Err(); err != nil {
		return "", false, err
	}
	return "", false, nil
}

// Close closes the optional scanner closer if present.
func (s *ScannerSource) Close() error {
	if s.closer != nil {
		return s.closer.Close()
	}
	return nil
}

// NewPromptSource wraps an interactive terminal prompt reader as a Source.
func NewPromptSource(reader *Terminal) Source {
	return &PromptSource{
		prompt: reader,
	}
}

// ReadLine reads the next line from the terminal prompt reader.
func (s *PromptSource) ReadLine() (string, bool, error) {
	return s.prompt.ReadLine()
}

// Close closes the underlying terminal prompt reader.
func (s *PromptSource) Close() error {
	return s.prompt.Close()
}
