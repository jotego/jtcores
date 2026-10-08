/* SPDX-FileCopyrightText: 2026 Jose Tejada Gomez
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Date: 4-1-2025 */

package mra

// Minimum support for now
type MRA struct {
	Name    string `xml:"name"`
	Setname string `xml:"setname"`
	Rbf     string `xml:"rbf"`
}

type MRAfile struct {
	data MRA `xml:"misterromdescription"`
}
