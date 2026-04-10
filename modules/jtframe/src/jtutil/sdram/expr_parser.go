package sdram

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"

	"github.com/PaesslerAG/gval"
	"jotego/jtframe/macros"
	"jotego/jtframe/mem"
)

var macroRefRE = regexp.MustCompile("`([A-Za-z_][A-Za-z0-9_]*)")
var verilogIntRE = regexp.MustCompile("(?i)(?:\\b[0-9]+)?'[bdho][0-9a-f_xz]+")
var identRE = regexp.MustCompile("\\b[A-Za-z_][A-Za-z0-9_]*\\b")

type expressionResolver struct {
	params  map[string]string
	cache   map[string]int
	pending map[string]bool
}

func newExpressionResolver(params []mem.Param) *expressionResolver {
	ref := make(map[string]string)
	for _, each := range params {
		ref[each.Name] = each.Value
	}
	return &expressionResolver{
		params:  ref,
		cache:   make(map[string]int),
		pending: make(map[string]bool),
	}
}

func (r *expressionResolver) eval(expr string) (int, error) {
	expanded, err := r.expand(expr)
	if err != nil {
		return 0, err
	}
	value, err := gval.Evaluate(expanded, map[string]any{})
	if err != nil {
		return 0, fmt.Errorf("cannot evaluate expression %q (%q): %w", expr, expanded, err)
	}
	switch v := value.(type) {
	case float64:
		return int(v), nil
	case int:
		return v, nil
	case int64:
		return int(v), nil
	default:
		return 0, fmt.Errorf("expression %q returned unsupported type %T", expr, value)
	}
}

func (r *expressionResolver) expand(expr string) (string, error) {
	expanded := strings.TrimSpace(expr)
	var err error
	expanded = macroRefRE.ReplaceAllStringFunc(expanded, func(match string) string {
		if err != nil {
			return match
		}
		name := strings.TrimPrefix(match, "`")
		var value int
		value, err = resolveMacroInt(name)
		if err != nil {
			return match
		}
		return strconv.Itoa(value)
	})
	if err != nil {
		return "", err
	}
	expanded = verilogIntRE.ReplaceAllStringFunc(expanded, func(match string) string {
		if err != nil {
			return match
		}
		var value int
		value, err = parseIntLiteral(match)
		if err != nil {
			return match
		}
		return strconv.Itoa(value)
	})
	if err != nil {
		return "", err
	}
	expanded = identRE.ReplaceAllStringFunc(expanded, func(match string) string {
		if err != nil {
			return match
		}
		var value int
		value, err = r.resolveIdentifier(match)
		if err != nil {
			return match
		}
		return strconv.Itoa(value)
	})
	if err != nil {
		return "", err
	}
	return expanded, nil
}

func (r *expressionResolver) resolveIdentifier(name string) (int, error) {
	if value, found := r.cache[name]; found {
		return value, nil
	}
	raw, found := r.params[name]
	if found {
		if strings.TrimSpace(raw) == "" {
			return resolveMacroInt(name)
		}
		if r.pending[name] {
			return 0, fmt.Errorf("circular parameter reference at %s", name)
		}
		r.pending[name] = true
		value, err := r.eval(raw)
		delete(r.pending, name)
		if err != nil {
			return 0, fmt.Errorf("cannot evaluate parameter %s: %w", name, err)
		}
		r.cache[name] = value
		return value, nil
	}
	return resolveMacroInt(name)
}

func resolveMacroInt(name string) (int, error) {
	value := macros.Get(name)
	if strings.TrimSpace(value) == "" {
		return 0, fmt.Errorf("macro %s is not defined", name)
	}
	return parseIntLiteral(value)
}

func parseIntLiteral(raw string) (int, error) {
	s := strings.ReplaceAll(strings.TrimSpace(raw), "_", "")
	if strings.Contains(s, "'") {
		return parseVerilogIntLiteral(s)
	}
	parsed, err := strconv.ParseInt(s, 0, 64)
	if err != nil {
		return 0, fmt.Errorf("cannot parse integer %q: %w", raw, err)
	}
	return int(parsed), nil
}

func parseVerilogIntLiteral(raw string) (int, error) {
	parts := strings.SplitN(raw, "'", 2)
	if len(parts) != 2 || len(parts[1]) < 2 {
		return 0, fmt.Errorf("invalid Verilog integer %q", raw)
	}
	baseTag := strings.ToLower(parts[1][:1])
	digits := strings.ToLower(parts[1][1:])
	if strings.ContainsAny(digits, "xz?") {
		return 0, fmt.Errorf("unsupported x/z digits in Verilog integer %q", raw)
	}
	base := 10
	switch baseTag {
	case "b":
		base = 2
	case "o":
		base = 8
	case "d":
		base = 10
	case "h":
		base = 16
	default:
		return 0, fmt.Errorf("unsupported Verilog base in %q", raw)
	}
	parsed, err := strconv.ParseInt(digits, base, 64)
	if err != nil {
		return 0, fmt.Errorf("cannot parse Verilog integer %q: %w", raw, err)
	}
	return int(parsed), nil
}
