package regression

import (
	"context"
	"fmt"
	"strings"
	"testing"
)

const partialCaptureReceiptTemplate = `{"protocol": "jtframe-capture-image-v3", "capture_protocol": "jtframe-capture-v3", "session_id": "SESSION", "fpga_generation": 1, "plan_crc32": "5a4bb7ed", "packed_cab_crc32": "3927480c", "requested_checkpoint": CP, "actual_interval": 699, "actual_checkpoint": CP, "descriptor_checkpoint": CP, "width": 256, "height": 224, "row_pitch": 768, "payload_bytes": 172032, "slot_base": "3fe00000", "slot_stride": 2097152, "slot": 0, "mode": "00002c01", "descriptor_crc32": "b7170c09", "descriptor_bytes_hex": "4a54433202004000bc02bb020000e03f000020000001e0000003000000a00200012c0000a102000047465731930e6ae70000000000000000090c17b752445932", "pixel_checksum": "e76a0e93", "pixel_checksum_algorithm": "gfw1", "ready_caps": [51792, 2, 64, 70, 5, 0, 3, 0], "post_copy_caps": [51792, 2, 64, 70, 5, 0, 3, 0], "burst_count": 673, "release_confirmed": true, "release_ack_freshness": 6, "png_complete": true, "png_path": "PNGPATH", "png_size": 3952, "raw_rgb_path": "", "raw_rgb_size": 0}`

// A capture that fails after some checkpoints leaves Main's receipts and PNGs
// behind. Cleanup must own them so the screenshot directory can be removed.
func TestCleanupAdoptsPartialCaptureOutputs(t *testing.T) {
	const session = "mister-0123456789abcdef01234567"
	remote := newFakeMiSTerRemote()
	driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{BoardKey: "board", LocalStateDir: t.TempDir()}}
	active := &miSTerActiveSession{key: AttemptKey{Board: "board", SessionID: session},
		prepared: PreparedSession{Setname: "bublbobl", Checkpoints: []uint32{500, 600, 700}}}
	png := func(cp uint32) string {
		return fmt.Sprintf("/media/fat/screenshots/bublbobl/20261120_0012%02d-cabcap_%s_%04x.png", cp/100, session, cp)
	}
	for _, cp := range []uint32{500, 600} {
		receipt := strings.NewReplacer("SESSION", session, "PNGPATH", png(cp), "CP", fmt.Sprint(cp)).Replace(partialCaptureReceiptTemplate)
		remote.files[fmt.Sprintf("/tmp/jtframe-capture-%s-checkpoint-%05x.receipt.json", session, cp)] = []byte(receipt)
		remote.files[png(cp)] = []byte(fmt.Sprintf("png %d", cp))
	}
	if err := driver.adoptPartialCaptureOutputs(context.Background(), active); err != nil {
		t.Fatal(err)
	}
	if got := len(active.ledger.OwnedFiles); got != 4 {
		t.Fatalf("adopted %d files, want 4 (two receipts, two PNGs)", got)
	}
	for _, file := range active.ledger.OwnedFiles {
		if !file.Owned || file.SHA256 != digestBytes(remote.files[file.Path]) {
			t.Errorf("bad ownership for %s: %+v", file.Path, file)
		}
	}
	reads := len(remote.fileReads)
	if err := driver.adoptPartialCaptureOutputs(context.Background(), active); err != nil {
		t.Fatal(err)
	}
	if len(active.ledger.OwnedFiles) != 4 {
		t.Fatalf("second adoption duplicated entries: %d", len(active.ledger.OwnedFiles))
	}
	if got := len(remote.fileReads) - reads; got != 1 {
		t.Errorf("second adoption read %d receipts, want only the missing checkpoint", got)
	}
}

func TestCleanupRejectsForeignPartialCapturePNG(t *testing.T) {
	const session = "mister-0123456789abcdef01234567"
	remote := newFakeMiSTerRemote()
	driver := &MiSTerSessionDriver{Remote: remote, Config: MiSTerDriverConfig{BoardKey: "board", LocalStateDir: t.TempDir()}}
	active := &miSTerActiveSession{key: AttemptKey{Board: "board", SessionID: session},
		prepared: PreparedSession{Setname: "bublbobl", Checkpoints: []uint32{500}}}
	receipt := strings.NewReplacer("SESSION", session, "PNGPATH", "/media/fat/screenshots/other/x.png", "CP", "500").Replace(partialCaptureReceiptTemplate)
	remote.files[fmt.Sprintf("/tmp/jtframe-capture-%s-checkpoint-%05x.receipt.json", session, 500)] = []byte(receipt)
	if err := driver.adoptPartialCaptureOutputs(context.Background(), active); err == nil {
		t.Fatal("PNG outside the session screenshot directory was adopted")
	}
	if len(active.ledger.OwnedFiles) != 0 {
		t.Fatal("ledger changed after a rejected receipt")
	}
}
