/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */
package regression

import (
    "encoding/hex"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "strings"
)

type FirmwarePair struct {
    Firmware string `json:"firmware"`
    SHA256 string `json:"sha256"`
}

// FirmwareTransition is an explicit operator-approved campaign continuation.
// It permits verification of historical captures, never relabeling them.
type FirmwareTransition struct {
    Schema int `json:"schema"`
    RunID string `json:"run_id"`
    Build BuildIdentity `json:"build"`
    From FirmwarePair `json:"from"`
    To FirmwarePair `json:"to"`
}

func (b *Batch) read_firmware_transition() (*FirmwareTransition,error) {
    path:=filepath.Join(b.Root,"log",b.RunID,"firmware-transition.json")
    data,err:=os.ReadFile(path)
    if os.IsNotExist(err) {return nil,nil};if err!=nil {return nil,err}
    var transition FirmwareTransition
    if err=json.Unmarshal(data,&transition);err!=nil {return nil,err}
    if transition.Schema!=1 || transition.RunID!=b.RunID || !sameResumeBuild(transition.Build,b.Build) || transition.To.Firmware!=b.Firmware || !strings.EqualFold(transition.To.SHA256,b.FirmwareSHA256) || transition.From==transition.To {return nil,fmt.Errorf("firmware transition does not match selected campaign/build/current firmware")}
    for _,pair:=range []FirmwarePair{transition.From,transition.To} {
        digest,decode_error:=hex.DecodeString(pair.SHA256)
        if decode_error!=nil || len(digest)!=32 || pair.Firmware=="" {return nil,fmt.Errorf("invalid firmware transition identity")}
    }
    return &transition,nil
}

func (b *Batch) historical_firmware_batch(transition *FirmwareTransition) *Batch {
    copy:=*b
    copy.Firmware=transition.From.Firmware
    copy.FirmwareSHA256=transition.From.SHA256
    copy.read_only_receipts=true
    return &copy
}

func (b *Batch) transitioned_game_identity(transition *FirmwareTransition,game GameSpec,current string) (string,bool,error) {
    if transition==nil {return current,false,nil}
    result,exists:=b.State.Games[game.Setname]
    if !exists || result.Outcome!=New && result.Outcome!=Pass && result.Outcome!=Fail && result.Outcome!=Unsupported {return current,false,nil}
    historical:=b.historical_firmware_batch(transition)
    old_identity,err:=gameSpecIdentity(historical,game)
    if err!=nil {return "",false,err}
    if result.Outcome!=Unsupported {
        metadata,read_error:=read_metadata(b.capture_receipt(game.Setname))
        if read_error!=nil {return "",false,read_error}
        if metadata.Firmware==b.Firmware && strings.EqualFold(metadata.FirmwareSHA256,b.FirmwareSHA256) {return current,false,nil}
        if metadata.Firmware!=transition.From.Firmware || !strings.EqualFold(metadata.FirmwareSHA256,transition.From.SHA256) {return "",false,fmt.Errorf("finalized capture has firmware outside approved transition")}
    } else if b.State.GameSpecIdentities[game.Setname]!=old_identity {return current,false,nil}
    if b.State.GameSpecIdentities[game.Setname]!=old_identity || !historical.legacyFinalizedMatches(game,result) {return "",false,fmt.Errorf("cannot prove historical firmware capture %s unchanged",game.Setname)}
    return old_identity,true,nil
}
