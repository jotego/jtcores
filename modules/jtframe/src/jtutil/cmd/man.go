package cmd

import "fmt"

func man_blurb(page, summary string) string {
	if summary == "" {
		return fmt.Sprintf("Use \"man %s\" for full documentation.", page)
	}
	return fmt.Sprintf("%s\n\nUse \"man %s\" for full documentation.", summary, page)
}
