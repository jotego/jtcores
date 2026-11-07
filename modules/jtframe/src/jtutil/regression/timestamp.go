/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "encoding/json"
    "time"
)

// LogTime formats human-readable log timestamps in the host's local timezone.
func LogTime(value time.Time) string {
    return value.Local().Format("2006-01-02 15:04:05")
}

type progress_fields Progress
type progress_timestamp time.Time
type progress_json struct {
    *progress_fields
    Started progress_timestamp `json:"started"`
    Updated progress_timestamp `json:"updated"`
}

func (p Progress) MarshalJSON() ([]byte,error) {
    return json.Marshal(progress_json{(*progress_fields)(&p),progress_timestamp(p.Started),progress_timestamp(p.Updated)})
}

func (p *Progress) UnmarshalJSON(data []byte) error {
    decoded:=progress_json{progress_fields:(*progress_fields)(p)}
    if err:=json.Unmarshal(data,&decoded);err!=nil{return err}
    p.Started=time.Time(decoded.Started);p.Updated=time.Time(decoded.Updated)
    return nil
}

const progress_time_format="2006-01-02 15:04:05.999999999-07:00"

func (value progress_timestamp) MarshalJSON() ([]byte,error) {
    stamp:=time.Time(value)
    if !stamp.IsZero(){stamp=stamp.Local()}
    return json.Marshal(stamp.Format(progress_time_format))
}

func (value *progress_timestamp) UnmarshalJSON(data []byte) error {
    if string(data)=="null"{*value=progress_timestamp(time.Time{});return nil}
    var stamp string
    if err:=json.Unmarshal(data,&stamp);err!=nil{return err}
    parsed,err:=time.Parse(progress_time_format,stamp)
    if err!=nil{parsed,err=time.Parse(time.RFC3339Nano,stamp)}
    if err!=nil{return err}
    *value=progress_timestamp(parsed)
    return nil
}
