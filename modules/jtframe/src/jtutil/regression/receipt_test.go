/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later */

package regression

import (
	"encoding/binary"
	"image/png"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func receipt_test_batch(t *testing.T, startup int) (*Batch, GameSpec, GameResult) {
	t.Helper()
	game := GameSpec{Setname: "collected"}
	batch := makeBatch(t, t.TempDir(), &retryHardware{}, []GameSpec{game})
	profile := "video: 300\nstart-up: " + jsonNumber(startup) + "\n"
	if err := os.WriteFile(batch.GlobalProfile, []byte(profile), 0600); err != nil { t.Fatal(err) }
	return batch, game, GameResult{Outcome: New, TestIdentity: "receipt-test"}
}

func legacy_test_receipt(t *testing.T, batch *Batch, game GameSpec, source string) {
	t.Helper()
	dir := batch.capture_receipt(game.Setname)
	if err := os.MkdirAll(dir, 0750); err != nil { t.Fatal(err) }
	if err := export_png_frames(source, dir); err != nil { t.Fatal(err) }
	if err := write_metadata(dir, GameMetadata{Build: batch.Build, TestIdentity: "receipt-test", CaptureFormat: "rgb555"}); err != nil { t.Fatal(err) }
	if err := copyFile(filepath.Join(source, "index.jsonl"), filepath.Join(dir, "transport-index.jsonl")); err != nil { t.Fatal(err) }
}

func publish_test_new(t *testing.T, batch *Batch, game GameSpec, source string) string {
	t.Helper()
	dir := filepath.Join(batch.Root, batch.Core, game.Setname)
	if err := PublishComplete(dir, source, New, nil); err != nil { t.Fatal(err) }
	return dir
}

func assert_no_receipt_pngs(t *testing.T, dir string) {
	t.Helper()
	files, err := filepath.Glob(filepath.Join(dir, "*.png")); if err != nil { t.Fatal(err) }
	if len(files)!=0 { t.Fatalf("durable duplicate images remain: %v", files) }
}

func TestJSONReceiptHasNoImagesAndAcceptsDesignerPromotion(t *testing.T) {
	batch, game, result := receipt_test_batch(t, 0)
	source := make_capture_fixture(t, []uint16{1,2,3})
	seed_receipt(t, batch, game.Setname, source, GameMetadata{Build:batch.Build, TestIdentity:result.TestIdentity})
	dir := publish_test_new(t, batch, game, source)
	assert_no_receipt_pngs(t, batch.capture_receipt(game.Setname))
	if !batch.verifyFinalized(game, result) { t.Fatal("JSON receipt did not verify PNG publication") }
	if err := os.Rename(filepath.Join(dir,"new"),filepath.Join(dir,"ref")); err != nil { t.Fatal(err) }
	if !batch.verifyFinalized(game, result) || result.Outcome!=New { t.Fatal("designer promotion must verify without changing historical collection outcome") }
}

func TestLegacyPNGReceiptMigratesOnlyAfterPublishedProof(t *testing.T) {
	batch, game, result := receipt_test_batch(t, 0)
	source := make_capture_fixture(t, []uint16{1,2,3})
	legacy_test_receipt(t, batch, game, source)
	publish_test_new(t,batch,game,source)
	if !batch.verifyFinalized(game,result) { t.Fatal("verified legacy receipt did not migrate") }
	dir := batch.capture_receipt(game.Setname)
	assert_no_receipt_pngs(t,dir)
	receipt, legacy, err := read_capture_receipt(dir,Profile{Video:300},"rgb555")
	if err!=nil || legacy || len(receipt.Frames)!=3 || receipt.Frames[0].Actual!=100 { t.Fatalf("invalid migrated receipt: %+v %v",receipt,err) }
	for _, name := range []string{"metadata.json","transport-index.jsonl","frames.json"} { if _,err=os.Stat(filepath.Join(dir,name));err!=nil {t.Fatal(err)} }
}

func TestLegacyReceiptWithUnprovenPublishedImagesIsPreserved(t *testing.T) {
	batch,game,result:=receipt_test_batch(t,0)
	legacy_test_receipt(t,batch,game,make_capture_fixture(t,[]uint16{1,2,3}))
	publish_test_new(t,batch,game,make_capture_fixture(t,[]uint16{4,5,6}))
	if batch.verifyFinalized(game,result) {t.Fatal("different publication accepted")}
	dir:=batch.capture_receipt(game.Setname)
	files,_:=filepath.Glob(filepath.Join(dir,"*.png"));if len(files)!=3 {t.Fatal("unproven legacy images removed")}
	if _,err:=os.Stat(filepath.Join(dir,"frames.json"));!os.IsNotExist(err) {t.Fatal("unproven migration became durable")}
}

func TestPartialLegacyReceiptCleanupRetriesFromJSON(t *testing.T) {
	batch,game,result:=receipt_test_batch(t,0)
	source:=make_capture_fixture(t,[]uint16{1,2,3})
	legacy_test_receipt(t,batch,game,source)
	publish_test_new(t,batch,game,source)
	dir:=batch.capture_receipt(game.Setname)
	receipt,_,err:=read_capture_receipt(dir,Profile{Video:300},"rgb555");if err!=nil {t.Fatal(err)}
	if err=save_capture_receipt(dir,receipt);err!=nil {t.Fatal(err)}
	if err=os.Remove(filepath.Join(dir,"frame_00000100.png"));err!=nil {t.Fatal(err)}
	if !batch.verifyFinalized(game,result) {t.Fatal("partial cleanup could not resume")}
	assert_no_receipt_pngs(t,dir)
}

func TestLegacyPassReceiptUsesPostStartupPixelsOfOlderDesignerRef(t *testing.T) {
	batch,game,result:=receipt_test_batch(t,100)
	source:=make_capture_fixture(t,[]uint16{1,2,3})
	legacy_test_receipt(t,batch,game,source)
	dir:=publish_test_new(t,batch,game,make_capture_fixture(t,[]uint16{4,2,3}))
	if err:=os.Rename(filepath.Join(dir,"new"),filepath.Join(dir,"ref"));err!=nil {t.Fatal(err)}
	result.Outcome=Pass
	if !batch.verifyFinalized(game,result) {t.Fatal("pass migration wrongly required startup pixels or same-build reference metadata")}
	assert_no_receipt_pngs(t,batch.capture_receipt(game.Setname))
}

func TestLateStartupPNGNamesRetainRequestedAndActual(t *testing.T) {
	source:=make_capture_fixture(t,[]uint16{1,2,3})
	path:=filepath.Join(source,"index.jsonl")
	data,err:=os.ReadFile(path);if err!=nil {t.Fatal(err)}
	data=[]byte(strings.Replace(string(data),`"actual":100`,`"actual":112`,1))
	if err=os.WriteFile(path,data,0600);err!=nil {t.Fatal(err)}
	set,err:=ReadCaptureSet(source,300,100,100);if err!=nil {t.Fatal(err)}
	receipt,err:=make_capture_receipt(set);if err!=nil {t.Fatal(err)}
	if receipt.Frames[0].Requested!=100 || receipt.Frames[0].Actual!=112 {t.Fatal("receipt lost actual frame")}
	out:=t.TempDir();if err=export_png_frames(source,out);err!=nil {t.Fatal(err)}
	if _,err=os.Stat(filepath.Join(out,"frame_00000100_actual_00000112.png"));err!=nil {t.Fatal(err)}
	pngs,err:=read_png_capture_set(out,300,100,100);if err!=nil {t.Fatal(err)}
	if pngs.Captures[0].Requested!=100 || pngs.Captures[0].Actual!=112 {t.Fatal("PNG read relabeled late capture")}
	if !receipt_matches_pngs(receipt,pngs,0) {t.Fatal("late startup receipt hash mismatch")}
	if _,err=read_png_capture_set(out,300,0,100);err==nil {t.Fatal("late poststartup PNG accepted")}
	if err=os.Rename(filepath.Join(out,"frame_00000100_actual_00000112.png"),filepath.Join(out,"frame_00000100.png"));err!=nil {t.Fatal(err)}
	pngs,err=read_png_capture_set(out,300,100,100);if err!=nil {t.Fatal(err)}
	if receipt_matches_pngs(receipt,pngs,0) {t.Fatal("late frame relabeled as on-time was accepted")}
}

func TestReceiptCanonicalRGB444AndRGB555HashesMatchDecodedPNGs(t *testing.T) {
	for _, native:=range []string{"rgb444","rgb555"} {t.Run(native,func(t *testing.T){
		source:=make_capture_fixture(t,[]uint16{0x123})
		if native=="rgb444" {
			set,read_error:=ReadCaptureSet(source,100,0,100);if read_error!=nil {t.Fatal(read_error)}
			path:=filepath.Join(source,set.Captures[0].Image)
			data:=[]byte{2,0,2,0,0x12,0x34,0x56,0xab,0xcd,0xef}
			binary.LittleEndian.PutUint16(data,2)
			if err:=os.WriteFile(path,data,0600);err!=nil {t.Fatal(err)}
		}
		set,err:=ReadCaptureSet(source,100,0,100);if err!=nil {t.Fatal(err)}
		receipt,err:=make_capture_receipt(set);if err!=nil {t.Fatal(err)}
		if receipt.Format!=native {t.Fatalf("wrong native format %s",receipt.Format)}
		out:=t.TempDir();if err=export_png_frames(source,out);err!=nil {t.Fatal(err)}
		pngs,err:=read_png_capture_set(out,100,0,100);if err!=nil {t.Fatal(err)}
		if !receipt_matches_pngs(receipt,pngs,0) {t.Fatal("native/decodedPNG canonical digest differs")}
	})}
}

func TestLegacyLateStartupReceiptSurvivesMigrationAndManualPromotion(t *testing.T) {
	batch,game,result:=receipt_test_batch(t,100)
	source:=make_capture_fixture(t,[]uint16{1,2,3})
	index:=filepath.Join(source,"index.jsonl")
	data,err:=os.ReadFile(index);if err!=nil {t.Fatal(err)}
	if err=os.WriteFile(index,[]byte(strings.Replace(string(data),`"actual":100`,`"actual":112`,1)),0600);err!=nil {t.Fatal(err)}
	legacy_test_receipt(t,batch,game,source)
	game_dir:=publish_test_new(t,batch,game,source)
	for _, dir:=range []string{batch.capture_receipt(game.Setname),filepath.Join(game_dir,"new")} {
		if err=os.Rename(filepath.Join(dir,"frame_00000100_actual_00000112.png"),filepath.Join(dir,"frame_00000100.png"));err!=nil {t.Fatal(err)}
	}
	if !batch.verifyFinalized(game,result) {t.Fatal("transport-proven legacy late startup label could not migrate")}
	assert_no_receipt_pngs(t,batch.capture_receipt(game.Setname))
	if !batch.verifyFinalized(game,result) {t.Fatal("legacy label proof did not survive JSON migration")}
	if err=os.Rename(filepath.Join(game_dir,"new"),filepath.Join(game_dir,"ref"));err!=nil {t.Fatal(err)}
	if !batch.verifyFinalized(game,result) {t.Fatal("manual promotion of transport-proven legacy label did not verify")}
	receipt,_,err:=read_capture_receipt(batch.capture_receipt(game.Setname),Profile{Video:300,Startup:100},"rgb555")
	if err!=nil || receipt.Frames[0].Actual!=112 || !receipt.Frames[0].LegacyRequestOnlyName {t.Fatalf("actual timing proof lost: %+v %v",receipt,err)}
}

func TestMalformedReceiptCannotSkipPublishedImages(t *testing.T) {
	for _, change:=range []string{"schema","geometry","format","count","duplicate","actual","digest"} {t.Run(change,func(t *testing.T){
		batch,game,result:=receipt_test_batch(t,0)
		source:=make_capture_fixture(t,[]uint16{1,2,3})
		seed_receipt(t,batch,game.Setname,source,GameMetadata{Build:batch.Build,TestIdentity:result.TestIdentity})
		publish_test_new(t,batch,game,source)
		dir:=batch.capture_receipt(game.Setname)
		receipt,_,err:=read_capture_receipt(dir,Profile{Video:300},"rgb555");if err!=nil {t.Fatal(err)}
		switch change {
		case "schema":receipt.Schema=0
		case "geometry":receipt.Width++
		case "format":receipt.Format="rgb444"
		case "count":receipt.Frames=receipt.Frames[:2]
		case "duplicate":receipt.Frames[1].Requested=receipt.Frames[0].Requested
		case "actual":receipt.Frames[0].Actual++
		case "digest":receipt.Frames[0].RGBSHA256="invalid"
		}
		if err=save_capture_receipt(dir,receipt);err!=nil {t.Fatal(err)}
		if batch.verifyFinalized(game,result) {t.Fatalf("malformed %s receipt accepted",change)}
	})}
}

func TestReceiptAcceptsLosslessPNGReencoding(t *testing.T) {
	batch,game,result:=receipt_test_batch(t,0)
	source:=make_capture_fixture(t,[]uint16{1,2,3})
	seed_receipt(t,batch,game.Setname,source,GameMetadata{Build:batch.Build,TestIdentity:result.TestIdentity})
	dir:=publish_test_new(t,batch,game,source)
	path:=filepath.Join(dir,"new","frame_00000100.png")
	before,err:=FileSHA256(path);if err!=nil {t.Fatal(err)}
	file,err:=os.Open(path);if err!=nil {t.Fatal(err)}
	frame,err:=png.Decode(file);_ = file.Close();if err!=nil {t.Fatal(err)}
	file,err=os.Create(path);if err!=nil {t.Fatal(err)}
	encoder:=png.Encoder{CompressionLevel:png.NoCompression}
	err=encoder.Encode(file,frame);_ = file.Close();if err!=nil {t.Fatal(err)}
	after,err:=FileSHA256(path);if err!=nil || before==after {t.Fatal("test did not change PNG encoding")}
	if !batch.verifyFinalized(game,result) {t.Fatal("losslessly reencoded PNG failed canonical RGB verification")}
}
