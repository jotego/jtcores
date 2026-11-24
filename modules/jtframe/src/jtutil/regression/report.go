/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"time"
)

// Outcome is the result of one game
type Outcome string

const (
	Pass        Outcome = "pass"
	New         Outcome = "new"
	Fail        Outcome = "fail"
	Error       Outcome = "error"
	Unsupported Outcome = "unsupported"
	Pending     Outcome = "pending"
)

type GameResult struct {
	Core    string  `json:"core,omitempty"`
	Setname string  `json:"setname"`
	Outcome Outcome `json:"outcome"`
	Stage   string  `json:"stage,omitempty"`
	Message string  `json:"message,omitempty"`
}

type BuildIdentity struct {
	Repository string `json:"repository"`
	RunID      string `json:"run_id"`
	SHA        string `json:"sha"`
	Ref        string `json:"ref"`
	Event      string `json:"event"`
	PR         int    `json:"pull_request,omitempty"`
}

type Summary struct {
	RunID            string         `json:"run_id"`
	Build            BuildIdentity  `json:"build"`
	Started          time.Time      `json:"started"`
	Finished         time.Time      `json:"finished,omitempty"`
	Duration         time.Duration  `json:"duration_ns,omitempty"`
	Status           string         `json:"status"`
	OperationalError string         `json:"operational_error,omitempty"`
	Games            []GameResult   `json:"games"`
	Coverage         map[string]int `json:"coverage"`
}
