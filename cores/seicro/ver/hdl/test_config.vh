/* SPDX-FileCopyrightText: 2026 Andrea Bogazzi
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 24-10-2026 */

`ifdef TEST_SCENE
`define NOMAIN
`define NOSOUND
`endif
`ifdef TEST_HEADER
`define NOMAIN
`define NOSOUND
`endif
`ifdef TEST_FLIP
`define NOMAIN
`endif
`ifdef TEST_AUDIO_NOSOUND
`define NOSOUND
`endif
