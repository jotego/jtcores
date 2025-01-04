package cfgstr

type Config struct {
	Target,
	Deffile,
	Core,
	Output,
	Template,
	Commit string
	Add     []string // new definitions in command line
	Discard []string // definitions to be discarded
}