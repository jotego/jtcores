package common

import (
	"fmt"
	"slices"
)

type Validator struct {
	Context string
	Valid   []string
	raw_map map[string]interface{}
	err     error
}

func (v Validator) Validate(unmarshal func(interface{}) error) error {
	v.load_raw_map(unmarshal)
	v.validate_fields()
	return v.err
}

func (v *Validator) load_raw_map(unmarshal func(interface{}) error) {
	v.err = unmarshal(&v.raw_map)
}

func (v *Validator) validate_fields() {
	if v.err != nil {
		return
	}
	for field := range v.raw_map {
		if slices.Contains(v.Valid, field) {
			continue
		}
		v.err = fmt.Errorf("Unexpected field %s in %s", field, v.Context)
		return
	}
}
