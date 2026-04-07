package macros

import (
	"fmt"
	"strconv"
	"strings"
)

func Eval(expr string) (int64, error) {
	return eval_expr(expr, macros)
}

func eval_expr(expr string, values map[string]string) (int64, error) {
	parser := expr_parser{
		text:   expr,
		values: values,
		stack:  make(map[string]bool),
	}
	value, err := parser.parse_or()
	if err != nil {
		return 0, err
	}
	parser.skip_space()
	if parser.pos != len(parser.text) {
		return 0, fmt.Errorf("unexpected token near %q", parser.text[parser.pos:])
	}
	return value, nil
}

type expr_parser struct {
	text   string
	pos    int
	values map[string]string
	stack  map[string]bool
}

func (parser *expr_parser) parse_or() (int64, error) {
	value, err := parser.parse_shift()
	if err != nil {
		return 0, err
	}
	for {
		parser.skip_space()
		if !parser.consume("|") {
			return value, nil
		}
		right, err := parser.parse_shift()
		if err != nil {
			return 0, err
		}
		value |= right
	}
}

func (parser *expr_parser) parse_shift() (int64, error) {
	value, err := parser.parse_add()
	if err != nil {
		return 0, err
	}
	for {
		parser.skip_space()
		switch {
		case parser.consume("<<"):
			right, err := parser.parse_add()
			if err != nil {
				return 0, err
			}
			value <<= uint(right)
		case parser.consume(">>"):
			right, err := parser.parse_add()
			if err != nil {
				return 0, err
			}
			value >>= uint(right)
		default:
			return value, nil
		}
	}
}

func (parser *expr_parser) parse_add() (int64, error) {
	value, err := parser.parse_unary()
	if err != nil {
		return 0, err
	}
	for {
		parser.skip_space()
		switch {
		case parser.consume("+"):
			right, err := parser.parse_unary()
			if err != nil {
				return 0, err
			}
			value += right
		case parser.consume("-"):
			right, err := parser.parse_unary()
			if err != nil {
				return 0, err
			}
			value -= right
		default:
			return value, nil
		}
	}
}

func (parser *expr_parser) parse_unary() (int64, error) {
	parser.skip_space()
	if parser.consume("+") {
		return parser.parse_unary()
	}
	if parser.consume("-") {
		value, err := parser.parse_unary()
		if err != nil {
			return 0, err
		}
		return -value, nil
	}
	return parser.parse_primary()
}

func (parser *expr_parser) parse_primary() (int64, error) {
	parser.skip_space()
	if parser.consume("(") {
		value, err := parser.parse_or()
		if err != nil {
			return 0, err
		}
		parser.skip_space()
		if !parser.consume(")") {
			return 0, fmt.Errorf("missing closing parenthesis")
		}
		return value, nil
	}
	token := parser.read_token()
	if token == "" {
		return 0, fmt.Errorf("missing expression")
	}
	if value, ok, err := parse_int(token); ok || err != nil {
		return value, err
	}
	return parser.resolve_symbol(token)
}

func (parser *expr_parser) resolve_symbol(symbol string) (int64, error) {
	name := strings.TrimPrefix(symbol, "`")
	expr, ok := parser.values[name]
	if !ok {
		return 0, fmt.Errorf("unknown symbol %s", symbol)
	}
	if parser.stack[name] {
		return 0, fmt.Errorf("cyclic reference involving %s", name)
	}
	parser.stack[name] = true
	value, err := eval_expr_with_stack(expr, parser.values, parser.stack)
	delete(parser.stack, name)
	if err != nil {
		return 0, err
	}
	return value, nil
}

func eval_expr_with_stack(expr string, values map[string]string, stack map[string]bool) (int64, error) {
	parser := expr_parser{
		text:   expr,
		values: values,
		stack:  stack,
	}
	value, err := parser.parse_or()
	if err != nil {
		return 0, err
	}
	parser.skip_space()
	if parser.pos != len(parser.text) {
		return 0, fmt.Errorf("unexpected token near %q", parser.text[parser.pos:])
	}
	return value, nil
}

func (parser *expr_parser) skip_space() {
	for parser.pos < len(parser.text) {
		switch parser.text[parser.pos] {
		case ' ', '\t', '\n', '\r':
			parser.pos++
		default:
			return
		}
	}
}

func (parser *expr_parser) consume(pattern string) bool {
	if strings.HasPrefix(parser.text[parser.pos:], pattern) {
		parser.pos += len(pattern)
		return true
	}
	return false
}

func (parser *expr_parser) read_token() string {
	start := parser.pos
	for parser.pos < len(parser.text) {
		switch parser.text[parser.pos] {
		case ' ', '\t', '\n', '\r', '(', ')', '+', '-', '|':
			return parser.text[start:parser.pos]
		case '<', '>':
			return parser.text[start:parser.pos]
		default:
			parser.pos++
		}
	}
	return parser.text[start:parser.pos]
}

func parse_int(token string) (int64, bool, error) {
	if token == "" {
		return 0, false, nil
	}
	if strings.HasPrefix(token, "0x") || strings.HasPrefix(token, "0X") {
		value, err := strconv.ParseInt(token[2:], 16, 64)
		if err != nil {
			return 0, true, err
		}
		return value, true, nil
	}
	if strings.IndexByte(token, '\'') >= 0 {
		return parse_verilog_int(token)
	}
	if token[0] < '0' || token[0] > '9' {
		return 0, false, nil
	}
	value, err := strconv.ParseInt(token, 10, 64)
	if err != nil {
		return 0, true, err
	}
	return value, true, nil
}

func parse_verilog_int(token string) (int64, bool, error) {
	quote := strings.IndexByte(token, '\'')
	if quote < 0 || quote == len(token)-1 {
		return 0, true, fmt.Errorf("bad Verilog integer %s", token)
	}
	base := token[quote+1]
	digits := token[quote+2:]
	if digits == "" {
		return 0, true, fmt.Errorf("bad Verilog integer %s", token)
	}
	digits = strings.ReplaceAll(digits, "_", "")
	if strings.ContainsAny(digits, "xXzZ?") {
		return 0, true, fmt.Errorf("bad Verilog integer %s", token)
	}
	var radix int
	switch base {
	case 'd', 'D':
		radix = 10
	case 'h', 'H':
		radix = 16
	case 'b', 'B':
		radix = 2
	case 'o', 'O':
		radix = 8
	default:
		return 0, true, fmt.Errorf("bad Verilog integer %s", token)
	}
	value, err := strconv.ParseInt(digits, radix, 64)
	if err != nil {
		return 0, true, err
	}
	return value, true, nil
}
